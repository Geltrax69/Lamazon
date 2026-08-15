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

	// Whether they have a password, so the sign-in screen knows to ask for
	// one instead of mailing a code. Never the hash itself.
	HasPassword bool `json:"hasPassword"`
	HasAddress  bool `json:"hasAddress"`

	// True once we know who they are, how to reach them and where to
	// deliver. False sends them to the details screen rather than into a
	// shop that cannot deliver to them.
	Ready bool `json:"ready"`
}

// SetUp reports whether we have what an order needs: who they are, a number
// to call, and somewhere to deliver.
func (u User) SetUp() bool {
	return u.Name != "" && u.Phone != "" && u.HasAddress
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
		       EXISTS (SELECT 1 FROM seller_stores s WHERE s.owner = u.email),
		       u.pass_hash <> '',
		       EXISTS (SELECT 1 FROM addresses a WHERE a.email = u.email)
		FROM users u WHERE u.email = $1`, email).
		Scan(&u.PublicID, &u.Name, &u.Phone, &u.HasStore, &u.HasPassword,
			&u.HasAddress)
	if err != nil {
		return u, err
	}
	u.Roles = []string{"buyer"}
	u.Ready = u.SetUp()
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

// PATCH /api/me — name, phone, and a password if they want one.
func (a *API) handleUpdateMe(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Name     *string `json:"name"`
		Phone    *string `json:"phone"`
		Password *string `json:"password"`
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

	// Hashed here, never stored or logged in the clear. Sent as null by
	// anyone who is only changing their name, which leaves it untouched.
	var hash *string
	if in.Password != nil {
		if len(*in.Password) < minPasswordLength {
			writeError(w, http.StatusBadRequest,
				"a password needs at least 8 characters")
			return
		}
		h, err := hashPassword(*in.Password)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		hash = &h
	}

	// COALESCE so a call that sends only one field leaves the others alone.
	if _, err := a.db.sql.ExecContext(r.Context(), `
		UPDATE users SET name = COALESCE($2, name), phone = COALESCE($3, phone),
		                 pass_hash = COALESCE($4, pass_hash)
		WHERE email = $1`, email, in.Name, in.Phone, hash); err != nil {
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

// The demonstration account. It exists so the shop can be shown without
// waiting on an inbox, and it is seeded on every boot so a wiped database
// still has it.
//
// Its password is in the source, which means anyone who reads this repository
// can sign in as it. That is the point of it — it owns nothing, sells nothing
// and can be emptied without consequence — but it is a real account on a real
// API, so keep it that way: no store, no admin, nothing worth taking.
const (
	demoEmail    = "lalit@lamazon.in"
	demoPassword = "Lamazon.2113"
	demoName     = "Lalit Test 1"
	demoPhone    = "123456789"
	demoAddress  = "Test 1"
)

// seedDemoUser creates it, and resets the password if it has drifted. Details
// are only filled in when blank, so poking at the account from the app is not
// undone by the next restart.
func (d *DB) seedDemoUser(ctx context.Context) error {
	hash, err := hashPassword(demoPassword)
	if err != nil {
		return err
	}
	if _, err := d.sql.ExecContext(ctx, `
		INSERT INTO users (email, name, phone, pass_hash)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (email) DO UPDATE SET
			pass_hash = EXCLUDED.pass_hash,
			name = CASE WHEN users.name = '' THEN EXCLUDED.name ELSE users.name END,
			phone = CASE WHEN users.phone = '' THEN EXCLUDED.phone ELSE users.phone END`,
		demoEmail, demoName, demoPhone, hash); err != nil {
		return err
	}

	// One address, so the account is ready to order rather than landing on
	// the details screen every time.
	_, err = d.sql.ExecContext(ctx, `
		INSERT INTO addresses (email, label, line, city, name, phone, is_default)
		SELECT $1, 'Home', $2, $3, $4, $5, true
		WHERE NOT EXISTS (SELECT 1 FROM addresses WHERE email = $1)`,
		demoEmail, demoAddress, ServiceableCities[0], demoName, demoPhone)
	return err
}
