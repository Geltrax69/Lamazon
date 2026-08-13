package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// End to end through the real handler: two listings in one group come back
// ranked, with the derived row and the highlights the shopper reads first.
func TestCompareRanksTwoListings(t *testing.T) {
	db := testDB(t)
	h := routes(&API{db: db})

	// A group whose weight field is both ranked and the price basis.
	template := `[{"name":"Weight","unit":"g","mode":"higher_better","perUnit":true},
	              {"name":"Flavour"}]`
	// comparison_groups is not in the harness truncate list — it is catalog,
	// not per-test data — so this both survives a previous run and cleans up
	// after itself rather than leaving a group behind for the next one.
	if _, err := db.sql.Exec(
		`INSERT INTO comparison_groups (name, attributes) VALUES ('Chips', $1)
		 ON CONFLICT (name) DO UPDATE SET attributes = EXCLUDED.attributes`,
		template); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		db.sql.Exec(`DELETE FROM comparison_groups WHERE name = 'Chips'`)
	})
	if _, err := db.sql.Exec(
		`INSERT INTO seller_stores (owner, name, location, city, status)
		 VALUES ('a@x.com', 'Corner Shop', 'Phagwara', 'Phagwara', 'approved')`); err != nil {
		t.Fatal(err)
	}
	for _, it := range []struct {
		title string
		price float64
		attrs string
	}{
		{"Balaji", 60, `{"Weight":"200","Flavour":"Masala"}`},
		{"Lay's", 120, `{"Weight":"500","Flavour":"Classic"}`},
	} {
		if _, err := db.sql.Exec(
			`INSERT INTO inventory_items
			   (owner, title, price, stock, compare_group, attributes)
			 VALUES ('a@x.com', $1, $2, 5, 'Chips', $3)`,
			it.title, it.price, it.attrs); err != nil {
			t.Fatal(err)
		}
	}

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/compare?group=Chips", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("want 200, got %d: %s", rec.Code, rec.Body)
	}

	var body struct {
		Attributes []struct {
			Name   string `json:"name"`
			Mode   string `json:"mode"`
			Winner string `json:"winner"`
		} `json:"attributes"`
		Derived []struct {
			Name   string             `json:"name"`
			Values map[string]float64 `json:"values"`
			Winner string             `json:"winner"`
		} `json:"derived"`
		Highlights []string `json:"highlights"`
		Products   []struct {
			ID    string `json:"id"`
			Title string `json:"title"`
		} `json:"products"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}

	id := map[string]string{}
	for _, p := range body.Products {
		id[p.Title] = p.ID
	}
	if body.Attributes[0].Winner != id["Lay's"] {
		t.Errorf("weight should go to the 500g pack")
	}
	if body.Attributes[1].Winner != "" {
		t.Errorf("flavour has no mode and must not be ranked")
	}
	if len(body.Derived) != 1 || body.Derived[0].Name != "₹ / 100 g" {
		t.Fatalf("derived row missing: %+v", body.Derived)
	}
	if body.Derived[0].Values[id["Balaji"]] != 30 ||
		body.Derived[0].Values[id["Lay's"]] != 24 {
		t.Errorf("₹/100g wrong: %v", body.Derived[0].Values)
	}
	if body.Derived[0].Winner != id["Lay's"] {
		t.Errorf("value winner should be the 500g pack")
	}
	// The cheapest pack and the best value are different products, and the
	// shopper is told both.
	if len(body.Highlights) < 2 || body.Highlights[0] != "Balaji costs the least" {
		t.Errorf("highlights: %v", body.Highlights)
	}
}
