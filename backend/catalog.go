package main

import (
	"net/http"
	"strings"
)

// GET /api/products?tab=&category=&q=
// Filters stack, so ?tab=Grocery&q=milk narrows twice.
func (s *Store) handleProducts(w http.ResponseWriter, r *http.Request) {
	tab := r.URL.Query().Get("tab")
	category := r.URL.Query().Get("category")
	q := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("q")))

	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make([]Product, 0, len(s.products))
	for _, p := range s.products {
		if tab != "" && !strings.EqualFold(tab, "all") && !strings.EqualFold(p.Tab, tab) {
			continue
		}
		if category != "" && !strings.EqualFold(p.Category, category) {
			continue
		}
		if q != "" && !matches(p, q) {
			continue
		}
		out = append(out, p)
	}
	writeJSON(w, http.StatusOK, out)
}

func matches(p Product, q string) bool {
	return strings.Contains(strings.ToLower(p.Name), q) ||
		strings.Contains(strings.ToLower(p.Category), q) ||
		strings.Contains(strings.ToLower(p.Store), q)
}

// GET /api/products/{id}
func (s *Store) handleProduct(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, p := range s.products {
		if p.ID == id {
			writeJSON(w, http.StatusOK, p)
			return
		}
	}
	writeError(w, http.StatusNotFound, "no product with id "+id)
}

// GET /api/shops?tab=
func (s *Store) handleShops(w http.ResponseWriter, r *http.Request) {
	tab := r.URL.Query().Get("tab")
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make([]Shop, 0, len(s.shops))
	for _, shop := range s.shops {
		if tab != "" && !strings.EqualFold(tab, "all") && !strings.EqualFold(shop.Tab, tab) {
			continue
		}
		out = append(out, shop)
	}
	writeJSON(w, http.StatusOK, out)
}

// GET /api/shops/{name}/products
// Everything the shop sells: its own listings, plus items it stocks that are
// listed elsewhere, each priced at this shop's price.
func (s *Store) handleShopProducts(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make([]Product, 0)
	for _, p := range s.products {
		if strings.EqualFold(p.Store, name) {
			out = append(out, p)
			continue
		}
		for _, o := range p.Offers {
			if !strings.EqualFold(o.Store, name) {
				continue
			}
			stocked := p
			stocked.ID = p.ID + "@" + name
			stocked.Price = o.Price
			stocked.Store = name
			// Compare against the original listing and the other vendors.
			stocked.Offers = append([]Offer{{Store: p.Store, Price: p.Price}},
				othersThan(p.Offers, name)...)
			out = append(out, stocked)
			break
		}
	}
	writeJSON(w, http.StatusOK, out)
}

func othersThan(offers []Offer, store string) []Offer {
	out := make([]Offer, 0, len(offers))
	for _, o := range offers {
		if !strings.EqualFold(o.Store, store) {
			out = append(out, o)
		}
	}
	return out
}

// GET /api/locations — where delivery is available.
func handleLocations(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"cities": ServiceableCities,
		"eta":    "12 mins",
	})
}

// GET /api/locations/check?city=
func handleLocationCheck(w http.ResponseWriter, r *http.Request) {
	city := r.URL.Query().Get("city")
	resolved, ok := resolveCity(city)
	writeJSON(w, http.StatusOK, map[string]any{
		"city":        resolved,
		"serviceable": ok,
	})
}

// resolveCity accepts the shorthands people actually type ("lpu", extra
// spaces, any casing) and reports the canonical name.
func resolveCity(city string) (string, bool) {
	q := strings.ToLower(strings.TrimSpace(city))
	if q == "" {
		return "", false
	}
	if canonical, ok := cityAliases[q]; ok {
		return canonical, true
	}
	for _, c := range ServiceableCities {
		if strings.EqualFold(c, q) {
			return c, true
		}
	}
	return strings.TrimSpace(city), false
}
