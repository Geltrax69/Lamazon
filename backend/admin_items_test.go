package main

import (
	"net/http"
	"testing"
)

// The admin catalogue view: every store's stock in one place, with the numbers
// that make its buttons honest — and a delete that refuses for the same reason
// the seller's does.
func TestAdminSeesEveryStoreAndCannotDeleteAnOrderedItem(t *testing.T) {
	h := testAPI(t)
	admin := adminSignIn(t, h)
	addRider(t, h, admin, "9876543210")
	openApprovedStore(t, h, map[string]any{"name": "Guard Store", "location": "Block 32", "city": "LPU", "categories": []string{"Food"}})
	somewhereToDeliver(t, h)
	_, ordered := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{"title": "Masala Chai", "price": 25, "stock": 5})
	_, spare := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{"title": "Spare Bun", "price": 10, "stock": 3})
	orderedID := ordered["id"].(string)
	spareID := spare["id"].(string)

	if code, body := call(t, h, http.MethodPost, "/api/orders/checkout", map[string]any{
		"lines": []map[string]any{{"itemId": orderedID, "units": 2}}, "requestId": "admin-items-001", "expectedTotal": 65,
	}); code != 201 {
		t.Fatalf("checkout: %d %v", code, body)
	}

	// No ?owner=: the whole catalogue, with the store on every row.
	_, all := callAs(t, h, admin, http.MethodGet, "/api/admin/items", nil)
	rows := all["items"].([]any)
	if len(rows) != 2 {
		t.Fatalf("expected both items across the shop, got %d", len(rows))
	}
	byID := map[string]map[string]any{}
	for _, raw := range rows {
		row := raw.(map[string]any)
		byID[row["id"].(string)] = row
		if row["storeName"] != "Guard Store" {
			t.Fatalf("row is missing its store: %v", row)
		}
	}
	// The counts the screen needs to explain itself before a button is pressed.
	if got := byID[orderedID]["orders"]; got != float64(1) {
		t.Fatalf("ordered item should report 1 order, got %v", got)
	}
	if got := byID[orderedID]["reserved"]; got != float64(2) {
		t.Fatalf("ordered item should report 2 reserved units, got %v", got)
	}
	if _, present := byID[spareID]["orders"]; present {
		t.Fatalf("an item with no orders should omit the count, got %v", byID[spareID]["orders"])
	}

	// Delete is refused while an order points at the row.
	if code, body := callAs(t, h, admin, http.MethodDelete, "/api/admin/items/"+orderedID, nil); code != http.StatusConflict {
		t.Fatalf("admin delete of an ordered item should be refused, got %d %v", code, body)
	}
	if _, mine := call(t, h, http.MethodGet, "/api/orders", nil); len(mine["orders"].([]any)) != 1 {
		t.Fatal("the order did not survive the refused admin delete")
	}

	// Hiding it is the way out, and it works across stores without an owner.
	if code, body := callAs(t, h, admin, http.MethodPatch, "/api/admin/items/"+orderedID+"/listing", map[string]any{"delisted": true}); code != 204 {
		t.Fatalf("admin delist: %d %v", code, body)
	}
	if onSale(callList(t, h, "/api/products"), "Masala Chai") {
		t.Fatal("a delisted item is still in the shop")
	}

	// An admin can correct a miscount without signing in as the seller.
	if code, body := callAs(t, h, admin, http.MethodPatch, "/api/admin/items/"+spareID+"/stock", map[string]any{"stock": 11}); code != 204 {
		t.Fatalf("admin stock correction: %d %v", code, body)
	}
	_, after := callAs(t, h, admin, http.MethodGet, "/api/admin/items", nil)
	for _, raw := range after["items"].([]any) {
		row := raw.(map[string]any)
		if row["id"] == spareID && row["stock"] != float64(11) {
			t.Fatalf("stock correction did not stick: %v", row["stock"])
		}
	}

	// And an unordered item still deletes, so the guard is not just refusing
	// everything.
	if code, body := callAs(t, h, admin, http.MethodDelete, "/api/admin/items/"+spareID, nil); code != 204 {
		t.Fatalf("admin delete of an unordered item: %d %v", code, body)
	}
}

// The routes are admin-only.
func TestAdminItemRoutesRejectAShopper(t *testing.T) {
	h := testAPI(t)
	adminSignIn(t, h)
	openApprovedStore(t, h, map[string]any{"name": "S", "location": "L", "city": "LPU", "categories": []string{"Food"}})
	_, item := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{"title": "Bun", "price": 10, "stock": 3})
	id := item["id"].(string)

	// call() carries the shopper's token, not the admin's.
	for _, probe := range []struct {
		method, path string
		body         any
	}{
		{http.MethodGet, "/api/admin/items", nil},
		{http.MethodDelete, "/api/admin/items/" + id, nil},
		{http.MethodPatch, "/api/admin/items/" + id + "/listing", map[string]any{"delisted": true}},
		{http.MethodPatch, "/api/admin/items/" + id + "/stock", map[string]any{"stock": 1}},
	} {
		if code, _ := call(t, h, probe.method, probe.path, probe.body); code != http.StatusUnauthorized {
			t.Fatalf("%s %s should reject a shopper token, got %d", probe.method, probe.path, code)
		}
	}
}
