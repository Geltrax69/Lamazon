package main

import (
	"sync"
	"time"
)

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
	Name       string   `json:"name"`
	Location   string   `json:"location"`
	City       string   `json:"city"`
	Categories []string `json:"categories"`
	Owner      string   `json:"owner"` // email of the seller
}

// InventoryItem is one line of a seller's stock.
type InventoryItem struct {
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Category    string  `json:"category"`
	Price       float64 `json:"price"`
	Stock       int     `json:"stock"`
	Status      string  `json:"status"` // derived, never stored
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

// Store holds everything the API serves. ponytail: in-memory behind a mutex,
// same shape as the Flutter side. Swap the maps for a database when the data
// has to outlive the process; the handlers do not change.
type Store struct {
	mu sync.RWMutex

	products []Product
	shops    []Shop

	sellerStore *SellerStore
	items       []InventoryItem
	orders      []Order

	nextID int
}

func NewStore() *Store {
	return &Store{products: seedProducts(), shops: seedShops()}
}

func (s *Store) id(prefix string) string {
	s.nextID++
	return prefix + "-" + time.Now().Format("150405") + "-" + itoa(s.nextID)
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b []byte
	for n > 0 {
		b = append([]byte{byte('0' + n%10)}, b...)
		n /= 10
	}
	return string(b)
}
