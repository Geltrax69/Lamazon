package main

import (
	"embed"
	"fmt"
	"html/template"
	"net/http"
	"strings"
)

// The shop window: plain server-rendered HTML, no framework and no build step.
//
// The Flutter app is the right tool for the parts behind a sign-in — carts,
// checkout, the seller and admin panels — but it is the wrong one for a page a
// stranger lands on. It ships its own renderer: about 2.7 MB of WebAssembly
// that a browser must download *and compile* before it can draw a single
// pixel. Measured on the live build, first visit, cache cold: 4.4s on a good
// phone, 8.1s on a mid-range one, 17.4s on a budget phone over slow 4G. Over
// half of mobile visitors leave before three.
//
// These pages have none of that. They are HTML and one inlined stylesheet, so
// the first paint is the first packet — and, unlike a canvas, a search engine
// can read the prices.
//
// Everything here is read-only and public. Nothing in this file touches a
// session, so there is no cookie to get wrong and no cache to poison.

//go:embed templates/*.html
var storefrontFiles embed.FS

var storefront = template.Must(
	template.New("").Funcs(storefrontFuncs).ParseFS(storefrontFiles, "templates/*.html"),
)

var storefrontFuncs = template.FuncMap{
	"money":    money,
	"thumb":    func(url string) string { return catalogueImage(url, 300) },
	"hero":     func(url string) string { return catalogueImage(url, 800) },
	"discount": discountPercent,
	"hasPrice": func(p Product) bool { return p.MRP > p.Price },
	// Stock is a pointer because "not tracked" and "none left" are different
	// answers, and a template cannot follow one on its own.
	"deref": func(v *int) int {
		if v == nil {
			return 0
		}
		return *v
	},
}

// money writes a rupee amount the way it is read here: grouped in lakhs, and
// with the paise left off when there are none. Mirrors MoneyText in the app so
// a price does not change shape when Flutter takes over the page.
func money(v float64) string {
	paise := int64(v*100 + 0.5)
	whole, rem := paise/100, paise%100
	digits := fmt.Sprintf("%d", whole)
	if len(digits) > 3 {
		head, tail := digits[:len(digits)-3], digits[len(digits)-3:]
		var parts []string
		for len(head) > 2 {
			parts = append([]string{head[len(head)-2:]}, parts...)
			head = head[:len(head)-2]
		}
		if head != "" {
			parts = append([]string{head}, parts...)
		}
		digits = strings.Join(parts, ",") + "," + tail
	}
	if rem == 0 {
		return digits
	}
	return fmt.Sprintf("%s.%02d", digits, rem)
}

func discountPercent(p Product) int {
	if p.MRP <= p.Price {
		return 0
	}
	return int((p.MRP-p.Price)/p.MRP*100 + 0.5)
}

// catalogueImage asks the CDN for the size actually being drawn, in the same
// buckets the app uses so the two share a cache rather than doubling it.
func catalogueImage(url string, width int) string {
	const marker = "/image/upload/"
	if url == "" || !strings.Contains(url, marker) {
		return url
	}
	if strings.Contains(url, "c_fill") || strings.Contains(url, "c_pad") ||
		strings.Contains(url, "c_limit") {
		return url
	}
	return strings.Replace(url, marker, fmt.Sprintf(
		"%sc_fill,ar_1:1,g_auto,e_improve:30,w_%d,f_auto,q_auto/", marker, bucket(width)), 1)
}

func bucket(width int) int {
	for _, size := range []int{160, 300, 400, 800} {
		if width <= size {
			return size
		}
	}
	return 1200
}

type storePage struct {
	Title       string
	Description string
	Query       string
	Products    []Product
	Product     Product
	Departments []string
	Canonical   string
}

func (a *API) render(w http.ResponseWriter, name string, page storePage) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	// A shop window goes stale in minutes, not days. The CDN may serve a
	// slightly old page instantly while it fetches a fresh one behind — which
	// is the whole trick that makes this feel instant on a repeat visit.
	w.Header().Set("Cache-Control", "public, max-age=60, stale-while-revalidate=600")
	if err := storefront.ExecuteTemplate(w, name, page); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
	}
}

// GET / — the shop window.
func (a *API) handleStoreHome(w http.ResponseWriter, r *http.Request) {
	// Anything other than the root is a product or a page that does not exist;
	// without this "/" would answer for every unmatched path.
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	items, err := a.db.products(r.Context(), productFilter{})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	a.render(w, "home.html", storePage{
		Title:       "Lamazon — local shops, delivered on campus",
		Description: "Order from shops around campus. Real stock, real prices, cash on delivery.",
		Products:    items,
		Departments: departmentsOf(items),
		Canonical:   "/",
	})
}

// GET /p/{id} — one product, readable by a person and by a crawler.
func (a *API) handleStoreProduct(w http.ResponseWriter, r *http.Request) {
	p, err := a.db.product(r.Context(), r.PathValue("id"))
	if err != nil {
		http.NotFound(w, r)
		return
	}
	summary := p.Description
	if len(summary) > 150 {
		summary = summary[:150] + "…"
	}
	a.render(w, "product.html", storePage{
		Title:       p.Name + " — ₹" + money(p.Price) + " from " + p.Store,
		Description: summary,
		Product:     p,
		Canonical:   "/p/" + p.ID,
	})
}

// GET /search?q= — the same list the app searches, as a page.
func (a *API) handleStoreSearch(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	items, err := a.db.products(r.Context(), productFilter{Q: q})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	title := "Search — Lamazon"
	if q != "" {
		title = q + " — Lamazon"
	}
	a.render(w, "search.html", storePage{
		Title:       title,
		Description: "Search the shops around campus.",
		Query:       q,
		Products:    items,
		Canonical:   "/search",
	})
}

// GET /login — the sign-in form, usable before the app could have booted.
//
// The only page here that needs JavaScript, because signing in is a
// conversation with the API rather than a document. The markup and the styling
// still arrive rendered, so the form is on screen and typeable in a couple of
// hundred milliseconds; the script only wakes up when somebody presses a
// button.
func (a *API) handleStoreLogin(w http.ResponseWriter, r *http.Request) {
	a.render(w, "login.html", storePage{
		Title:       "Log in — Lamazon",
		Description: "Sign in to order from shops around campus.",
		Canonical:   "/login",
	})
}

// departmentsOf lists the tabs the catalogue actually has stock in, in the
// order they first appear, so an empty department never gets a chip.
func departmentsOf(items []Product) []string {
	seen := map[string]bool{}
	var out []string
	for _, p := range items {
		if p.Tab != "" && !seen[p.Tab] {
			seen[p.Tab] = true
			out = append(out, p.Tab)
		}
	}
	return out
}
