package main

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"
)

// POST /api/seller/store — opens the seller's store.
func (s *Store) handleCreateStore(w http.ResponseWriter, r *http.Request) {
	var in SellerStore
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	in.Name = strings.TrimSpace(in.Name)
	in.Location = strings.TrimSpace(in.Location)
	if in.Name == "" || in.Location == "" || len(in.Categories) == 0 {
		writeError(w, http.StatusBadRequest,
			"name, location and at least one category are required")
		return
	}
	city, ok := resolveCity(in.City)
	if !ok {
		writeError(w, http.StatusBadRequest,
			"we only deliver around "+ServiceableCities[0])
		return
	}
	in.City = city

	s.mu.Lock()
	defer s.mu.Unlock()
	s.sellerStore = &in
	writeJSON(w, http.StatusCreated, in)
}

// GET /api/seller/store
func (s *Store) handleGetStore(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.sellerStore == nil {
		writeError(w, http.StatusNotFound, "no store yet")
		return
	}
	writeJSON(w, http.StatusOK, s.sellerStore)
}

// GET /api/seller/items — inventory with derived status and totals.
func (s *Store) handleItems(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	writeJSON(w, http.StatusOK, map[string]any{
		"items":   s.itemsWithStatus(),
		"summary": s.summary(),
	})
}

// POST /api/seller/items — add a line of stock.
func (s *Store) handleAddItem(w http.ResponseWriter, r *http.Request) {
	var in InventoryItem
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	in.Title = strings.TrimSpace(in.Title)
	if in.Title == "" {
		writeError(w, http.StatusBadRequest, "title is required")
		return
	}
	if in.Price <= 0 {
		writeError(w, http.StatusBadRequest, "price must be above 0")
		return
	}
	if in.Stock < 0 {
		writeError(w, http.StatusBadRequest, "stock cannot be negative")
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	if s.sellerStore == nil {
		writeError(w, http.StatusConflict, "open a store before adding stock")
		return
	}
	in.ID = s.id("item")
	in.Status = stockStatus(in.Stock)
	s.items = append([]InventoryItem{in}, s.items...)
	writeJSON(w, http.StatusCreated, in)
}

type stockPatch struct {
	Delta *int `json:"delta"` // relative change, e.g. -1 for a sale
	Stock *int `json:"stock"` // absolute set, wins over delta
}

// PATCH /api/seller/items/{id}/stock
func (s *Store) handlePatchStock(w http.ResponseWriter, r *http.Request) {
	var in stockPatch
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	id := r.PathValue("id")

	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.items {
		if s.items[i].ID != id {
			continue
		}
		switch {
		case in.Stock != nil:
			s.items[i].Stock = *in.Stock
		case in.Delta != nil:
			s.items[i].Stock += *in.Delta
		default:
			writeError(w, http.StatusBadRequest, "send delta or stock")
			return
		}
		// Stock never goes negative — that is a bug upstream, not a state.
		if s.items[i].Stock < 0 {
			s.items[i].Stock = 0
		}
		s.items[i].Status = stockStatus(s.items[i].Stock)
		writeJSON(w, http.StatusOK, s.items[i])
		return
	}
	writeError(w, http.StatusNotFound, "no item with id "+id)
}

// DELETE /api/seller/items/{id}
func (s *Store) handleDeleteItem(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, item := range s.items {
		if item.ID == id {
			s.items = append(s.items[:i], s.items[i+1:]...)
			w.WriteHeader(http.StatusNoContent)
			return
		}
	}
	writeError(w, http.StatusNotFound, "no item with id "+id)
}

// GET /api/seller/orders
func (s *Store) handleOrders(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	counts := map[OrderStage]int{}
	for _, o := range s.orders {
		counts[o.Stage]++
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"orders": s.orders,
		"counts": map[string]int{
			"received":  counts[StageReceived],
			"accepted":  counts[StageAccepted],
			"delivered": counts[StageDelivered],
		},
	})
}

// POST /api/seller/orders — a buyer places an order against a stock line.
func (s *Store) handlePlaceOrder(w http.ResponseWriter, r *http.Request) {
	var in struct {
		ItemID string `json:"itemId"`
		Units  int    `json:"units"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if in.Units <= 0 {
		in.Units = 1
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	for _, item := range s.items {
		if item.ID != in.ItemID {
			continue
		}
		if item.Stock < in.Units {
			writeError(w, http.StatusConflict, "not enough stock")
			return
		}
		order := Order{
			ID:        s.id("order"),
			ItemID:    item.ID,
			ItemTitle: item.Title,
			Units:     in.Units,
			Amount:    item.Price * float64(in.Units),
			Stage:     StageReceived,
			PlacedAt:  time.Now().UTC(),
		}
		s.orders = append(s.orders, order)
		writeJSON(w, http.StatusCreated, order)
		return
	}
	writeError(w, http.StatusNotFound, "no item with id "+in.ItemID)
}

// POST /api/seller/orders/{id}/accept
func (s *Store) handleAcceptOrder(w http.ResponseWriter, r *http.Request) {
	s.advance(w, r.PathValue("id"), StageAccepted)
}

// POST /api/seller/orders/{id}/deliver — the hand-over is what takes the
// units out of inventory.
func (s *Store) handleDeliverOrder(w http.ResponseWriter, r *http.Request) {
	s.advance(w, r.PathValue("id"), StageDelivered)
}

func (s *Store) advance(w http.ResponseWriter, id string, to OrderStage) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.orders {
		if s.orders[i].ID != id {
			continue
		}
		if s.orders[i].Stage == StageDelivered {
			writeError(w, http.StatusConflict, "order already delivered")
			return
		}
		s.orders[i].Stage = to
		if to == StageDelivered {
			for j := range s.items {
				if s.items[j].ID == s.orders[i].ItemID {
					s.items[j].Stock -= s.orders[i].Units
					if s.items[j].Stock < 0 {
						s.items[j].Stock = 0
					}
					s.items[j].Status = stockStatus(s.items[j].Stock)
					break
				}
			}
		}
		writeJSON(w, http.StatusOK, s.orders[i])
		return
	}
	writeError(w, http.StatusNotFound, "no order with id "+id)
}

func (s *Store) itemsWithStatus() []InventoryItem {
	out := make([]InventoryItem, len(s.items))
	copy(out, s.items)
	for i := range out {
		out[i].Status = stockStatus(out[i].Stock)
	}
	return out
}

func (s *Store) summary() map[string]any {
	var units int
	var value float64
	var needsRestock int
	for _, i := range s.items {
		if i.Stock > 0 {
			units += i.Stock
		}
		value += i.Price * float64(i.Stock)
		if stockStatus(i.Stock) != "in_stock" {
			needsRestock++
		}
	}
	return map[string]any{
		"products":       len(s.items),
		"units":          units,
		"needsRestock":   needsRestock,
		"inventoryValue": value,
	}
}
