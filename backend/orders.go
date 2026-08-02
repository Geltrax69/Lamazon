package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
)

// The life of an order, and who moves it on:
//
//	buyer   places it            → received
//	seller  accepts              → accepted   (a 4-digit code goes to the buyer)
//	seller  rejects, with reason → rejected   (the end)
//	rider   picks it up          → picked
//	rider   types the code       → delivered  (stock drops, count goes up)
//
// Every step is one UPDATE whose WHERE clause carries both the stage it must
// be in and who is allowed to move it. Nothing here trusts an id on its own,
// which is what keeps one seller's panel — or one rider's run — away from
// somebody else's order.

// orderColumns is the shape every handler here scans, in one place so the
// column list and the Scan cannot drift apart.
const orderColumns = `id, item_id, item_title, units, amount, stage, placed_at,
	store_owner, store_name, receiver_name, receiver_phone, receiver_address,
	reject_reason, rider_phone`

func scanOrder(row interface{ Scan(...any) error }) (Order, error) {
	var o Order
	err := row.Scan(&o.ID, &o.ItemID, &o.ItemTitle, &o.Units, &o.Amount, &o.Stage,
		&o.PlacedAt, &o.StoreOwner, &o.StoreName, &o.ReceiverName,
		&o.ReceiverPhone, &o.ReceiverAddress, &o.RejectReason, &o.RiderPhone)
	return o, err
}

// POST /api/orders — a buyer orders against a stock line.
func (a *API) handlePlaceOrder(w http.ResponseWriter, r *http.Request) {
	var in struct {
		ItemID    string `json:"itemId"`
		Units     int    `json:"units"`
		AddressID string `json:"addressId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if in.Units <= 0 {
		in.Units = 1
	}
	buyer := a.owner(r)

	// Where it goes is settled before anything is written, and copied onto
	// the order: the rider reads this, not the address book, so editing an
	// address later cannot redirect a bag that is already out.
	receiver, err := a.deliveryTarget(r.Context(), buyer, in.AddressID)
	if err != nil {
		writeError(w, http.StatusBadRequest,
			"add a delivery address before ordering")
		return
	}

	// Check and insert inside one transaction, holding the item row. FOR
	// UPDATE makes concurrent orders for the same item queue up, and because
	// each statement takes a fresh snapshot, the reserved sum below sees
	// whatever the previous holder committed. A single statement would not:
	// its CTEs would all read the snapshot from before the lock was granted.
	tx, err := a.db.sql.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer tx.Rollback() //nolint:errcheck // no-op once committed

	var title, storeOwner, storeName, status string
	var price float64
	var stock int
	err = tx.QueryRowContext(r.Context(), `
		SELECT i.title, i.price, i.stock, s.owner, s.name, s.status
		FROM inventory_items i JOIN seller_stores s ON s.owner = i.owner
		WHERE i.id = $1 FOR UPDATE OF i`, in.ItemID).
		Scan(&title, &price, &stock, &storeOwner, &storeName, &status)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "no item with id "+in.ItemID)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if status != "approved" {
		writeError(w, http.StatusConflict, "that store is not taking orders")
		return
	}

	// Orders that are still alive already claim units, so the fifth buyer of
	// five units is the last one served. A rejected order gives its units back.
	var reserved int
	if err := tx.QueryRowContext(r.Context(), `
		SELECT COALESCE(sum(units), 0) FROM orders
		WHERE item_id = $1 AND stage NOT IN ('delivered', 'rejected')`,
		in.ItemID).Scan(&reserved); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if stock-reserved < in.Units {
		writeError(w, http.StatusConflict, "not enough stock")
		return
	}

	o, err := scanOrder(tx.QueryRowContext(r.Context(), `
		INSERT INTO orders (item_id, item_title, units, amount, stage, buyer_email,
			store_owner, store_name, receiver_name, receiver_phone, receiver_address)
		VALUES ($1,$2,$3,$4,'received',$5,$6,$7,$8,$9,$10)
		RETURNING `+orderColumns,
		in.ItemID, title, in.Units, price*float64(in.Units), buyer,
		storeOwner, storeName, receiver.Name, receiver.Phone, receiver.Line))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// The seller hears about it only once the order is committed, and a
	// notification that fails never undoes a real order.
	a.notify(r.Context(), storeOwner,
		fmt.Sprintf("New order: %d × %s", o.Units, o.ItemTitle),
		fmt.Sprintf("%s just received an order.\n\n%d × %s\nTotal ₹%.0f\n\n"+
			"Open Lamazon to accept it.", storeName, o.Units, o.ItemTitle, o.Amount))
	writeJSON(w, http.StatusCreated, o)
}

// deliveryTarget picks the address this order is for: the one asked for, or
// the default. Scoped to the buyer, so an id from somebody else's book is
// simply not found.
func (a *API) deliveryTarget(ctx context.Context, buyer, addressID string) (Address, error) {
	var ad Address
	err := a.db.sql.QueryRowContext(ctx, `
		SELECT id, label, line, city, pincode, name, phone
		FROM addresses
		WHERE email = $1 AND ($2::text = '' OR id = $2)
		ORDER BY is_default DESC, created_at LIMIT 1`, buyer, addressID).
		Scan(&ad.ID, &ad.Label, &ad.Line, &ad.City, &ad.Pincode, &ad.Name, &ad.Phone)
	if err != nil {
		return ad, err
	}
	// Whoever placed the order is who to call when nobody answers the door.
	if ad.Name == "" || ad.Phone == "" {
		var name, phone string
		a.db.sql.QueryRowContext(ctx, `SELECT name, phone FROM users WHERE email = $1`,
			buyer).Scan(&name, &phone)
		if ad.Name == "" {
			ad.Name = name
		}
		if ad.Phone == "" {
			ad.Phone = phone
		}
	}
	ad.Line = strings.TrimSpace(ad.Line + ", " + ad.City + " " + ad.Pincode)
	return ad, nil
}

// GET /api/orders — the buyer's own orders, newest first. This is the only
// place the delivery code is ever returned: the rider has to be told it by
// the person at the door, which is what makes it proof of delivery.
func (a *API) handleMyOrders(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.sql.QueryContext(r.Context(), `
		SELECT `+orderColumns+`,
		       CASE WHEN stage IN ('accepted','picked') THEN delivery_code ELSE '' END
		FROM orders WHERE buyer_email = $1 ORDER BY placed_at DESC`, a.owner(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	out := make([]Order, 0)
	for rows.Next() {
		var o Order
		if err := rows.Scan(&o.ID, &o.ItemID, &o.ItemTitle, &o.Units, &o.Amount,
			&o.Stage, &o.PlacedAt, &o.StoreOwner, &o.StoreName, &o.ReceiverName,
			&o.ReceiverPhone, &o.ReceiverAddress, &o.RejectReason, &o.RiderPhone,
			&o.DeliveryCode); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		o.StoreOwner = "" // the buyer has no business with the seller's address
		out = append(out, o)
	}
	writeJSON(w, http.StatusOK, map[string]any{"orders": out})
}

// GET /api/seller/orders — every order against this seller's stock.
func (a *API) handleOrders(w http.ResponseWriter, r *http.Request) {
	orders, err := a.db.orders(r.Context(), a.owner(r))
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
			"rejected":  counts[StageRejected],
			"picked":    counts[StagePicked],
			"delivered": counts[StageDelivered],
		},
	})
}

// POST /api/seller/orders/{id}/accept — the seller takes the order on. Stock
// is untouched; what changes is that a delivery code now exists, and the
// buyer is the only one told it.
func (a *API) handleAcceptOrder(w http.ResponseWriter, r *http.Request) {
	code, err := fourDigits()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	id := r.PathValue("id")
	var buyer string
	row := a.db.sql.QueryRowContext(r.Context(), `
		UPDATE orders SET stage = 'accepted', accepted_at = now(), delivery_code = $3
		WHERE id = $1 AND store_owner = $2 AND stage = 'received'
		RETURNING `+orderColumns+`, buyer_email`,
		id, a.owner(r), code)

	var o Order
	err = row.Scan(&o.ID, &o.ItemID, &o.ItemTitle, &o.Units, &o.Amount, &o.Stage,
		&o.PlacedAt, &o.StoreOwner, &o.StoreName, &o.ReceiverName, &o.ReceiverPhone,
		&o.ReceiverAddress, &o.RejectReason, &o.RiderPhone, &buyer)
	if !a.orderMoved(w, r, id, err) {
		return
	}
	a.notify(r.Context(), buyer, "Order "+o.ID+" is confirmed",
		fmt.Sprintf("%s accepted your order of %d × %s.\n\n"+
			"Your delivery code is %s. Read it out to the rider when they hand "+
			"the order over — it is what closes the delivery.",
			o.StoreName, o.Units, o.ItemTitle, code))
	writeJSON(w, http.StatusOK, o)
}

// POST /api/seller/orders/{id}/reject — with a reason, which the buyer sees.
func (a *API) handleRejectOrder(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Reason string `json:"reason"`
	}
	json.NewDecoder(r.Body).Decode(&in) //nolint:errcheck // empty body is a missing reason
	reason := strings.TrimSpace(in.Reason)
	if reason == "" {
		writeError(w, http.StatusBadRequest, "say why, so the customer knows")
		return
	}
	id := r.PathValue("id")
	var buyer string
	row := a.db.sql.QueryRowContext(r.Context(), `
		UPDATE orders SET stage = 'rejected', reject_reason = $3
		WHERE id = $1 AND store_owner = $2 AND stage = 'received'
		RETURNING `+orderColumns+`, buyer_email`, id, a.owner(r), reason)

	var o Order
	err := row.Scan(&o.ID, &o.ItemID, &o.ItemTitle, &o.Units, &o.Amount, &o.Stage,
		&o.PlacedAt, &o.StoreOwner, &o.StoreName, &o.ReceiverName, &o.ReceiverPhone,
		&o.ReceiverAddress, &o.RejectReason, &o.RiderPhone, &buyer)
	if !a.orderMoved(w, r, id, err) {
		return
	}
	a.notify(r.Context(), buyer, "Order "+o.ID+" could not be accepted",
		fmt.Sprintf("%s could not take your order of %d × %s.\n\nReason: %s",
			o.StoreName, o.Units, o.ItemTitle, reason))
	writeJSON(w, http.StatusOK, o)
}

// POST /api/seller/orders/{id}/deliver — the seller handing an order over
// themselves, for a store that does its own running. Refused once a rider has
// picked it up: that delivery is closed with the buyer's code, not from here.
func (a *API) handleDeliverOrder(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	tx, err := a.db.sql.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer tx.Rollback() //nolint:errcheck // no-op once committed

	o, err := scanOrder(tx.QueryRowContext(r.Context(), `
		UPDATE orders SET stage = 'delivered', delivered_at = now()
		WHERE id = $1 AND store_owner = $2 AND stage = 'accepted' AND rider_phone = ''
		RETURNING `+orderColumns, id, a.owner(r)))
	if !a.orderMoved(w, r, id, err) {
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

// orderMoved turns "no row came back" into the reason it did not. Every
// stage change above is one conditional UPDATE, so this is where "not yours",
// "already moved on" and "never existed" are told apart — and they must be,
// because 409 on a double tap and 404 on a bad id mean different things to
// the app showing them.
func (a *API) orderMoved(w http.ResponseWriter, r *http.Request, id string, err error) bool {
	if err == nil {
		return true
	}
	if !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusInternalServerError, err.Error())
		return false
	}
	var stage, owner string
	switch scanErr := a.db.sql.QueryRowContext(r.Context(),
		`SELECT stage, store_owner FROM orders WHERE id = $1`, id).
		Scan(&stage, &owner); {
	case errors.Is(scanErr, sql.ErrNoRows):
		writeError(w, http.StatusNotFound, "no order with id "+id)
	case scanErr != nil:
		writeError(w, http.StatusInternalServerError, scanErr.Error())
	case owner != a.owner(r):
		// Not their order, and not their business that it exists either.
		log.Printf("order %s: %s tried to move someone else's order", id, a.owner(r))
		writeError(w, http.StatusNotFound, "no order with id "+id)
	default:
		writeError(w, http.StatusConflict, "that order is already "+stage)
	}
	return false
}
