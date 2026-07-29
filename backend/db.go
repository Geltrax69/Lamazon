package main

import (
	"context"
	"database/sql"
	_ "embed"
	"fmt"
	"strings"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
)

//go:embed schema.sql
var schema string

// DB is the Postgres-backed store. Same handlers, real storage.
type DB struct {
	sql *sql.DB
}

// OpenDB connects, applies the schema and seeds the catalog if it is empty.
// ponytail: schema on boot instead of a migration tool — the file is
// idempotent, and there is no live data to migrate yet.
func OpenDB(dsn string) (*DB, error) {
	conn, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, fmt.Errorf("open: %w", err)
	}
	conn.SetMaxOpenConns(10)
	conn.SetConnMaxLifetime(time.Hour)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := conn.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("ping: %w", err)
	}
	if _, err := conn.ExecContext(ctx, schema); err != nil {
		return nil, fmt.Errorf("schema: %w", err)
	}

	db := &DB{sql: conn}
	if err := db.seedIfEmpty(ctx); err != nil {
		return nil, fmt.Errorf("seed: %w", err)
	}
	return db, nil
}

func (d *DB) Close() error { return d.sql.Close() }

// seedIfEmpty loads the sample catalog the first time only, so restarts do
// not duplicate rows or undo edits.
func (d *DB) seedIfEmpty(ctx context.Context) error {
	var n int
	if err := d.sql.QueryRowContext(ctx, `SELECT count(*) FROM products`).Scan(&n); err != nil {
		return err
	}
	if n > 0 {
		return nil
	}

	tx, err := d.sql.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() //nolint:errcheck // no-op once committed

	for _, p := range seedProducts() {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO products (id, name, category, tab, price, image_url, store, description)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
			p.ID, p.Name, p.Category, p.Tab, p.Price, p.ImageURL, p.Store, p.Description); err != nil {
			return err
		}
		for _, o := range p.Offers {
			if _, err := tx.ExecContext(ctx, `
				INSERT INTO offers (product_id, store, price) VALUES ($1,$2,$3)`,
				p.ID, o.Store, o.Price); err != nil {
				return err
			}
		}
	}
	for _, s := range seedShops() {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO shops (name, tagline, image_url, tab) VALUES ($1,$2,$3,$4)`,
			s.Name, s.Tagline, s.ImageURL, s.Tab); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// products loads the catalog with each product's offers attached.
func (d *DB) products(ctx context.Context) ([]Product, error) {
	rows, err := d.sql.QueryContext(ctx, `
		SELECT id, name, category, tab, price, image_url, store, description
		FROM products ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Product
	byID := map[string]int{}
	for rows.Next() {
		var p Product
		if err := rows.Scan(&p.ID, &p.Name, &p.Category, &p.Tab, &p.Price,
			&p.ImageURL, &p.Store, &p.Description); err != nil {
			return nil, err
		}
		byID[p.ID] = len(out)
		out = append(out, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// One extra query rather than N: offers are attached in a second pass.
	offerRows, err := d.sql.QueryContext(ctx,
		`SELECT product_id, store, price FROM offers ORDER BY product_id, store`)
	if err != nil {
		return nil, err
	}
	defer offerRows.Close()
	for offerRows.Next() {
		var id string
		var o Offer
		if err := offerRows.Scan(&id, &o.Store, &o.Price); err != nil {
			return nil, err
		}
		if i, ok := byID[id]; ok {
			out[i].Offers = append(out[i].Offers, o)
		}
	}
	return out, offerRows.Err()
}

func (d *DB) shops(ctx context.Context) ([]Shop, error) {
	rows, err := d.sql.QueryContext(ctx,
		`SELECT name, tagline, image_url, tab FROM shops ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Shop
	for rows.Next() {
		var s Shop
		if err := rows.Scan(&s.Name, &s.Tagline, &s.ImageURL, &s.Tab); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// store reads one seller's store.
//
// database/sql cannot scan a text[] into []string, so the array is flattened
// in SQL and split here. ponytail: two lines instead of an array-type
// dependency for the one column that needs it.
func (d *DB) store(ctx context.Context, owner string) (SellerStore, error) {
	var s SellerStore
	var categories string
	err := d.sql.QueryRowContext(ctx, `
		SELECT owner, name, location, city, array_to_string(categories, ',')
		FROM seller_stores WHERE owner = $1`, owner).
		Scan(&s.Owner, &s.Name, &s.Location, &s.City, &categories)
	if err != nil {
		return s, err
	}
	s.Categories = []string{}
	if categories != "" {
		s.Categories = strings.Split(categories, ",")
	}
	return s, nil
}

// items reads a seller's inventory, newest first, with status derived here
// rather than stored — one less column that can drift out of sync.
func (d *DB) items(ctx context.Context, owner string) ([]InventoryItem, error) {
	rows, err := d.sql.QueryContext(ctx, `
		SELECT id, title, description, category, price, stock
		FROM inventory_items WHERE owner = $1 ORDER BY id DESC`, owner)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]InventoryItem, 0)
	for rows.Next() {
		var i InventoryItem
		if err := rows.Scan(&i.ID, &i.Title, &i.Description, &i.Category,
			&i.Price, &i.Stock); err != nil {
			return nil, err
		}
		i.Status = stockStatus(i.Stock)
		out = append(out, i)
	}
	return out, rows.Err()
}

// orders reads every order against this seller's stock, newest first.
func (d *DB) orders(ctx context.Context, owner string) ([]Order, error) {
	rows, err := d.sql.QueryContext(ctx, `
		SELECT o.id, o.item_id, o.item_title, o.units, o.amount, o.stage, o.placed_at
		FROM orders o
		JOIN inventory_items i ON i.id = o.item_id
		WHERE i.owner = $1
		ORDER BY o.placed_at DESC`, owner)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Order, 0)
	for rows.Next() {
		var o Order
		if err := rows.Scan(&o.ID, &o.ItemID, &o.ItemTitle, &o.Units,
			&o.Amount, &o.Stage, &o.PlacedAt); err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}
