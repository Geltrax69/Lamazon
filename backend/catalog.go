package main

import (
	"net/http"
	"strings"
)

// API serves every endpoint off Postgres.
type API struct{ db *DB }

// GET /api/products?tab=&category=&q=
// Filters stack, so ?tab=Grocery&q=milk narrows twice.
func (a *API) handleProducts(w http.ResponseWriter, r *http.Request) {
	all, err := a.db.products(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	tab := r.URL.Query().Get("tab")
	category := r.URL.Query().Get("category")
	q := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("q")))

	out := make([]Product, 0, len(all))
	for _, p := range all {
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
func (a *API) handleProduct(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	all, err := a.db.products(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	for _, p := range all {
		if p.ID == id {
			writeJSON(w, http.StatusOK, p)
			return
		}
	}
	writeError(w, http.StatusNotFound, "no product with id "+id)
}

// GET /api/shops?tab=
func (a *API) handleShops(w http.ResponseWriter, r *http.Request) {
	all, err := a.db.shops(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	tab := r.URL.Query().Get("tab")
	out := make([]Shop, 0, len(all))
	for _, shop := range all {
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
func (a *API) handleShopProducts(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	all, err := a.db.products(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	out := make([]Product, 0)
	for _, p := range all {
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
	resolved, ok := resolveCity(r.URL.Query().Get("city"))
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

// owner identifies the seller. ponytail: header or query until the app has
// real sessions; swap for the token subject then.
func owner(r *http.Request) string {
	if e := r.Header.Get("X-User-Email"); e != "" {
		return strings.ToLower(strings.TrimSpace(e))
	}
	if e := r.URL.Query().Get("owner"); e != "" {
		return strings.ToLower(strings.TrimSpace(e))
	}
	return DefaultOwner
}
