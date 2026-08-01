package main

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
)

// User is one person, recognised by the address they sign in with.
//
// Roles are derived, never stored: someone is a seller exactly when they have
// a store, so the two can never disagree. Opening a store makes the answer
// change on the next read with nothing to keep in sync.
type User struct {
	Email    string   `json:"email"`
	PublicID string   `json:"id"` // LMZ-1001, the one a person quotes
	Name     string   `json:"name"`
	Phone    string   `json:"phone"`
	Roles    []string `json:"roles"` // ["buyer"] or ["buyer","seller"]
	HasStore bool     `json:"hasStore"`
}

// upsertUser creates the row on first sign-in and returns it either way. The
// public id is assigned once by the sequence and never changes.
func (d *DB) upsertUser(ctx context.Context, email string) (User, error) {
	if _, err := d.sql.ExecContext(ctx,
		`INSERT INTO users (email) VALUES ($1) ON CONFLICT (email) DO NOTHING`,
		email); err != nil {
		return User{}, err
	}
	return d.user(ctx, email)
}

func (d *DB) user(ctx context.Context, email string) (User, error) {
	u := User{Email: email}
	err := d.sql.QueryRowContext(ctx, `
		SELECT u.public_id, u.name, u.phone,
		       EXISTS (SELECT 1 FROM seller_stores s WHERE s.owner = u.email)
		FROM users u WHERE u.email = $1`, email).
		Scan(&u.PublicID, &u.Name, &u.Phone, &u.HasStore)
	if err != nil {
		return u, err
	}
	u.Roles = []string{"buyer"}
	if u.HasStore {
		u.Roles = append(u.Roles, "seller")
	}
	return u, nil
}

// GET /api/me — who is signed in, with their roles.
func (a *API) handleMe(w http.ResponseWriter, r *http.Request) {
	// A session can outlive its user row only if someone deleted it by hand;
	// recreating is friendlier than a 500.
	u, err := a.db.upsertUser(r.Context(), a.owner(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, u)
}

// PATCH /api/me — name and phone, the two things we ask for at checkout.
func (a *API) handleUpdateMe(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Name  *string `json:"name"`
		Phone *string `json:"phone"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	email := a.owner(r)
	if _, err := a.db.upsertUser(r.Context(), email); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	// COALESCE so a call that sends only one field leaves the other alone.
	if _, err := a.db.sql.ExecContext(r.Context(), `
		UPDATE users SET name = COALESCE($2, name), phone = COALESCE($3, phone)
		WHERE email = $1`, email, in.Name, in.Phone); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	u, err := a.db.user(r.Context(), email)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, u)
}

// Address is one entry in a person's address book.
type Address struct {
	ID      string `json:"id"`
	Label   string `json:"label"`
	Line    string `json:"line"`
	City    string `json:"city"`
	Pincode string `json:"pincode"`
	Name    string `json:"name"`  // who receives it
	Phone   string `json:"phone"` // and on what number
	Default bool   `json:"isDefault"`
}

func (d *DB) addresses(ctx context.Context, email string) ([]Address, error) {
	rows, err := d.sql.QueryContext(ctx, `
		SELECT id, label, line, city, pincode, name, phone, is_default
		FROM addresses WHERE email = $1
		ORDER BY is_default DESC, created_at`, email)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Address, 0)
	for rows.Next() {
		var a Address
		if err := rows.Scan(&a.ID, &a.Label, &a.Line, &a.City, &a.Pincode,
			&a.Name, &a.Phone, &a.Default); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// GET /api/addresses — the book, default first.
func (a *API) handleAddresses(w http.ResponseWriter, r *http.Request) {
	list, err := a.db.addresses(r.Context(), a.owner(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, list)
}

// POST /api/addresses — save one. The first one saved becomes the default.
func (a *API) handleAddAddress(w http.ResponseWriter, r *http.Request) {
	var in Address
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	in.Line = strings.TrimSpace(in.Line)
	in.Name = strings.TrimSpace(in.Name)
	in.Phone = strings.TrimSpace(in.Phone)
	if in.Line == "" {
		writeError(w, http.StatusBadRequest, "street address is required")
		return
	}
	city, ok := resolveCity(in.City)
	if !ok {
		writeError(w, http.StatusBadRequest,
			"we only deliver around "+ServiceableCities[0])
		return
	}
	in.City = city
	if in.Label == "" {
		in.Label = "Home"
	}

	email := a.owner(r)
	if _, err := a.db.upsertUser(r.Context(), email); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	tx, err := a.db.sql.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer tx.Rollback() //nolint:errcheck // no-op once committed

	// Exactly one default: promoting this one demotes the rest in the same
	// transaction, so a reader never sees two or none.
	var makeDefault bool
	if err := tx.QueryRowContext(r.Context(),
		`SELECT count(*) = 0 FROM addresses WHERE email = $1`, email).
		Scan(&makeDefault); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	makeDefault = makeDefault || in.Default
	if makeDefault {
		if _, err := tx.ExecContext(r.Context(),
			`UPDATE addresses SET is_default = false WHERE email = $1`, email); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
	}
	if err := tx.QueryRowContext(r.Context(), `
		INSERT INTO addresses (email, label, line, city, pincode, name, phone, is_default)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
		email, in.Label, in.Line, in.City, in.Pincode, in.Name, in.Phone, makeDefault).
		Scan(&in.ID); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Saving an address is also the moment we learn the person's name and
	// number, so the profile picks them up rather than asking again later.
	if in.Name != "" || in.Phone != "" {
		a.db.sql.ExecContext(r.Context(), `
			UPDATE users SET
				name = CASE WHEN name = '' THEN $2 ELSE name END,
				phone = CASE WHEN phone = '' THEN $3 ELSE phone END
			WHERE email = $1`, email, in.Name, in.Phone)
	}

	in.Default = makeDefault
	writeJSON(w, http.StatusCreated, in)
}

// DELETE /api/addresses/{id} — scoped to the owner, so an id from someone
// else's book matches nothing.
func (a *API) handleDeleteAddress(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	res, err := a.db.sql.ExecContext(r.Context(),
		`DELETE FROM addresses WHERE id = $1 AND email = $2`, id, a.owner(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "no address with id "+id)
		return
	}
	// Losing the default leaves the book without one; the oldest takes over.
	a.db.sql.ExecContext(r.Context(), `
		UPDATE addresses SET is_default = true
		WHERE id = (SELECT id FROM addresses WHERE email = $1
		            AND NOT EXISTS (SELECT 1 FROM addresses
		                            WHERE email = $1 AND is_default)
		            ORDER BY created_at LIMIT 1)`, a.owner(r))
	w.WriteHeader(http.StatusNoContent)
}
