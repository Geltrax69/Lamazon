package main

import (
	"net/http"
	"testing"
)

// addRider is the admin doing what an admin does: typing in a number. The PIN
// comes back once, here, and never again.
func addRider(t *testing.T, h http.Handler, admin, phone string) string {
	t.Helper()
	code, body := callAs(t, h, admin, http.MethodPost, "/api/admin/riders",
		map[string]string{"phone": phone, "name": "Manish"})
	if code != http.StatusCreated {
		t.Fatalf("add rider: want 201, got %d (%v)", code, body["error"])
	}
	return body["pin"].(string)
}

// Nothing behind /api/admin or /api/delivery opens without the right kind of
// token — and an admin's token is the wrong kind for the delivery panel.
func TestStaffPanelsAreClosedWithoutTheRightToken(t *testing.T) {
	h := testAPI(t)

	for _, path := range []string{"/api/admin/overview", "/api/delivery/orders"} {
		if code, _ := callAs(t, h, "", http.MethodGet, path, nil); code != http.StatusUnauthorized {
			t.Fatalf("%s with no token: want 401, got %d", path, code)
		}
		// A shopper's session is a real token, and still not this one.
		if code, _ := call(t, h, http.MethodGet, path, nil); code != http.StatusUnauthorized {
			t.Fatalf("%s with a shopper token: want 401, got %d", path, code)
		}
	}

	admin := adminSignIn(t, h)
	if code, _ := callAs(t, h, admin, http.MethodGet, "/api/delivery/orders", nil); code != http.StatusUnauthorized {
		t.Fatalf("admin token on the delivery panel: want 401, got %d", code)
	}
	if code, _ := callAs(t, h, admin, http.MethodGet, "/api/admin/overview", nil); code != http.StatusOK {
		t.Fatalf("admin token on the admin panel: want 200, got %d", code)
	}

	// A wrong password is a 401, and says nothing about which half was wrong.
	if code, body := callAs(t, h, "", http.MethodPost, "/api/admin/login",
		map[string]string{"username": "boss", "password": "guess"}); code != http.StatusUnauthorized ||
		body["error"] != "wrong username or password" {
		t.Fatalf("wrong password: want a flat 401, got %d (%v)", code, body["error"])
	}
}

// A store is invisible until it is approved, and a rejection comes with the
// reason the seller has to act on.
func TestStoreReviewGatesTheShelf(t *testing.T) {
	h := testAPI(t)
	call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Under Review", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	admin := adminSignIn(t, h)

	// It is in the queue, and nowhere else.
	pending := 0
	for _, s := range callListAs(t, h, admin, "/api/admin/stores?status=pending") {
		if s.(map[string]any)["name"] == "Under Review" {
			pending++
		}
	}
	if pending != 1 {
		t.Fatalf("want the new store in the review queue, got %d", pending)
	}
	for _, s := range callList(t, h, "/api/shops") {
		if s.(map[string]any)["name"] == "Under Review" {
			t.Fatal("a store under review must not be listed to shoppers")
		}
	}

	// Rejecting without a reason is refused: the seller could not act on it.
	if code, _ := callAs(t, h, admin, http.MethodPost,
		"/api/admin/stores/"+DefaultOwner+"/reject", map[string]string{}); code != http.StatusBadRequest {
		t.Fatalf("reject with no reason: want 400, got %d", code)
	}
	callAs(t, h, admin, http.MethodPost, "/api/admin/stores/"+DefaultOwner+"/reject",
		map[string]string{"reason": "Photo does not show the shop"})

	_, store := call(t, h, http.MethodGet, "/api/seller/store", nil)
	if store["status"] != "rejected" || store["rejectReason"] != "Photo does not show the shop" {
		t.Fatalf("the seller should see why: %v", store)
	}
	if code, body := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{
		"title": "Nope", "price": 10, "stock": 1,
	}); code != http.StatusForbidden {
		t.Fatalf("stock on a rejected store: want 403, got %d (%v)", code, body["error"])
	}

	// Editing a rejected store is how it goes back for another look.
	_, again := call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Under Review", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	if again["status"] != "pending" {
		t.Fatalf("resubmitting should go back to pending, got %v", again["status"])
	}
}

// The whole trip: ordered, accepted, picked, and closed with the four digits
// only the buyer was told.
func TestOrderTravelsFromShopToDoor(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	somewhereToDeliver(t, h)
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Cold Coffee", "category": "Food", "price": 60, "stock": 10})

	code, order := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 2})
	if code != http.StatusCreated {
		t.Fatalf("place order: want 201, got %d (%v)", code, order["error"])
	}
	id := order["id"].(string)
	// The receiver is copied onto the order, because that is what the rider
	// will read — not whatever the address book says by then.
	if order["receiverName"] != "Lalit Singh" || order["receiverPhone"] != "9876543210" {
		t.Fatalf("order did not carry the receiver: %v", order)
	}

	admin := adminSignIn(t, h)
	pin := addRider(t, h, admin, "98765 43210")
	_, rider := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9876543210", "pin": pin})
	riderToken, ok := rider["token"].(string)
	if !ok {
		t.Fatalf("rider login failed: %v", rider["error"])
	}

	// Nothing to collect until the shop has accepted.
	if got := callAs2(t, h, riderToken, "/api/delivery/orders")["orders"].([]any); len(got) != 0 {
		t.Fatalf("an unaccepted order must not reach the delivery panel, got %d", len(got))
	}
	// And no rider can pick one up either.
	if code, _ := callAs(t, h, riderToken, http.MethodPost,
		"/api/delivery/orders/"+id+"/pick", nil); code != http.StatusConflict {
		t.Fatalf("picking before acceptance: want 409, got %d", code)
	}

	call(t, h, http.MethodPost, "/api/seller/orders/"+id+"/accept", nil)

	// The code goes to the buyer and only to the buyer.
	var mine map[string]any
	for _, o := range callAs2(t, h, testToken, "/api/orders")["orders"].([]any) {
		if o.(map[string]any)["id"] == id {
			mine = o.(map[string]any)
		}
	}
	codeDigits, _ := mine["deliveryCode"].(string)
	if len(codeDigits) != 4 {
		t.Fatalf("the buyer should have a 4-digit code, got %q", mine["deliveryCode"])
	}
	for _, o := range callAs2(t, h, riderToken, "/api/delivery/orders")["orders"].([]any) {
		if o.(map[string]any)["deliveryCode"] != nil {
			t.Fatal("the rider must never be told the code")
		}
	}

	if code, body := callAs(t, h, riderToken, http.MethodPost,
		"/api/delivery/orders/"+id+"/pick", nil); code != http.StatusOK {
		t.Fatalf("pick: want 200, got %d (%v)", code, body["error"])
	}
	// Once claimed, it is gone from everyone else's list.
	pin2 := addRider(t, h, admin, "9000000000")
	_, other := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9000000000", "pin": pin2})
	otherToken := other["token"].(string)
	if got := callAs2(t, h, otherToken, "/api/delivery/orders")["orders"].([]any); len(got) != 0 {
		t.Fatalf("a claimed order showed up on another rider's run: %d", len(got))
	}
	if code, _ := callAs(t, h, otherToken, http.MethodPost,
		"/api/delivery/orders/"+id+"/deliver", map[string]string{"code": codeDigits}); code != http.StatusForbidden {
		t.Fatalf("another rider closing the delivery: want 403, got %d", code)
	}

	// Wrong digits change nothing.
	wrong := "0000"
	if wrong == codeDigits {
		wrong = "1111"
	}
	if code, _ := callAs(t, h, riderToken, http.MethodPost,
		"/api/delivery/orders/"+id+"/deliver", map[string]string{"code": wrong}); code != http.StatusUnauthorized {
		t.Fatalf("wrong code: want 401, got %d", code)
	}
	_, stock := call(t, h, http.MethodGet, "/api/seller/items", nil)
	if got := stock["items"].([]any)[0].(map[string]any)["stock"].(float64); got != 10 {
		t.Fatalf("a failed delivery must not touch stock, got %v", got)
	}

	if code, body := callAs(t, h, riderToken, http.MethodPost,
		"/api/delivery/orders/"+id+"/deliver", map[string]string{"code": codeDigits}); code != http.StatusOK {
		t.Fatalf("deliver: want 200, got %d (%v)", code, body["error"])
	}
	_, stock = call(t, h, http.MethodGet, "/api/seller/items", nil)
	if got := stock["items"].([]any)[0].(map[string]any)["stock"].(float64); got != 8 {
		t.Fatalf("delivering 2 of 10 should leave 8, got %v", got)
	}
	panel := callAs2(t, h, riderToken, "/api/delivery/orders")
	if got := panel["rider"].(map[string]any)["delivered"].(float64); got != 1 {
		t.Fatalf("the rider's delivered count should be 1, got %v", got)
	}
}

// A rejected order tells the buyer why, and gives its units back.
func TestRejectingAnOrderFreesTheStock(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	somewhereToDeliver(t, h)
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Samosa", "price": 20, "stock": 1})

	_, first := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 1})
	// The one unit is spoken for.
	if code, _ := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 1}); code != http.StatusConflict {
		t.Fatalf("second order on one unit: want 409, got %d", code)
	}

	if code, _ := call(t, h, http.MethodPost,
		"/api/seller/orders/"+first["id"].(string)+"/reject", map[string]string{}); code != http.StatusBadRequest {
		t.Fatalf("reject with no reason: want 400, got %d", code)
	}
	call(t, h, http.MethodPost, "/api/seller/orders/"+first["id"].(string)+"/reject",
		map[string]string{"reason": "Kitchen closed"})

	if code, body := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 1}); code != http.StatusCreated {
		t.Fatalf("a rejected order should free its unit: got %d (%v)", code, body["error"])
	}
	for _, o := range callAs2(t, h, testToken, "/api/orders")["orders"].([]any) {
		if o.(map[string]any)["id"] == first["id"] &&
			o.(map[string]any)["rejectReason"] != "Kitchen closed" {
			t.Fatalf("the buyer should see the reason: %v", o)
		}
	}
}

// One seller must not be able to touch another's orders, even holding the id.
func TestOneSellerCannotMoveAnothersOrder(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "Mine", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	somewhereToDeliver(t, h)
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Coffee", "price": 60, "stock": 5})
	_, order := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 1})

	// A second, unrelated seller.
	intruder := signIn(t, lastTestDB, "someone.else@lpu.in")
	if code, body := callAs(t, h, intruder, http.MethodPost,
		"/api/seller/orders/"+order["id"].(string)+"/accept", nil); code != http.StatusNotFound {
		t.Fatalf("someone else's order: want 404, got %d (%v)", code, body["error"])
	}
	if code, _ := callAs(t, h, intruder, http.MethodGet, "/api/seller/orders", nil); code != http.StatusOK {
		t.Fatal("the other seller should still see their own (empty) list")
	}
}
