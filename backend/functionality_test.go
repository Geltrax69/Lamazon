package main

import (
	"context"
	"net/http"
	"strings"
	"sync"
	"testing"
)

func TestAddressValidationAndOwnership(t *testing.T) {
	h := testAPI(t)
	for _, bad := range []map[string]any{
		{"line": "Room 1", "city": "LPU", "phone": "abcdefghijabc12"},
		{"line": "Room 1", "city": "LPU", "name": strings.Repeat("a", 101)},
		{"line": "Room 1", "city": "LPU", "name": "<script>alert(1)</script>"},
		{"line": strings.Repeat("a", 301), "city": "LPU"},
		{"line": "Room 1", "city": "LPU", "pincode": "abc123"},
	} {
		if code, _ := call(t, h, "POST", "/api/addresses", bad); code != 400 {
			t.Fatalf("invalid address accepted: %d", code)
		}
	}
	code, address := call(t, h, "POST", "/api/addresses", map[string]any{"line": "Room 1", "city": "LPU", "phone": "+91 9876543210", "name": "Lalit"})
	if code != 201 || address["phone"] != "9876543210" {
		t.Fatalf("valid address: %d %v", code, address)
	}
	id := address["id"].(string)
	stranger := signIn(t, lastTestDB, "stranger@example.com")
	for _, path := range []string{"/api/addresses/" + id, "/api/addresses/" + id + "/default"} {
		code, _ = callAs(t, h, stranger, "PATCH", path, map[string]any{"line": "Other room", "city": "LPU"})
		if code != 404 {
			t.Fatalf("cross-account change: %d", code)
		}
	}
	code, address = call(t, h, "PATCH", "/api/addresses/"+id, map[string]any{"line": "Room 2", "city": "LPU", "name": "Recipient", "phone": "9999999999"})
	if code != 200 || address["line"] != "Room 2" || address["isDefault"] != true {
		t.Fatalf("edit: %d %v", code, address)
	}
}

func TestConcurrentAddressDefaultsAndSelection(t *testing.T) {
	h := testAPI(t)
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			code, _ := call(t, h, "POST", "/api/addresses", map[string]any{"line": "Room", "city": "LPU", "isDefault": true})
			if code != 201 {
				t.Errorf("save %d", code)
			}
		}()
	}
	wg.Wait()
	rows := callList(t, h, "/api/addresses")
	defaults := 0
	for _, r := range rows {
		if r.(map[string]any)["isDefault"] == true {
			defaults++
		}
	}
	if len(rows) != 8 || defaults != 1 {
		t.Fatalf("rows=%d defaults=%d", len(rows), defaults)
	}
	id := rows[len(rows)-1].(map[string]any)["id"].(string)
	if code, _ := call(t, h, "PATCH", "/api/addresses/"+id+"/default", nil); code != 204 {
		t.Fatal(code)
	}
	if callList(t, h, "/api/addresses")[0].(map[string]any)["id"] != id {
		t.Fatal("default selection did not persist")
	}
	call(t, h, "DELETE", "/api/addresses/"+id, nil)
	if callList(t, h, "/api/addresses")[0].(map[string]any)["isDefault"] != true {
		t.Fatal("default not replaced after deletion")
	}
}

func TestPreferencesPersistAndSuppressNotifications(t *testing.T) {
	h := testAPI(t)
	code, prefs := call(t, h, "PATCH", "/api/preferences", map[string]bool{"orderUpdates": false, "emailOffers": true})
	if code != 200 || prefs["orderUpdates"] != false || prefs["push"] != true {
		t.Fatalf("preferences: %d %v", code, prefs)
	}
	stored, err := (&API{db: lastTestDB}).preferences(context.Background(), DefaultOwner)
	if err != nil || stored.OrderUpdates || !stored.EmailOffers {
		t.Fatalf("stored: %v %v", stored, err)
	}
	call(t, h, "PATCH", "/api/preferences", map[string]bool{"push": false})
	_, prefs = call(t, h, "GET", "/api/preferences", nil)
	if prefs["orderUpdates"] != false || prefs["push"] != false || prefs["emailOffers"] != true {
		t.Fatal("patch overwrote other preferences")
	}
	if code, _ := callAs(t, h, "", "GET", "/api/preferences", nil); code != http.StatusUnauthorized {
		t.Fatal("guest preferences exposed")
	}
}

func TestProductLimitsReturnValidationErrors(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{"name": "Store", "location": "Block 1", "city": "LPU", "categories": []string{"Food"}})
	for _, bad := range []map[string]any{
		{"title": strings.Repeat("x", 161), "price": 20, "stock": 1},
		{"title": "Bad", "price": 1000000, "stock": 1},
		{"title": "Bad", "price": 1.001, "stock": 1},
		{"title": "Bad", "price": 20, "stock": 1, "category": "NotARealCategory"},
		{"title": "Bad", "price": 20, "stock": 1, "mrp": 1000000},
	} {
		code, body := call(t, h, "POST", "/api/seller/items", bad)
		if code != 400 || strings.Contains(body["error"].(string), "SQLSTATE") {
			t.Fatalf("bad product: %d %v", code, body)
		}
	}
}

func TestOrderNotificationHonorsPreferences(t *testing.T) {
	h, sent, push := notifyAPI(t)
	openApprovedStore(t, h, map[string]any{"name": "Store", "location": "Block 1", "city": "LPU", "categories": []string{"Food"}})
	somewhereToDeliver(t, h)
	_, item := call(t, h, "POST", "/api/seller/items", map[string]any{"title": "Food", "price": 20, "stock": 10})
	call(t, h, "POST", "/api/push/subscribe", map[string]string{"token": "device-token"})
	call(t, h, "PATCH", "/api/preferences", map[string]bool{"orderUpdates": false})
	mails, pushes := sent.count, push.count()
	if code, body := call(t, h, "POST", "/api/orders", map[string]any{"itemId": item["id"], "units": 1, "expectedTotal": 35}); code != 201 {
		t.Fatalf("order %d %v", code, body)
	}
	if sent.count != mails || push.count() != pushes {
		t.Fatal("order opt-out was ignored")
	}
	call(t, h, "PATCH", "/api/preferences", map[string]bool{"orderUpdates": true, "push": false})
	call(t, h, "POST", "/api/orders", map[string]any{"itemId": item["id"], "units": 1, "expectedTotal": 35})
	if sent.count != mails+1 || push.count() != pushes {
		t.Fatal("push opt-out should still allow order email")
	}
}
