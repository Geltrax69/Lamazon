package main

import (
	"context"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"strings"
	"time"
)

// Staff — admins and delivery riders — sign in with a password rather than an
// emailed code, so their secrets are stored the way passwords have to be:
// PBKDF2-SHA256, per-row salt, constant-time compare. ponytail: stdlib
// crypto/pbkdf2 instead of a bcrypt dependency; same job, no module to vet.
const (
	pbkdfIterations = 100_000
	staffLifetime   = 12 * time.Hour
)

func hashPassword(password string) (string, error) {
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	key, err := pbkdf2.Key(sha256.New, password, salt, pbkdfIterations, 32)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("pbkdf2$%d$%s$%s", pbkdfIterations,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(key)), nil
}

// passwordMatches is deliberately quiet about why it said no: a wrong user
// and a wrong password have to look identical from outside.
func passwordMatches(stored, password string) bool {
	parts := strings.Split(stored, "$")
	if len(parts) != 4 || parts[0] != "pbkdf2" {
		return false
	}
	var iter int
	if _, err := fmt.Sscanf(parts[1], "%d", &iter); err != nil || iter <= 0 {
		return false
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[2])
	if err != nil {
		return false
	}
	want, err := base64.RawStdEncoding.DecodeString(parts[3])
	if err != nil {
		return false
	}
	got, err := pbkdf2.Key(sha256.New, password, salt, iter, len(want))
	if err != nil {
		return false
	}
	return subtle.ConstantTimeCompare(got, want) == 1
}

// seedAdmin creates or updates the admin account from the environment. The
// credentials never live in this repository — an unset ADMIN_PASSWORD simply
// leaves whatever is already in the table.
func (d *DB) seedAdmin(ctx context.Context) error {
	user := strings.TrimSpace(os.Getenv("ADMIN_USER"))
	pass := os.Getenv("ADMIN_PASSWORD")
	if user == "" || pass == "" {
		return nil
	}
	hash, err := hashPassword(pass)
	if err != nil {
		return err
	}
	_, err = d.sql.ExecContext(ctx, `
		INSERT INTO admins (username, pass_hash) VALUES ($1,$2)
		ON CONFLICT (username) DO UPDATE SET pass_hash = EXCLUDED.pass_hash`,
		strings.ToLower(user), hash)
	return err
}

// ---- staff sessions -----------------------------------------------------

func (d *DB) newStaffSession(ctx context.Context, role, subject string) (string, error) {
	token, err := newToken()
	if err != nil {
		return "", err
	}
	_, err = d.sql.ExecContext(ctx, `
		INSERT INTO staff_sessions (token_hash, role, subject, expires_at)
		VALUES ($1,$2,$3, now() + $4::interval)`,
		hashCode(token), role, subject,
		fmt.Sprintf("%d seconds", int(staffLifetime.Seconds())))
	return token, err
}

// staffSubject resolves a live staff token to who it belongs to, but only for
// the role asked for: an admin token presented to /api/delivery is no better
// than no token at all.
func (d *DB) staffSubject(ctx context.Context, role, token string) (string, error) {
	var subject string
	err := d.sql.QueryRowContext(ctx, `
		SELECT subject FROM staff_sessions
		WHERE token_hash = $1 AND role = $2 AND expires_at > now()`,
		hashCode(token), role).Scan(&subject)
	return subject, err
}

type staffKey struct{}

// staffOf is who the staff middleware verified: the admin's username, or the
// rider's phone number.
func (a *API) staffOf(r *http.Request) string {
	s, _ := r.Context().Value(staffKey{}).(string)
	return s
}

// ---- sign in ------------------------------------------------------------

// POST /api/admin/login
func (a *API) handleAdminLogin(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	username := strings.ToLower(strings.TrimSpace(in.Username))

	var hash string
	err := a.db.sql.QueryRowContext(r.Context(),
		`SELECT pass_hash FROM admins WHERE username = $1`, username).Scan(&hash)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	// The compare runs even when there is no such admin, so a missing account
	// and a wrong password take the same time to answer.
	if !passwordMatches(hash, in.Password) {
		writeError(w, http.StatusUnauthorized, "wrong username or password")
		return
	}
	token, err := a.db.newStaffSession(r.Context(), "admin", username)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token":     token,
		"username":  username,
		"expiresIn": int(staffLifetime.Seconds()),
	})
}

// POST /api/delivery/login — number and PIN, both handed out by an admin.
func (a *API) handleRiderLogin(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Phone string `json:"phone"`
		PIN   string `json:"pin"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	phone := normalisePhone(in.Phone)

	var hash, name string
	var active bool
	err := a.db.sql.QueryRowContext(r.Context(),
		`SELECT pin_hash, name, active FROM riders WHERE phone = $1`, phone).
		Scan(&hash, &name, &active)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if !passwordMatches(hash, in.PIN) {
		writeError(w, http.StatusUnauthorized,
			"that number is not approved for deliveries, or the PIN is wrong")
		return
	}
	if !active {
		writeError(w, http.StatusForbidden, "this delivery account is switched off")
		return
	}
	token, err := a.db.newStaffSession(r.Context(), "rider", phone)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token":     token,
		"phone":     phone,
		"name":      name,
		"expiresIn": int(staffLifetime.Seconds()),
	})
}

// normalisePhone keeps digits only, so 98765-43210 and +91 98765 43210 are
// the same rider. The last ten digits are what India dials.
func normalisePhone(raw string) string {
	digits := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, raw)
	if len(digits) > 10 {
		digits = digits[len(digits)-10:]
	}
	return digits
}

// fourDigits is crypto/rand for the same reason the sign-in code is: a
// delivery anyone can guess closed is not a verification.
func fourDigits() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(10000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%04d", n), nil
}

// ---- admin: what is going on ---------------------------------------------

// GET /api/admin/overview — the numbers on the admin's front page, plus the
// people behind them.
func (a *API) handleAdminOverview(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.sql.QueryContext(r.Context(), `
		SELECT u.email, u.public_id, u.name, u.phone, u.created_at,
		       COALESCE(s.name, ''), COALESCE(s.status, '')
		FROM users u
		LEFT JOIN seller_stores s ON s.owner = u.email
		ORDER BY u.created_at DESC`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	type person struct {
		Email     string    `json:"email"`
		ID        string    `json:"id"`
		Name      string    `json:"name"`
		Phone     string    `json:"phone"`
		JoinedAt  time.Time `json:"joinedAt"`
		StoreName string    `json:"storeName,omitempty"`
		Status    string    `json:"storeStatus,omitempty"`
	}
	people := make([]person, 0)
	var sellers, pending int
	for rows.Next() {
		var p person
		if err := rows.Scan(&p.Email, &p.ID, &p.Name, &p.Phone, &p.JoinedAt,
			&p.StoreName, &p.Status); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if p.StoreName != "" {
			sellers++
		}
		if p.Status == "pending" {
			pending++
		}
		people = append(people, p)
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	var riders, orders int
	a.db.sql.QueryRowContext(r.Context(),
		`SELECT count(*) FROM riders WHERE active`).Scan(&riders)
	a.db.sql.QueryRowContext(r.Context(), `SELECT count(*) FROM orders`).Scan(&orders)

	writeJSON(w, http.StatusOK, map[string]any{
		"users":         len(people),
		"sellers":       sellers,
		"pendingStores": pending,
		"riders":        riders,
		"orders":        orders,
		"people":        people,
	})
}

// GET /api/admin/stores?status=pending — the review queue, or everything.
func (a *API) handleAdminStores(w http.ResponseWriter, r *http.Request) {
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	rows, err := a.db.sql.QueryContext(r.Context(), `
		SELECT s.owner, s.name, s.location, s.city,
		       array_to_string(s.categories, ','), s.photo_url, s.status,
		       s.reject_reason, COALESCE(u.phone, ''),
		       (SELECT count(*) FROM inventory_items i WHERE i.owner = s.owner)
		FROM seller_stores s
		LEFT JOIN users u ON u.email = s.owner
		WHERE ($1::text = '' OR s.status = $1)
		ORDER BY (s.status = 'pending') DESC, s.name`, status)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	type storeRow struct {
		SellerStore
		Phone string `json:"phone"`
		Items int    `json:"items"`
	}
	out := make([]storeRow, 0)
	for rows.Next() {
		var s storeRow
		var categories string
		if err := rows.Scan(&s.Owner, &s.Name, &s.Location, &s.City, &categories,
			&s.PhotoURL, &s.Status, &s.RejectReason, &s.Phone, &s.Items); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		s.Categories = []string{}
		if categories != "" {
			s.Categories = strings.Split(categories, ",")
		}
		out = append(out, s)
	}
	writeJSON(w, http.StatusOK, out)
}

// POST /api/admin/stores/{owner}/approve
func (a *API) handleApproveStore(w http.ResponseWriter, r *http.Request) {
	a.reviewStore(w, r, "approved", "")
}

// POST /api/admin/stores/{owner}/reject — a rejection without a reason is
// useless to the person who has to fix it, so the reason is required.
func (a *API) handleRejectStore(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Reason string `json:"reason"`
	}
	json.NewDecoder(r.Body).Decode(&in) //nolint:errcheck // empty body is a missing reason
	reason := strings.TrimSpace(in.Reason)
	if reason == "" {
		writeError(w, http.StatusBadRequest, "say why, so the seller can fix it")
		return
	}
	a.reviewStore(w, r, "rejected", reason)
}

func (a *API) reviewStore(w http.ResponseWriter, r *http.Request, status, reason string) {
	owner := r.PathValue("owner")
	var name string
	err := a.db.sql.QueryRowContext(r.Context(), `
		UPDATE seller_stores SET status = $2, reject_reason = $3, reviewed_at = now()
		WHERE owner = $1 RETURNING name`, owner, status, reason).Scan(&name)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "no store for "+owner)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	if status == "approved" {
		a.notify(r.Context(), owner, name+" is approved",
			"Your store is live on Lamazon. Open the seller panel to add stock — "+
				"shoppers can see it now.")
	} else {
		a.notify(r.Context(), owner, name+" was not approved",
			"Reason: "+reason+"\n\nFix that and submit the store again.")
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"owner": owner, "name": name, "status": status, "rejectReason": reason,
	})
}

// ---- admin: riders -------------------------------------------------------

// GET /api/admin/riders
func (a *API) handleListRiders(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.sql.QueryContext(r.Context(), `
		SELECT r.phone, r.name, r.active, r.delivered, r.created_at,
		       (SELECT count(*) FROM orders o
		        WHERE o.rider_phone = r.phone AND o.stage = 'picked')
		FROM riders r ORDER BY r.created_at DESC`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	type rider struct {
		Phone     string    `json:"phone"`
		Name      string    `json:"name"`
		Active    bool      `json:"active"`
		Delivered int       `json:"delivered"`
		Carrying  int       `json:"carrying"`
		AddedAt   time.Time `json:"addedAt"`
	}
	out := make([]rider, 0)
	for rows.Next() {
		var v rider
		if err := rows.Scan(&v.Phone, &v.Name, &v.Active, &v.Delivered,
			&v.AddedAt, &v.Carrying); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		out = append(out, v)
	}
	writeJSON(w, http.StatusOK, out)
}

// POST /api/admin/riders — the admin types a number, the server picks the
// PIN. It comes back once, in this response, and is never readable again.
func (a *API) handleAddRider(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Phone string `json:"phone"`
		Name  string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	phone := normalisePhone(in.Phone)
	if len(phone) != 10 {
		writeError(w, http.StatusBadRequest, "enter a 10-digit mobile number")
		return
	}
	pin, err := fourDigits()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	hash, err := hashPassword(pin)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if _, err := a.db.sql.ExecContext(r.Context(), `
		INSERT INTO riders (phone, name, pin_hash) VALUES ($1,$2,$3)
		ON CONFLICT (phone) DO UPDATE SET
			name = EXCLUDED.name, pin_hash = EXCLUDED.pin_hash, active = true`,
		phone, strings.TrimSpace(in.Name), hash); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{
		"phone": phone, "name": strings.TrimSpace(in.Name), "pin": pin,
	})
}

// DELETE /api/admin/riders/{phone} — switched off rather than deleted, so the
// orders they already delivered keep pointing at someone.
func (a *API) handleRemoveRider(w http.ResponseWriter, r *http.Request) {
	phone := normalisePhone(r.PathValue("phone"))
	res, err := a.db.sql.ExecContext(r.Context(),
		`UPDATE riders SET active = false WHERE phone = $1`, phone)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "no rider on "+phone)
		return
	}
	// Their sessions go with them; an off rider must not keep a live panel.
	a.db.sql.ExecContext(r.Context(),
		`DELETE FROM staff_sessions WHERE role = 'rider' AND subject = $1`, phone)
	w.WriteHeader(http.StatusNoContent)
}

// ---- delivery panel ------------------------------------------------------

// GET /api/delivery/orders — what this rider can pick up, and what they are
// already carrying. Nobody else's: an order another rider claimed is gone
// from this list the moment they claim it.
func (a *API) handleRiderOrders(w http.ResponseWriter, r *http.Request) {
	phone := a.staffOf(r)
	rows, err := a.db.sql.QueryContext(r.Context(), `
		SELECT id, item_title, units, amount, stage, placed_at, store_name,
		       receiver_name, receiver_phone, receiver_address, rider_phone
		FROM orders
		WHERE (stage = 'accepted' AND rider_phone = '')
		   OR (stage = 'picked' AND rider_phone = $1)
		ORDER BY (stage = 'picked') DESC, placed_at`, phone)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	out := make([]Order, 0)
	for rows.Next() {
		var o Order
		if err := rows.Scan(&o.ID, &o.ItemTitle, &o.Units, &o.Amount, &o.Stage,
			&o.PlacedAt, &o.StoreName, &o.ReceiverName, &o.ReceiverPhone,
			&o.ReceiverAddress, &o.RiderPhone); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		out = append(out, o)
	}

	var name string
	var delivered int
	a.db.sql.QueryRowContext(r.Context(),
		`SELECT name, delivered FROM riders WHERE phone = $1`, phone).
		Scan(&name, &delivered)
	writeJSON(w, http.StatusOK, map[string]any{
		"rider":     map[string]any{"phone": phone, "name": name, "delivered": delivered},
		"orders":    out,
		"carrying":  countStage(out, StagePicked),
		"available": countStage(out, StageAccepted),
	})
}

func countStage(orders []Order, stage OrderStage) int {
	n := 0
	for _, o := range orders {
		if o.Stage == stage {
			n++
		}
	}
	return n
}

// POST /api/delivery/orders/{id}/pick — claiming it. The WHERE clause is the
// claim: whichever rider's UPDATE lands first gets the order, and the second
// one is told it is gone rather than both riding to the same door.
func (a *API) handleRiderPick(w http.ResponseWriter, r *http.Request) {
	phone := a.staffOf(r)
	id := r.PathValue("id")
	var o Order
	err := a.db.sql.QueryRowContext(r.Context(), `
		UPDATE orders SET stage = 'picked', rider_phone = $2, picked_at = now()
		WHERE id = $1 AND stage = 'accepted' AND rider_phone = ''
		RETURNING id, item_title, units, amount, stage, placed_at, store_name,
		          receiver_name, receiver_phone, receiver_address, buyer_email`,
		id, phone).
		Scan(&o.ID, &o.ItemTitle, &o.Units, &o.Amount, &o.Stage, &o.PlacedAt,
			&o.StoreName, &o.ReceiverName, &o.ReceiverPhone, &o.ReceiverAddress,
			&o.BuyerEmail)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusConflict,
			"that order is not waiting for pick-up any more")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	a.notify(r.Context(), o.BuyerEmail, "Order "+o.ID+" is on its way",
		fmt.Sprintf("A rider picked up your %s from %s.\n\n"+
			"Have your 4-digit delivery code ready — they need it to close the order.",
			o.ItemTitle, o.StoreName))
	o.BuyerEmail = ""
	writeJSON(w, http.StatusOK, o)
}

// POST /api/delivery/orders/{id}/deliver — the code is the hand-over. The
// rider types what the buyer read out; wrong digits change nothing.
func (a *API) handleRiderDeliver(w http.ResponseWriter, r *http.Request) {
	phone := a.staffOf(r)
	id := r.PathValue("id")
	var in struct {
		Code string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	tx, err := a.db.sql.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer tx.Rollback() //nolint:errcheck // no-op once committed

	// Three conditions in one statement: the right order, in the right stage,
	// carried by this rider, closed with the right code. Any of them false and
	// no row comes back — which is also what stops a rider closing an order
	// that belongs to someone else's run.
	var o Order
	err = tx.QueryRowContext(r.Context(), `
		UPDATE orders SET stage = 'delivered', delivered_at = now()
		WHERE id = $1 AND stage = 'picked' AND rider_phone = $2 AND delivery_code = $3
		RETURNING id, item_id, item_title, units, amount, stage, placed_at,
		          store_name, store_owner, buyer_email`,
		id, phone, strings.TrimSpace(in.Code)).
		Scan(&o.ID, &o.ItemID, &o.ItemTitle, &o.Units, &o.Amount, &o.Stage,
			&o.PlacedAt, &o.StoreName, &o.StoreOwner, &o.BuyerEmail)
	if errors.Is(err, sql.ErrNoRows) {
		a.explainFailedDelivery(w, r, id, phone)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	// Delivering is what actually takes the units out of stock, and what the
	// rider's count is made of. Both in the transaction: a delivery that only
	// half happened is worse than one that did not.
	if _, err := tx.ExecContext(r.Context(),
		`UPDATE inventory_items SET stock = GREATEST(stock - $2, 0) WHERE id = $1`,
		o.ItemID, o.Units); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if _, err := tx.ExecContext(r.Context(),
		`UPDATE riders SET delivered = delivered + 1 WHERE phone = $1`, phone); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	a.notify(r.Context(), o.BuyerEmail, "Delivered: "+o.ItemTitle,
		fmt.Sprintf("Order %s from %s has been delivered. Enjoy.", o.ID, o.StoreName))
	a.notify(r.Context(), o.StoreOwner, "Order "+o.ID+" was delivered",
		fmt.Sprintf("%d × %s reached the customer. ₹%.0f.",
			o.Units, o.ItemTitle, o.Amount))
	o.BuyerEmail, o.StoreOwner = "", ""
	writeJSON(w, http.StatusOK, o)
}

// A failed delivery has three possible causes and the rider needs to know
// which: wrong code, someone else's order, or already closed.
func (a *API) explainFailedDelivery(w http.ResponseWriter, r *http.Request, id, phone string) {
	var stage, rider string
	err := a.db.sql.QueryRowContext(r.Context(),
		`SELECT stage, rider_phone FROM orders WHERE id = $1`, id).Scan(&stage, &rider)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		writeError(w, http.StatusNotFound, "no order with id "+id)
	case err != nil:
		writeError(w, http.StatusInternalServerError, err.Error())
	case rider != phone:
		writeError(w, http.StatusForbidden, "that order is not on your run")
	case stage == "delivered":
		writeError(w, http.StatusConflict, "that order is already delivered")
	case stage != "picked":
		writeError(w, http.StatusConflict, "pick the order up first")
	default:
		log.Printf("order %s: wrong delivery code from rider %s", id, phone)
		writeError(w, http.StatusUnauthorized,
			"wrong code — ask the customer to read it out again")
	}
}
