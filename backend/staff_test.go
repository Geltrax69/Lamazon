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

// buyerCode is the four digits the buyer was told, which is the only way an
// order can be closed.
func buyerCode(t *testing.T, h http.Handler, id string) string {
	t.Helper()
	for _, o := range callAs2(t, h, testToken, "/api/orders")["orders"].([]any) {
		if row := o.(map[string]any); row["id"] == id {
			return row["deliveryCode"].(string)
		}
	}
	t.Fatalf("no order %s in the buyer's list", id)
	return ""
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

// Off is not gone: a switched-off rider comes back with the same PIN.
// Removing them for good is a different button, and it will not leave an
// order in nobody's hands.
func TestARiderCanBeSwitchedOffAndBackOnOrRemoved(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	somewhereToDeliver(t, h)
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Cold Coffee", "price": 60, "stock": 10})

	admin := adminSignIn(t, h)
	pin := addRider(t, h, admin, "9111111111")

	// Off: signed out, and no longer handed anything.
	callAs(t, h, admin, http.MethodDelete, "/api/admin/riders/9111111111", nil)
	// 403 rather than 401: the number and PIN are right, the shift is not.
	if code, _ := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9111111111", "pin": pin}); code != http.StatusForbidden {
		t.Fatalf("a switched-off rider should not sign in, got %d", code)
	}
	_, order := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 1})
	id := order["id"].(string)
	_, accepted := call(t, h, http.MethodPost, "/api/seller/orders/"+id+"/accept", nil)
	if accepted["assignedTo"] != nil {
		t.Fatalf("a switched-off rider should not be handed work: %v", accepted["assignedTo"])
	}

	// On again, with the PIN they already have.
	if code, _ := callAs(t, h, admin, http.MethodPost,
		"/api/admin/riders/9111111111/on", nil); code != http.StatusOK {
		t.Fatalf("switch on: want 200, got %d", code)
	}
	_, back := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9111111111", "pin": pin})
	token, ok := back["token"].(string)
	if !ok {
		t.Fatalf("the same PIN should still work: %v", back["error"])
	}

	// Carrying something is the one thing that blocks a permanent removal.
	callAs(t, h, admin, http.MethodPost, "/api/admin/orders/"+id+"/assign",
		map[string]string{"phone": "9111111111"})
	callAs(t, h, token, http.MethodPost, "/api/delivery/orders/"+id+"/pick", nil)
	if code, body := callAs(t, h, admin, http.MethodDelete,
		"/api/admin/riders/9111111111?forever=true", nil); code != http.StatusConflict {
		t.Fatalf("removing a rider mid-delivery: want 409, got %d (%v)", code, body["error"])
	}

	// Hands empty, and an order merely assigned goes back to the pool.
	_, second := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 1})
	secondID := second["id"].(string)
	call(t, h, http.MethodPost, "/api/seller/orders/"+secondID+"/accept", nil)
	callAs(t, h, token, http.MethodPost, "/api/delivery/orders/"+id+"/deliver",
		map[string]string{"code": buyerCode(t, h, id)})

	if code, body := callAs(t, h, admin, http.MethodDelete,
		"/api/admin/riders/9111111111?forever=true", nil); code != http.StatusNoContent {
		t.Fatalf("remove for good: want 204, got %d (%v)", code, body["error"])
	}
	if got := callListAs(t, h, admin, "/api/admin/riders"); len(got) != 0 {
		t.Fatalf("the rider should be gone, got %d", len(got))
	}
	for _, o := range callListAs(t, h, admin, "/api/admin/orders") {
		if o.(map[string]any)["id"] == secondID &&
			o.(map[string]any)["assignedTo"] != nil {
			t.Fatal("an order they had not collected should go back to the pool")
		}
	}
	if code, _ := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9111111111", "pin": pin}); code != http.StatusUnauthorized {
		t.Fatalf("a removed rider should not sign in, got %d", code)
	}
}

// A rider changes their SIM mid-run: the number moves, and everything that
// points at them by number moves with it — the bag in their hand, the count
// behind them, and the PIN, which does not survive the move.
func TestChangingARidersNumberTakesTheirWorkWithThem(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	somewhereToDeliver(t, h)
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Cold Coffee", "price": 60, "stock": 10})

	admin := adminSignIn(t, h)
	oldPIN := addRider(t, h, admin, "9111111111")
	_, login := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9111111111", "pin": oldPIN})
	oldToken := login["token"].(string)

	_, order := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 1})
	id := order["id"].(string)
	call(t, h, http.MethodPost, "/api/seller/orders/"+id+"/accept", nil)
	callAs(t, h, oldToken, http.MethodPost, "/api/delivery/orders/"+id+"/pick", nil)

	// A number already in use is refused rather than merging two riders.
	addRider(t, h, admin, "9222222222")
	if code, _ := callAs(t, h, admin, http.MethodPost,
		"/api/admin/riders/9111111111/number",
		map[string]string{"phone": "9222222222"}); code != http.StatusConflict {
		t.Fatalf("moving onto a taken number: want 409, got %d", code)
	}

	code, moved := callAs(t, h, admin, http.MethodPost,
		"/api/admin/riders/9111111111/number",
		map[string]string{"phone": "9333333333"})
	if code != http.StatusOK {
		t.Fatalf("change number: want 200, got %d (%v)", code, moved["error"])
	}
	newPIN, _ := moved["pin"].(string)
	if len(newPIN) != 4 || newPIN == oldPIN {
		t.Fatalf("a moved number should come with a fresh PIN, got %q", moved["pin"])
	}

	// The old number is gone: its session, its PIN, and the number itself.
	if code, _ := callAs(t, h, oldToken, http.MethodGet, "/api/delivery/orders", nil); code != http.StatusUnauthorized {
		t.Fatalf("the old session should be dead, got %d", code)
	}
	if code, _ := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9111111111", "pin": oldPIN}); code != http.StatusUnauthorized {
		t.Fatalf("the old number should not sign in, got %d", code)
	}

	// The new one picks up exactly where they left off, mid-delivery.
	_, fresh := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9333333333", "pin": newPIN})
	newToken, ok := fresh["token"].(string)
	if !ok {
		t.Fatalf("the new number should sign in: %v", fresh["error"])
	}
	carrying := callAs2(t, h, newToken, "/api/delivery/orders")["orders"].([]any)
	if len(carrying) != 1 || carrying[0].(map[string]any)["id"] != id {
		t.Fatalf("the order in their hand did not follow them: %v", carrying)
	}

	// And a PIN reset is the same story without the number changing.
	_, reset := callAs(t, h, admin, http.MethodPost,
		"/api/admin/riders/9333333333/pin", nil)
	resetPIN, _ := reset["pin"].(string)
	if resetPIN == newPIN || len(resetPIN) != 4 {
		t.Fatal("a reset must issue a different PIN")
	}
	if code, _ := callAs(t, h, newToken, http.MethodGet, "/api/delivery/orders", nil); code != http.StatusUnauthorized {
		t.Fatalf("a reset must sign the rider out, got %d", code)
	}
	if code, _ := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9333333333", "pin": resetPIN}); code != http.StatusOK {
		t.Fatalf("the new PIN should work, got %d", code)
	}
}

// Accepting an order hands it to a rider by itself. With two on shift each
// order lands on exactly one panel — never both, never neither.
func TestAcceptingAnOrderHandsItToARider(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	somewhereToDeliver(t, h)
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Cold Coffee", "price": 60, "stock": 20})

	admin := adminSignIn(t, h)
	tokens := map[string]string{}
	for _, phone := range []string{"9111111111", "9222222222"} {
		pin := addRider(t, h, admin, phone)
		_, login := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
			map[string]string{"phone": phone, "pin": pin})
		tokens[phone] = login["token"].(string)
	}

	// Six orders, so a run of all-one-rider would be a 1-in-32 fluke rather
	// than the assertion being loose.
	seen := map[string]int{}
	for range 6 {
		_, order := call(t, h, http.MethodPost, "/api/orders",
			map[string]any{"itemId": item["id"], "units": 1})
		id := order["id"].(string)
		_, accepted := call(t, h, http.MethodPost,
			"/api/seller/orders/"+id+"/accept", nil)
		assigned, _ := accepted["assignedTo"].(string)
		if assigned == "" {
			t.Fatal("accepting with riders on shift should hand the order to one")
		}
		seen[assigned]++

		// It is on that rider's panel, and on nobody else's.
		on := 0
		for phone, token := range tokens {
			for _, o := range callAs2(t, h, token, "/api/delivery/orders")["orders"].([]any) {
				if o.(map[string]any)["id"] == id {
					on++
					if phone != assigned {
						t.Fatalf("order %s showed on %s, assigned to %s", id, phone, assigned)
					}
				}
			}
		}
		if on != 1 {
			t.Fatalf("order %s is on %d panels, want exactly 1", id, on)
		}
	}
	// Spread, not a pile: least-loaded first means both get work.
	if len(seen) != 2 {
		t.Fatalf("six orders across two riders should reach both, got %v", seen)
	}
}

// An order with a rider's name on it is theirs alone — nobody else sees it,
// and nobody else can pick it up.
func TestAssignedOrdersGoToThatRiderOnly(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	somewhereToDeliver(t, h)
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Cold Coffee", "price": 60, "stock": 10})
	_, order := call(t, h, http.MethodPost, "/api/orders",
		map[string]any{"itemId": item["id"], "units": 1})
	id := order["id"].(string)

	admin := adminSignIn(t, h)
	minePIN := addRider(t, h, admin, "9111111111")
	otherPIN := addRider(t, h, admin, "9222222222")
	_, mineLogin := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9111111111", "pin": minePIN})
	_, otherLogin := callAs(t, h, "", http.MethodPost, "/api/delivery/login",
		map[string]string{"phone": "9222222222", "pin": otherPIN})
	mine := mineLogin["token"].(string)
	other := otherLogin["token"].(string)

	// Assigning an unknown number is refused rather than quietly saved.
	if code, _ := callAs(t, h, admin, http.MethodPost,
		"/api/admin/orders/"+id+"/assign",
		map[string]string{"phone": "9333333333"}); code != http.StatusNotFound {
		t.Fatalf("assign to a stranger: want 404, got %d", code)
	}
	// Assignment can happen before the shop has even accepted.
	if code, body := callAs(t, h, admin, http.MethodPost,
		"/api/admin/orders/"+id+"/assign",
		map[string]string{"phone": "9111111111"}); code != http.StatusOK {
		t.Fatalf("assign: want 200, got %d (%v)", code, body["error"])
	}
	call(t, h, http.MethodPost, "/api/seller/orders/"+id+"/accept", nil)

	if got := callAs2(t, h, other, "/api/delivery/orders")["orders"].([]any); len(got) != 0 {
		t.Fatalf("an assigned order showed on another rider's panel: %d", len(got))
	}
	if got := callAs2(t, h, mine, "/api/delivery/orders")["orders"].([]any); len(got) != 1 {
		t.Fatalf("the assigned rider should see it, got %d", len(got))
	}
	if code, body := callAs(t, h, other, http.MethodPost,
		"/api/delivery/orders/"+id+"/pick", nil); code != http.StatusForbidden {
		t.Fatalf("wrong rider picking up: want 403, got %d (%v)", code, body["error"])
	}
	if code, body := callAs(t, h, mine, http.MethodPost,
		"/api/delivery/orders/"+id+"/pick", nil); code != http.StatusOK {
		t.Fatalf("assigned rider picking up: want 200, got %d (%v)", code, body["error"])
	}
	// Once it is on a run it cannot be reassigned out from under them.
	if code, _ := callAs(t, h, admin, http.MethodPost,
		"/api/admin/orders/"+id+"/assign",
		map[string]string{"phone": "9222222222"}); code != http.StatusConflict {
		t.Fatalf("reassigning a picked order: want 409, got %d", code)
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
