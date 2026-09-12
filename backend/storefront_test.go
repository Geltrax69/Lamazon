package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// The shop window exists because the Flutter bundle cannot serve a stranger:
// first visit, cache cold, it was 4.4s on a good phone and 17.4s on a budget
// one. These pages have to stay what makes them fast — HTML with the prices
// already in it, no script, and nothing that needs a session.

// getHTML asks for a page the way a browser or a crawler would: no token, no
// JSON, just a GET.
func getHTML(t *testing.T, h http.Handler, path string) (int, string) {
	t.Helper()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec.Code, rec.Body.String()
}

func TestStorefrontServesProductsAsHTML(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "PURE BITES", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	if code, body := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{
		"title": "Aloo Tikki Burger", "price": 69, "mrp": 79, "stock": 8,
		"category": "Food", "description": "Golden-fried potato tikki.",
	}); code != 201 {
		t.Fatalf("could not list a product: %d %v", code, body)
	}

	code, page := getHTML(t, h, "/")
	if code != 200 {
		t.Fatalf("home: %d", code)
	}
	// The whole point: the price is in the HTML, not fetched by a script
	// after a renderer has booted.
	for _, want := range []string{"Aloo Tikki Burger", "69", "PURE BITES", "13% off"} {
		if !strings.Contains(page, want) {
			t.Errorf("home does not mention %q", want)
		}
	}
	if strings.Contains(page, "<script") {
		t.Error("the shop window must not need JavaScript to show a price")
	}
}

func TestStorefrontProductPageIsReadableByACrawler(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "PURE BITES", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	_, created := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{
		"title": "Aloo Tikki Burger", "price": 69, "stock": 3,
		"category": "Food", "description": "Golden-fried potato tikki.",
	})
	id, _ := created["id"].(string)

	code, page := getHTML(t, h, "/p/"+id)
	if code != 200 {
		t.Fatalf("product page: %d", code)
	}
	// A canvas app gives a search engine an empty page. This has to give it
	// the name, the price and the description.
	for _, want := range []string{
		"<title>Aloo Tikki Burger", `name="description"`,
		"Golden-fried potato tikki.", "<h1>Aloo Tikki Burger</h1>",
	} {
		if !strings.Contains(page, want) {
			t.Errorf("product page is missing %q", want)
		}
	}

	if code, _ := getHTML(t, h, "/p/does-not-exist"); code != http.StatusNotFound {
		t.Errorf("an unknown product should 404, got %d", code)
	}
	// "/" is registered as a pattern, so it must not answer for stray paths.
	if code, _ := getHTML(t, h, "/nonsense"); code != http.StatusNotFound {
		t.Errorf("an unknown path should 404, got %d", code)
	}
}

func TestStorefrontSearchFiltersAndSaysSo(t *testing.T) {
	h := testAPI(t)
	openApprovedStore(t, h, map[string]any{
		"name": "PURE BITES", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})
	for _, name := range []string{"Aloo Tikki Burger", "Paneer Sandwich"} {
		call(t, h, http.MethodPost, "/api/seller/items", map[string]any{
			"title": name, "price": 69, "stock": 3, "category": "Food",
			"description": "d",
		})
	}

	code, page := getHTML(t, h, "/search?q=burger")
	if code != 200 {
		t.Fatalf("search: %d", code)
	}
	if !strings.Contains(page, "Aloo Tikki Burger") {
		t.Error("search dropped the thing that matched")
	}
	if strings.Contains(page, "Paneer Sandwich") {
		t.Error("search kept something that did not match")
	}
	// The query is echoed so the box still holds it after a reload, and it is
	// escaped rather than pasted in.
	if _, page := getHTML(t, h, "/search?q=%3Cscript%3E"); strings.Contains(page, "<script>") {
		t.Error("the query is written into the page unescaped")
	}
}

func TestMoneyReadsTheWayARupeeIsWritten(t *testing.T) {
	for _, c := range []struct {
		in   float64
		want string
	}{
		{69, "69"}, {999, "999"}, {1499, "1,499"}, {59999, "59,999"},
		{88690, "88,690"}, {100000, "1,00,000"}, {1234567, "12,34,567"},
		{69.5, "69.50"}, {0.1, "0.10"}, {0, "0"},
	} {
		if got := money(c.in); got != c.want {
			t.Errorf("money(%v) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestCatalogueImageAsksForTheSizeItDraws(t *testing.T) {
	const raw = "https://res.cloudinary.com/x/image/upload/v1/Lamazon/a.png"
	if got := catalogueImage(raw, 300); !strings.Contains(got, "w_300") {
		t.Errorf("card image should ask for w_300, got %q", got)
	}
	if got := catalogueImage(raw, 800); !strings.Contains(got, "w_800") {
		t.Errorf("hero image should ask for w_800, got %q", got)
	}
	// Transforming twice would crop the crop.
	once := catalogueImage(raw, 300)
	if catalogueImage(once, 800) != once {
		t.Error("an already-transformed URL was transformed again")
	}
	if got := catalogueImage("", 300); got != "" {
		t.Errorf("an empty URL should stay empty, got %q", got)
	}
	if got := catalogueImage("https://example.test/a.png", 300); got != "https://example.test/a.png" {
		t.Error("a non-Cloudinary URL should pass straight through")
	}
}

// The sign-in page is the one here that needs a script, because signing in is
// a conversation rather than a document. What must not regress is that the
// form is already *rendered* — a stranger can start typing before the app
// could have compiled — and that it hands over to the app under the key names
// session_handoff_test.dart pins on the other side.
func TestStorefrontLoginIsRenderedNotAssembled(t *testing.T) {
	h := testAPI(t)
	code, page := getHTML(t, h, "/login")
	if code != 200 {
		t.Fatalf("login page: %d", code)
	}
	for _, want := range []string{
		`<form`, `id="who"`, `type="email"`, `autocomplete="email"`,
		"Log in or sign up",
	} {
		if !strings.Contains(page, want) {
			t.Errorf("the form is not in the HTML: missing %q", want)
		}
	}
	// The handoff contract. Renaming either side without the other silently
	// signs everybody in twice.
	for _, key := range []string{
		"flutter.", "session.email", "session.token",
		"session.refresh", "session.expiresAt",
	} {
		if !strings.Contains(page, key) {
			t.Errorf("the handoff no longer writes %q — see session_handoff_test.dart", key)
		}
	}
	// It posts to the endpoints that exist rather than inventing its own.
	for _, path := range []string{"/api/login", "/api/login/verify", "/api/login/password"} {
		if !strings.Contains(page, path) {
			t.Errorf("login page does not call %s", path)
		}
	}
}
