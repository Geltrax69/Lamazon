package main

import "time"

// Product is one listing in the catalog.
type Product struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Category    string  `json:"category"`
	Tab         string  `json:"tab"`
	Price       float64 `json:"price"`
	ImageURL    string  `json:"imageUrl"`
	Store       string  `json:"store"`
	Description string  `json:"description"`
	Offers      []Offer `json:"offers,omitempty"`
}

// Offer is the same product priced at another vendor.
type Offer struct {
	Store string  `json:"store"`
	Price float64 `json:"price"`
}

type Shop struct {
	Name     string `json:"name"`
	Tagline  string `json:"tagline"`
	ImageURL string `json:"imageUrl"`
	Tab      string `json:"tab"`
}

type SellerStore struct {
	Owner      string   `json:"owner"` // email the seller signed in with
	Name       string   `json:"name"`
	Location   string   `json:"location"`
	City       string   `json:"city"`
	Categories []string `json:"categories"`
}

// InventoryItem is one line of a seller's stock.
type InventoryItem struct {
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Category    string  `json:"category"`
	Price       float64 `json:"price"`
	Stock       int     `json:"stock"`
	Status      string  `json:"status"` // derived from stock, never stored
}

// LowStockAt is the threshold below which an item is flagged for restocking.
const LowStockAt = 5

func stockStatus(stock int) string {
	switch {
	case stock <= 0:
		return "sold_out"
	case stock <= LowStockAt:
		return "low"
	default:
		return "in_stock"
	}
}

type OrderStage string

const (
	StageReceived  OrderStage = "received"
	StageAccepted  OrderStage = "accepted"
	StageDelivered OrderStage = "delivered"
)

type Order struct {
	ID        string     `json:"id"`
	ItemID    string     `json:"itemId"`
	ItemTitle string     `json:"itemTitle"`
	Units     int        `json:"units"`
	Amount    float64    `json:"amount"`
	Stage     OrderStage `json:"stage"`
	PlacedAt  time.Time  `json:"placedAt"`
}

// DefaultOwner stands in until the app sends a real session. Callers can
// override it with ?owner= or the X-User-Email header.
const DefaultOwner = "demo@lamazon.app"
