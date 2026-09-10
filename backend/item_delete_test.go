package main

import (
	"net/http"
	"testing"
)

// The order is the record of a sale. Deleting the product used to take it —
// delivered ones included — so this is the guard that must not regress, plus
// the delist path that replaces the delete a seller actually wanted.
func TestDeletingAnOrderedItemIsRefusedAndDelistingWorks(t *testing.T) {
	h := testAPI(t)
	addRider(t, h, adminSignIn(t, h), "9876543210")
	openApprovedStore(t, h, map[string]any{"name": "Guard Store", "location": "Block 32", "city": "LPU", "categories": []string{"Food"}})
	somewhereToDeliver(t, h)
	_, item := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{"title": "Masala Chai", "price": 25, "stock": 5})
	id := item["id"].(string)

	// Nothing ordered yet: the delete is allowed, so the guard is not just
	// refusing everything.
	_, spare := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{"title": "Spare", "price": 10, "stock": 1})
	if code, body := call(t, h, http.MethodDelete, "/api/seller/items/"+spare["id"].(string), nil); code != 204 {
		t.Fatalf("delete of an unordered item: %d %v", code, body)
	}

	if code, body := call(t, h, http.MethodPost, "/api/orders/checkout", map[string]any{
		"lines": []map[string]any{{"itemId": id, "units": 1}}, "requestId": "guard-test-0001", "expectedTotal": 40,
	}); code != 201 {
		t.Fatalf("checkout: %d %v", code, body)
	}

	code, body := call(t, h, http.MethodDelete, "/api/seller/items/"+id, nil)
	if code != http.StatusConflict {
		t.Fatalf("delete of an ordered item should be refused, got %d %v", code, body)
	}

	// The order has to survive the refused delete.
	if _, mine := call(t, h, http.MethodGet, "/api/orders", nil); len(mine["orders"].([]any)) != 1 {
		t.Fatalf("the order did not survive: %v", mine["orders"])
	}

	// Delisting is the way out: off the shop, still in the seller's list.
	if code, body := call(t, h, http.MethodPatch, "/api/seller/items/"+id+"/listing", map[string]any{"delisted": true}); code != 204 {
		t.Fatalf("delist: %d %v", code, body)
	}
	if onSale(callList(t, h, "/api/products"), "Masala Chai") {
		t.Fatal("a delisted item is still in the shop")
	}
	_, seller := call(t, h, http.MethodGet, "/api/seller/items", nil)
	rows := seller["items"].([]any)
	if len(rows) != 1 || rows[0].(map[string]any)["delisted"] != true {
		t.Fatalf("the seller lost sight of their own delisted item: %v", rows)
	}

	// And back on sale.
	if code, body := call(t, h, http.MethodPatch, "/api/seller/items/"+id+"/listing", map[string]any{"delisted": false}); code != 204 {
		t.Fatalf("relist: %d %v", code, body)
	}
	if !onSale(callList(t, h, "/api/products"), "Masala Chai") {
		t.Fatal("relisting did not put it back on the shop")
	}
}

func onSale(rows []any, name string) bool {
	for _, row := range rows {
		if row.(map[string]any)["name"] == name {
			return true
		}
	}
	return false
}
