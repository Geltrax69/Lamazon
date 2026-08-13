package main

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// Comparison modes. A group's template says, per field, what "better" means —
// without that a comparison can only print values side by side and leave the
// ranking to the shopper's eye.
//
// The zero value is modeInfo on purpose: a field nobody has classified is
// displayed, never ranked. Inventing a winner for flavour or brand is worse
// than showing none.
const (
	modeHigher  = "higher_better"
	modeLower   = "lower_better"
	modeFeature = "feature"
	modeInfo    = "info"
	modeEqual   = "equal"
)

// firstNumber pulls a number out of whatever the seller typed. The unit lives
// in the template, so the field is meant to hold "20" — but someone typing
// "20W" into a box already labelled W is being sensible, not wrong, and their
// row should still rank.
var firstNumber = regexp.MustCompile(`-?\d+(?:\.\d+)?`)

func number(s string) (float64, bool) {
	m := firstNumber.FindString(s)
	if m == "" {
		return 0, false
	}
	n, err := strconv.ParseFloat(m, 64)
	if err != nil {
		return 0, false
	}
	return n, true
}

// rankedAttribute is one template field plus who won it.
type rankedAttribute struct {
	GroupAttribute
	// Winner is a product id, or empty when nobody won — which is the answer
	// far more often than it looks: everyone tied, only one product filled the
	// field in, nobody did, or the field is not the ranking kind.
	Winner string `json:"winner,omitempty"`
	Equal  bool   `json:"equal,omitempty"`
}

// derivedRow is a field nobody typed: price per unit, computed from the price
// and whichever template field is marked as the quantity.
type derivedRow struct {
	Name   string             `json:"name"`
	Values map[string]float64 `json:"values"`
	Winner string             `json:"winner,omitempty"`
}

// comparable is the slice of a listing the ranker needs. compare.go's row type
// satisfies it; the tests use it directly.
type comparable struct {
	ID     string
	Title  string
	Price  float64
	Values map[string]string
}

// rank scores every template field across the listings.
//
// Missing is missing. A blank field is never zero, never a loss, and never
// hands the win to whoever did fill it in — that single rule is the difference
// between a comparison sellers trust and one that quietly punishes them for
// leaving a box empty.
func rank(template []GroupAttribute, items []comparable) []rankedAttribute {
	out := make([]rankedAttribute, 0, len(template))
	for _, attr := range template {
		r := rankedAttribute{GroupAttribute: attr}
		switch attr.Mode {
		case modeHigher, modeLower:
			r.Winner, r.Equal = pick(attr, items)
		}
		// feature, info, equal and anything unset are shown, not ranked.
		out = append(out, r)
	}
	return out
}

// pick returns the winning id for one numeric field, or "" with equal set when
// every product that answered gave the same number.
func pick(attr GroupAttribute, items []comparable) (winner string, equal bool) {
	type scored struct {
		id string
		n  float64
	}
	var seen []scored
	for _, it := range items {
		if n, ok := number(it.Values[attr.Name]); ok {
			seen = append(seen, scored{it.ID, n})
		}
	}
	// One answer beats nothing. Nothing to compare it against is not a win.
	if len(seen) < 2 {
		return "", false
	}
	best := seen[0]
	tied := true
	for _, s := range seen[1:] {
		if s.n != best.n {
			tied = false
		}
		if (attr.Mode == modeHigher && s.n > best.n) ||
			(attr.Mode == modeLower && s.n < best.n) {
			best = s
		}
	}
	if tied {
		return "", true
	}
	// A shared best is nobody's win: two products on 500 ml should not have
	// the first one in the list quietly awarded the row.
	for _, s := range seen {
		if s.id != best.id && s.n == best.n {
			return "", false
		}
	}
	return best.id, false
}

// perUnitBasis is how much of a unit the price is quoted against: grams and
// millilitres are compared per 100 because that is how a shelf label reads,
// everything countable per one.
func perUnitBasis(unit string) (basis float64, label string) {
	switch strings.ToLower(strings.TrimSpace(unit)) {
	case "g", "gm", "gram", "grams":
		return 100, "₹ / 100 g"
	case "ml":
		return 100, "₹ / 100 ml"
	case "kg":
		return 1, "₹ / kg"
	case "l", "litre", "liter":
		return 1, "₹ / litre"
	case "":
		return 1, "₹ / piece"
	default:
		return 1, "₹ / " + strings.TrimSpace(unit)
	}
}

// derive computes the price-per-unit row from whichever field the template
// marks as the quantity.
//
// It is computed on every request rather than stored: it moves the moment a
// seller edits a price, and a stored copy would go stale without anyone
// noticing. There is at most one — a product has one price, so a second
// quantity field would just be the same money divided differently.
func derive(template []GroupAttribute, items []comparable) []derivedRow {
	for _, attr := range template {
		if !attr.PerUnit {
			continue
		}
		basis, label := perUnitBasis(attr.Unit)
		row := derivedRow{Name: label, Values: map[string]float64{}}
		for _, it := range items {
			qty, ok := number(it.Values[attr.Name])
			// A zero quantity is a typo, not a bargain, and dividing by it
			// would hand that listing an infinite win.
			if !ok || qty <= 0 || it.Price <= 0 {
				continue
			}
			row.Values[it.ID] = round2(it.Price / qty * basis)
		}
		if len(row.Values) < 2 {
			return nil
		}
		row.Winner = cheapestPerUnit(row.Values)
		return []derivedRow{row}
	}
	return nil
}

func cheapestPerUnit(values map[string]float64) string {
	best, bestID := 0.0, ""
	for id, v := range values {
		if bestID == "" || v < best {
			best, bestID = v, id
		}
	}
	// Same rule as pick: a shared best is nobody's win. Map order is random in
	// Go, so without this the winner would change between two identical
	// requests.
	for id, v := range values {
		if id != bestID && v == best {
			return ""
		}
	}
	return bestID
}

func round2(f float64) float64 {
	return float64(int64(f*100+0.5)) / 100
}

// highlights turns the winners into the sentences a shopper reads first.
//
// Deliberately plural and deliberately not a verdict: the cheapest pack and
// the best value per 100 g are usually different products, and a shopper with
// a fixed budget needs to see both rather than be told which one "wins".
func highlights(ranked []rankedAttribute, derived []derivedRow, items []comparable) []string {
	name := map[string]string{}
	for _, it := range items {
		name[it.ID] = it.Title
	}

	out := []string{}
	// Total price first: it is the one number every shopper checks.
	if id := cheapest(items); id != "" {
		out = append(out, name[id]+" costs the least")
	}
	for _, d := range derived {
		if d.Winner != "" {
			out = append(out, fmt.Sprintf("%s is better value (%s %.2f)",
				name[d.Winner], d.Name, d.Values[d.Winner]))
		}
	}
	for _, r := range ranked {
		if r.Winner == "" {
			continue
		}
		word := "the most"
		if r.Mode == modeLower {
			word = "the lowest"
		}
		out = append(out, fmt.Sprintf("%s has %s %s",
			name[r.Winner], word, strings.ToLower(r.Name)))
	}
	// Four is a summary; ten is the table again in prose.
	if len(out) > 4 {
		out = out[:4]
	}
	return out
}

func cheapest(items []comparable) string {
	best, bestID := 0.0, ""
	for _, it := range items {
		if it.Price <= 0 {
			continue
		}
		if bestID == "" || it.Price < best {
			best, bestID = it.Price, it.ID
		}
	}
	for _, it := range items {
		if it.ID != bestID && it.Price == best {
			return ""
		}
	}
	return bestID
}
