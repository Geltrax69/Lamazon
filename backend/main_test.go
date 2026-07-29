package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

// call runs one request against the API and returns status plus decoded body.
func call(t *testing.T, h http.Handler, method, path string, body any) (int, map[string]any) {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatal(err)
		}
	}
	req := httptest.NewRequest(method, path, &buf)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out) // arrays decode as nil, fine
	return rec.Code, out
}

func callList(t *testing.T, h http.Handler, path string) []any {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	var out []any
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("%s: %v (%s)", path, err, rec.Body.String())
	}
	return out
}

func TestCatalogFilters(t *testing.T) {
	h := routes(NewStore())

	all := callList(t, h, "/api/products")
	if len(all) == 0 {
		t.Fatal("catalog is empty")
	}
	if got := callList(t, h, "/api/products?tab=Grocery"); len(got) != 1 {
		t.Fatalf("tab filter: want 1 grocery product, got %d", len(got))
	}
	if got := callList(t, h, "/api/products?q=milk"); len(got) != 1 {
		t.Fatalf("search: want 1 match for milk, got %d", len(got))
	}
	// Filters stack rather than replacing each other.
	if got := callList(t, h, "/api/products?tab=Food&q=milk"); len(got) != 0 {
		t.Fatalf("stacked filters: want 0, got %d", len(got))
	}
	if code, _ := call(t, h, http.MethodGet, "/api/products/nope", nil); code != http.StatusNotFound {
		t.Fatalf("unknown product: want 404, got %d", code)
	}
}

func TestShopStocksOthersListings(t *testing.T) {
	h := routes(NewStore())
	// Milk is listed by Nature Fresh; FreshMart stocks it cheaper.
	items := callList(t, h, "/api/shops/FreshMart/products")
	if len(items) != 1 {
		t.Fatalf("want 1 stocked item, got %d", len(items))
	}
	item := items[0].(map[string]any)
	if item["price"].(float64) != 66 {
		t.Fatalf("want FreshMart price 66, got %v", item["price"])
	}
	if item["store"] != "FreshMart" {
		t.Fatalf("want store FreshMart, got %v", item["store"])
	}
}

func TestLocationOnlyServesCampus(t *testing.T) {
	h := routes(NewStore())
	for _, city := range []string{"LPU", "  lpu, phagwara ", "Lovely Professional University"} {
		_, body := call(t, h, http.MethodGet,
			"/api/locations/check?city="+url.QueryEscape(city), nil)
		if body["serviceable"] != true {
			t.Fatalf("%q should be serviceable", city)
		}
	}
	for _, city := range []string{"Jalandhar", "Mumbai", ""} {
		_, body := call(t, h, http.MethodGet,
			"/api/locations/check?city="+url.QueryEscape(city), nil)
		if body["serviceable"] != false {
			t.Fatalf("%q should not be serviceable", city)
		}
	}
}

func TestLoginValidatesEmail(t *testing.T) {
	h := routes(NewStore())
	if code, _ := call(t, h, http.MethodPost, "/api/login",
		map[string]string{"email": "lalit@lpu.in"}); code != http.StatusOK {
		t.Fatalf("valid email: want 200, got %d", code)
	}
	for _, bad := range []string{"lalit@example", "nope", "@example.com", ""} {
		if code, _ := call(t, h, http.MethodPost, "/api/login",
			map[string]string{"email": bad}); code != http.StatusBadRequest {
			t.Fatalf("%q: want 400, got %d", bad, code)
		}
	}
}

func TestSellerLifecycle(t *testing.T) {
	h := routes(NewStore())

	// Stock cannot exist before a store does.
	if code, _ := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Cold Coffee", "price": 60, "stock": 10}); code != http.StatusConflict {
		t.Fatalf("item before store: want 409, got %d", code)
	}

	// A store outside the delivery area is refused.
	if code, _ := call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "Mumbai",
		"categories": []string{"Food"},
	}); code != http.StatusBadRequest {
		t.Fatalf("unserved city: want 400, got %d", code)
	}

	if code, _ := call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "lpu",
		"categories": []string{"Food"},
	}); code != http.StatusCreated {
		t.Fatalf("create store: want 201, got %d", code)
	}

	code, item := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{
		"title": "Cold Coffee 300ml", "category": "Food", "price": 60, "stock": 10,
	})
	if code != http.StatusCreated {
		t.Fatalf("add item: want 201, got %d", code)
	}
	id := item["id"].(string)
	if item["status"] != "in_stock" {
		t.Fatalf("10 units should be in_stock, got %v", item["status"])
	}

	// Price and stock are validated.
	if code, _ := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Free", "price": 0, "stock": 1}); code != http.StatusBadRequest {
		t.Fatalf("zero price: want 400, got %d", code)
	}

	// Ordering more than exists is refused.
	if code, _ := call(t, h, http.MethodPost, "/api/seller/orders",
		map[string]any{"itemId": id, "units": 99}); code != http.StatusConflict {
		t.Fatalf("oversized order: want 409, got %d", code)
	}

	_, order := call(t, h, http.MethodPost, "/api/seller/orders",
		map[string]any{"itemId": id, "units": 2})
	orderID := order["id"].(string)
	if order["amount"].(float64) != 120 {
		t.Fatalf("2 x 60 should be 120, got %v", order["amount"])
	}

	// Accepting reserves; delivering is what removes the units.
	call(t, h, http.MethodPost, "/api/seller/orders/"+orderID+"/accept", nil)
	_, body := call(t, h, http.MethodGet, "/api/seller/items", nil)
	items := body["items"].([]any)
	if items[0].(map[string]any)["stock"].(float64) != 10 {
		t.Fatal("accepting must not change stock")
	}

	call(t, h, http.MethodPost, "/api/seller/orders/"+orderID+"/deliver", nil)
	_, body = call(t, h, http.MethodGet, "/api/seller/items", nil)
	items = body["items"].([]any)
	if got := items[0].(map[string]any)["stock"].(float64); got != 8 {
		t.Fatalf("delivering 2 of 10 should leave 8, got %v", got)
	}
	summary := body["summary"].(map[string]any)
	if summary["inventoryValue"].(float64) != 480 {
		t.Fatalf("8 x 60 should be 480, got %v", summary["inventoryValue"])
	}

	// Delivering twice is refused rather than double-decrementing.
	if code, _ := call(t, h, http.MethodPost,
		"/api/seller/orders/"+orderID+"/deliver", nil); code != http.StatusConflict {
		t.Fatalf("second deliver: want 409, got %d", code)
	}
}

func TestStockNeverGoesNegative(t *testing.T) {
	h := routes(NewStore())
	call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "S", "location": "L", "city": "LPU", "categories": []string{"Food"},
	})
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Sandwich", "price": 40, "stock": 3})
	id := item["id"].(string)

	_, patched := call(t, h, http.MethodPatch, "/api/seller/items/"+id+"/stock",
		map[string]any{"delta": -10})
	if patched["stock"].(float64) != 0 {
		t.Fatalf("stock floors at 0, got %v", patched["stock"])
	}
	if patched["status"] != "sold_out" {
		t.Fatalf("0 units is sold_out, got %v", patched["status"])
	}
}
