package main

import "time"

// Product is one listing in the catalog.
type Product struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Category string  `json:"category"`
	Tab      string  `json:"tab"`
	Price    float64 `json:"price"`
	ImageURL string  `json:"imageUrl"`
	// Every photo, in upload order. A seller's item can carry several; the
	// seeded rows have one. imageUrl stays the cover so old callers still work.
	ImageURLs   []string `json:"imageUrls"`
	Store       string   `json:"store"`
	Description string   `json:"description"`
	Offers      []Offer  `json:"offers,omitempty"`
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
	PhotoURL   string   `json:"photoUrl"` // Cloudinary, empty until uploaded
	// pending until an admin looks at it, then approved or rejected with a
	// reason. Only an approved store is visible to shoppers or may hold stock.
	Status       string `json:"status"`
	RejectReason string `json:"rejectReason,omitempty"`
}

// InventoryItem is one line of a seller's stock.
type InventoryItem struct {
	ID          string   `json:"id"`
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Category    string   `json:"category"`
	Price       float64  `json:"price"`
	Stock       int      `json:"stock"`
	Status      string   `json:"status"`    // derived from stock, never stored
	ImageURLs   []string `json:"imageUrls"` // Cloudinary, in upload order
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
	StageRejected  OrderStage = "rejected"
	StagePicked    OrderStage = "picked"
	StageDelivered OrderStage = "delivered"
)

// Order is one line bought from one store, and the whole trail behind it:
// who it is for, which store owes it, which rider has it.
//
// The receiver is copied in at the moment of ordering rather than joined from
// the address book — editing an address later must not redirect a bag that is
// already out.
type Order struct {
	ID        string     `json:"id"`
	ItemID    string     `json:"itemId"`
	ItemTitle string     `json:"itemTitle"`
	Units     int        `json:"units"`
	Amount    float64    `json:"amount"`
	Stage     OrderStage `json:"stage"`
	PlacedAt  time.Time  `json:"placedAt"`

	StoreOwner string `json:"storeOwner,omitempty"`
	StoreName  string `json:"storeName,omitempty"`
	BuyerEmail string `json:"buyerEmail,omitempty"`

	// Where the rider collects. Read from the store rather than copied onto
	// the order: a shop that moves should move for orders already in flight,
	// which is the opposite of what we want for the delivery address.
	StoreAddress string `json:"storeAddress,omitempty"`

	ReceiverName    string `json:"receiverName,omitempty"`
	ReceiverPhone   string `json:"receiverPhone,omitempty"`
	ReceiverAddress string `json:"receiverAddress,omitempty"`

	RejectReason string `json:"rejectReason,omitempty"`
	RiderPhone   string `json:"riderPhone,omitempty"`

	// Who the admin put on it, before anyone picks it up. Empty means the
	// first rider to claim it gets it.
	AssignedTo string `json:"assignedTo,omitempty"`

	// The four digits the buyer reads out at the door. Filled in only on the
	// buyer's own copy of the order; the rider is never told it, which is the
	// whole point of it.
	DeliveryCode string `json:"deliveryCode,omitempty"`
}

// DefaultOwner stands in until the app sends a real session. Callers can
// override it with ?owner= or the X-User-Email header.
const DefaultOwner = "demo@lamazon.app"
