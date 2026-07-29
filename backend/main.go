package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://lamazon:lamazon@localhost:5433/lamazon?sslmode=disable"
	}
	db, err := OpenDB(dsn)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer db.Close()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Lamazon API on :%s, Postgres ready", port)
	if err := http.ListenAndServe(":"+port, routes(&API{db: db})); err != nil {
		log.Fatal(err)
	}
}

// routes wires every endpoint. Go 1.22 pattern routing, so no router
// dependency. ponytail: one mux, no middleware stack until there is a
// second cross-cutting concern.
func routes(s *API) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Catalog
	mux.HandleFunc("GET /api/products", s.handleProducts)
	mux.HandleFunc("GET /api/products/{id}", s.handleProduct)
	mux.HandleFunc("GET /api/shops", s.handleShops)
	mux.HandleFunc("GET /api/shops/{name}/products", s.handleShopProducts)

	// Delivery area
	mux.HandleFunc("GET /api/locations", handleLocations)
	mux.HandleFunc("GET /api/locations/check", handleLocationCheck)

	// Accounts
	mux.HandleFunc("POST /api/login", handleLogin)

	// Seller
	mux.HandleFunc("GET /api/seller/categories", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, SellCategories)
	})
	mux.HandleFunc("POST /api/seller/store", s.handleCreateStore)
	mux.HandleFunc("GET /api/seller/store", s.handleGetStore)
	mux.HandleFunc("GET /api/seller/items", s.handleItems)
	mux.HandleFunc("POST /api/seller/items", s.handleAddItem)
	mux.HandleFunc("PATCH /api/seller/items/{id}/stock", s.handlePatchStock)
	mux.HandleFunc("DELETE /api/seller/items/{id}", s.handleDeleteItem)
	mux.HandleFunc("GET /api/seller/orders", s.handleOrders)
	mux.HandleFunc("POST /api/seller/orders", s.handlePlaceOrder)
	mux.HandleFunc("POST /api/seller/orders/{id}/accept", s.handleAcceptOrder)
	mux.HandleFunc("POST /api/seller/orders/{id}/deliver", s.handleDeliverOrder)

	return withCORS(mux)
}

// The Flutter web build is served from another origin, so browsers preflight
// anything that is not a plain GET.
func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods",
			"GET, POST, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

var emailPattern = regexp.MustCompile(`^[\w.+-]+@[\w-]+\.[\w.-]+$`)

// POST /api/login — email only, matching the app's sign-in.
func handleLogin(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	email := strings.TrimSpace(in.Email)
	if !emailPattern.MatchString(email) {
		writeError(w, http.StatusBadRequest, "enter a valid email address")
		return
	}
	// ponytail: no password, no token — the app has no protected data yet.
	// Issue a real session here when it does.
	writeJSON(w, http.StatusOK, map[string]string{"email": email})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		log.Printf("encode: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
