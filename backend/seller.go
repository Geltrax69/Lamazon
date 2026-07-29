package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
)

// POST /api/seller/store — opens (or updates) the seller's store.
func (a *API) handleCreateStore(w http.ResponseWriter, r *http.Request) {
	var in SellerStore
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	in.Owner = owner(r)
	in.Name = strings.TrimSpace(in.Name)
	in.Location = strings.TrimSpace(in.Location)
	if in.Name == "" || in.Location == "" || len(in.Categories) == 0 {
		writeError(w, http.StatusBadRequest,
			"name, location and at least one category are required")
		return
	}
	city, ok := resolveCity(in.City)
	if !ok {
		writeError(w, http.StatusBadRequest,
			"we only deliver around "+ServiceableCities[0])
		return
	}
	in.City = city

	if _, err := a.db.sql.ExecContext(r.Context(), `
		INSERT INTO seller_stores (owner, name, location, city, categories)
		VALUES ($1,$2,$3,$4,$5)
		ON CONFLICT (owner) DO UPDATE SET
			name = EXCLUDED.name, location = EXCLUDED.location,
			city = EXCLUDED.city, categories = EXCLUDED.categories`,
		in.Owner, in.Name, in.Location, in.City, in.Categories); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, in)
}

// GET /api/seller/store
func (a *API) handleGetStore(w http.ResponseWriter, r *http.Request) {
	store, err := a.db.store(r.Context(), owner(r))
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "no store yet")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, store)
}

// GET /api/seller/items — inventory plus the derived summary.
func (a *API) handleItems(w http.ResponseWriter, r *http.Request) {
	items, err := a.db.items(r.Context(), owner(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	var units, needsRestock int
	var value float64
	for _, i := range items {
		units += i.Stock
		value += i.Price * float64(i.Stock)
		if i.Status != "in_stock" {
			needsRestock++
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"items": items,
		"summary": map[string]any{
			"products":       len(items),
			"units":          units,
			"needsRestock":   needsRestock,
			"inventoryValue": value,
		},
	})
}

// POST /api/seller/items — add a line of stock.
func (a *API) handleAddItem(w http.ResponseWriter, r *http.Request) {
	var in InventoryItem
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	in.Title = strings.TrimSpace(in.Title)
	switch {
	case in.Title == "":
		writeError(w, http.StatusBadRequest, "title is required")
		return
	case in.Price <= 0:
		writeError(w, http.StatusBadRequest, "price must be above 0")
		return
	case in.Stock < 0:
		writeError(w, http.StatusBadRequest, "stock cannot be negative")
		return
	}

	in.ID = fmt.Sprintf("item-%d", time.Now().UnixMicro())
	_, err := a.db.sql.ExecContext(r.Context(), `
		INSERT INTO inventory_items (id, owner, title, description, category, price, stock)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		in.ID, owner(r), in.Title, in.Description, in.Category, in.Price, in.Stock)
	// The foreign key is what enforces "no stock without a store".
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23503" {
		writeError(w, http.StatusConflict, "open a store before adding stock")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	in.Status = stockStatus(in.Stock)
	writeJSON(w, http.StatusCreated, in)
}

type stockPatch struct {
	Delta *int `json:"delta"` // relative change, e.g. -1 for a sale
	Stock *int `json:"stock"` // absolute set, wins over delta
}

// PATCH /api/seller/items/{id}/stock
func (a *API) handlePatchStock(w http.ResponseWriter, r *http.Request) {
	var in stockPatch
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	id := r.PathValue("id")

	// GREATEST keeps the floor in SQL, so a racing update cannot slip a
	// negative past the check constraint.
	var query string
	var arg int
	switch {
	case in.Stock != nil:
		query = `UPDATE inventory_items SET stock = GREATEST($2, 0)
		         WHERE id = $1 RETURNING id, title, description, category, price, stock`
		arg = *in.Stock
	case in.Delta != nil:
		query = `UPDATE inventory_items SET stock = GREATEST(stock + $2, 0)
		         WHERE id = $1 RETURNING id, title, description, category, price, stock`
		arg = *in.Delta
	default:
		writeError(w, http.StatusBadRequest, "send delta or stock")
		return
	}

	var it InventoryItem
	err := a.db.sql.QueryRowContext(r.Context(), query, id, arg).Scan(
		&it.ID, &it.Title, &it.Description, &it.Category, &it.Price, &it.Stock)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "no item with id "+id)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	it.Status = stockStatus(it.Stock)
	writeJSON(w, http.StatusOK, it)
}

// DELETE /api/seller/items/{id}
func (a *API) handleDeleteItem(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	res, err := a.db.sql.ExecContext(r.Context(),
		`DELETE FROM inventory_items WHERE id = $1`, id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "no item with id "+id)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GET /api/seller/orders
func (a *API) handleOrders(w http.ResponseWriter, r *http.Request) {
	orders, err := a.db.orders(r.Context(), owner(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	counts := map[OrderStage]int{}
	for _, o := range orders {
		counts[o.Stage]++
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"orders": orders,
		"counts": map[string]int{
			"received":  counts[StageReceived],
			"accepted":  counts[StageAccepted],
			"delivered": counts[StageDelivered],
		},
	})
}

// POST /api/seller/orders — a buyer orders against a stock line.
func (a *API) handlePlaceOrder(w http.ResponseWriter, r *http.Request) {
	var in struct {
		ItemID string `json:"itemId"`
		Units  int    `json:"units"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if in.Units <= 0 {
		in.Units = 1
	}

	var title string
	var price float64
	var stock int
	err := a.db.sql.QueryRowContext(r.Context(),
		`SELECT title, price, stock FROM inventory_items WHERE id = $1`, in.ItemID).
		Scan(&title, &price, &stock)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "no item with id "+in.ItemID)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if stock < in.Units {
		writeError(w, http.StatusConflict, "not enough stock")
		return
	}

	order := Order{
		ID:        fmt.Sprintf("order-%d", time.Now().UnixMicro()),
		ItemID:    in.ItemID,
		ItemTitle: title,
		Units:     in.Units,
		Amount:    price * float64(in.Units),
		Stage:     StageReceived,
		PlacedAt:  time.Now().UTC(),
	}
	if _, err := a.db.sql.ExecContext(r.Context(), `
		INSERT INTO orders (id, item_id, item_title, units, amount, stage, placed_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		order.ID, order.ItemID, order.ItemTitle, order.Units, order.Amount,
		order.Stage, order.PlacedAt); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, order)
}

// POST /api/seller/orders/{id}/accept — reserves, stock untouched.
func (a *API) handleAcceptOrder(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	var o Order
	err := a.db.sql.QueryRowContext(r.Context(), `
		UPDATE orders SET stage = 'accepted'
		WHERE id = $1 AND stage <> 'delivered'
		RETURNING id, item_id, item_title, units, amount, stage, placed_at`, id).
		Scan(&o.ID, &o.ItemID, &o.ItemTitle, &o.Units, &o.Amount, &o.Stage, &o.PlacedAt)
	a.finishStage(w, r, id, o, err)
}

// POST /api/seller/orders/{id}/deliver — the hand-over, and the only thing
// that removes units from inventory. Both writes share a transaction so a
// half-delivered order cannot exist.
func (a *API) handleDeliverOrder(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	tx, err := a.db.sql.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer tx.Rollback() //nolint:errcheck // no-op once committed

	var o Order
	err = tx.QueryRowContext(r.Context(), `
		UPDATE orders SET stage = 'delivered'
		WHERE id = $1 AND stage <> 'delivered'
		RETURNING id, item_id, item_title, units, amount, stage, placed_at`, id).
		Scan(&o.ID, &o.ItemID, &o.ItemTitle, &o.Units, &o.Amount, &o.Stage, &o.PlacedAt)
	if errors.Is(err, sql.ErrNoRows) {
		a.alreadyDeliveredOrMissing(w, r, id)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if _, err := tx.ExecContext(r.Context(),
		`UPDATE inventory_items SET stock = GREATEST(stock - $2, 0) WHERE id = $1`,
		o.ItemID, o.Units); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, o)
}

func (a *API) finishStage(w http.ResponseWriter, r *http.Request, id string, o Order, err error) {
	if errors.Is(err, sql.ErrNoRows) {
		a.alreadyDeliveredOrMissing(w, r, id)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, o)
}

// Separating "already delivered" from "never existed" keeps 409 meaningful.
func (a *API) alreadyDeliveredOrMissing(w http.ResponseWriter, r *http.Request, id string) {
	var exists bool
	if err := a.db.sql.QueryRowContext(r.Context(),
		`SELECT true FROM orders WHERE id = $1`, id).Scan(&exists); err == nil && exists {
		writeError(w, http.StatusConflict, "order already delivered")
		return
	}
	writeError(w, http.StatusNotFound, "no order with id "+id)
}
