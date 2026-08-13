package main

import "testing"

// The chips example: the cheap pack and the good-value pack are different
// products, which is the whole reason this feature shows both.
func TestChipsCheapestIsNotBestValue(t *testing.T) {
	template := []GroupAttribute{
		{Name: "Weight", Unit: "g", Mode: modeHigher, PerUnit: true},
		{Name: "Flavour"},
	}
	items := []comparable{
		{ID: "a", Title: "Balaji", Price: 60, Values: map[string]string{"Weight": "200", "Flavour": "Masala"}},
		{ID: "b", Title: "Lay's", Price: 120, Values: map[string]string{"Weight": "500", "Flavour": "Classic"}},
	}

	ranked := rank(template, items)
	if ranked[0].Winner != "b" {
		t.Errorf("weight: want b (500g), got %q", ranked[0].Winner)
	}
	// No mode set, so it must not be ranked however tempting the strings are.
	if ranked[1].Winner != "" {
		t.Errorf("flavour was ranked: %q", ranked[1].Winner)
	}

	derived := derive(template, items)
	if len(derived) != 1 {
		t.Fatalf("want one derived row, got %d", len(derived))
	}
	if derived[0].Name != "₹ / 100 g" {
		t.Errorf("label: got %q", derived[0].Name)
	}
	if derived[0].Values["a"] != 30 || derived[0].Values["b"] != 24 {
		t.Errorf("₹/100g: want a=30 b=24, got a=%v b=%v",
			derived[0].Values["a"], derived[0].Values["b"])
	}
	if derived[0].Winner != "b" {
		t.Errorf("value winner: want b, got %q", derived[0].Winner)
	}

	// Cheapest total is A, best value is B, and both must be said.
	got := highlights(ranked, derived, items)
	if len(got) < 2 || got[0] != "Balaji costs the least" {
		t.Errorf("highlights should lead with the cheapest: %v", got)
	}
}

// The bug that would matter most: a blank field is not a zero.
func TestMissingIsNotZero(t *testing.T) {
	template := []GroupAttribute{{Name: "Protein", Unit: "g", Mode: modeHigher}}
	items := []comparable{
		{ID: "a", Title: "A", Price: 65, Values: map[string]string{"Protein": "6"}},
		{ID: "b", Title: "B", Price: 70, Values: map[string]string{}},
	}
	if w := rank(template, items)[0].Winner; w != "" {
		t.Errorf("one answer is not a win, got %q", w)
	}
}

func TestEqualValuesHaveNoWinner(t *testing.T) {
	template := []GroupAttribute{{Name: "Volume", Unit: "ml", Mode: modeHigher}}
	items := []comparable{
		{ID: "a", Title: "A", Price: 100, Values: map[string]string{"Volume": "500"}},
		{ID: "b", Title: "B", Price: 120, Values: map[string]string{"Volume": "500"}},
	}
	got := rank(template, items)[0]
	if got.Winner != "" || !got.Equal {
		t.Errorf("want equal with no winner, got winner=%q equal=%v", got.Winner, got.Equal)
	}
}

// Two products tied at the top and a third behind: the tie is still nobody's
// win, and must not fall to whichever row the query returned first.
func TestSharedBestIsNobodysWin(t *testing.T) {
	template := []GroupAttribute{{Name: "Power", Unit: "W", Mode: modeHigher}}
	items := []comparable{
		{ID: "a", Title: "A", Price: 100, Values: map[string]string{"Power": "65"}},
		{ID: "b", Title: "B", Price: 120, Values: map[string]string{"Power": "65"}},
		{ID: "c", Title: "C", Price: 90, Values: map[string]string{"Power": "20"}},
	}
	if w := rank(template, items)[0].Winner; w != "" {
		t.Errorf("shared best should win nothing, got %q", w)
	}
}

func TestLowerBetterPicksTheSmallest(t *testing.T) {
	template := []GroupAttribute{{Name: "Weight", Unit: "kg", Mode: modeLower}}
	items := []comparable{
		{ID: "a", Title: "A", Price: 100, Values: map[string]string{"Weight": "2.5"}},
		{ID: "b", Title: "B", Price: 120, Values: map[string]string{"Weight": "1.8"}},
	}
	if w := rank(template, items)[0].Winner; w != "b" {
		t.Errorf("want b (1.8kg), got %q", w)
	}
}

// The unit is in the template, so the box wants "20" — but a seller typing the
// unit in as well is being reasonable and their row must still rank.
func TestSellerTypingTheUnitStillRanks(t *testing.T) {
	template := []GroupAttribute{{Name: "Power", Unit: "W", Mode: modeHigher}}
	items := []comparable{
		{ID: "a", Title: "A", Price: 100, Values: map[string]string{"Power": "65W"}},
		{ID: "b", Title: "B", Price: 120, Values: map[string]string{"Power": "100 watts"}},
	}
	if w := rank(template, items)[0].Winner; w != "b" {
		t.Errorf("want b (100), got %q", w)
	}
}

func TestNumberIgnoresTextWithNoNumber(t *testing.T) {
	for _, s := range []string{"", "yes", "n/a", "—"} {
		if _, ok := number(s); ok {
			t.Errorf("%q should not parse as a number", s)
		}
	}
	for _, c := range []struct {
		in   string
		want float64
	}{{"20", 20}, {"20W", 20}, {"1.5 kg", 1.5}, {"about 6 pcs", 6}} {
		if got, ok := number(c.in); !ok || got != c.want {
			t.Errorf("number(%q) = %v %v, want %v", c.in, got, ok, c.want)
		}
	}
}

// A zero quantity is a typo. Dividing by it would hand that listing an
// infinite win, which is the sort of thing that reaches production.
func TestZeroQuantityIsSkippedNotDividedBy(t *testing.T) {
	template := []GroupAttribute{{Name: "Weight", Unit: "g", Mode: modeHigher, PerUnit: true}}
	items := []comparable{
		{ID: "a", Title: "A", Price: 60, Values: map[string]string{"Weight": "0"}},
		{ID: "b", Title: "B", Price: 120, Values: map[string]string{"Weight": "500"}},
	}
	// Only one usable quantity is left, so there is nothing to compare.
	if got := derive(template, items); got != nil {
		t.Errorf("want no derived row, got %v", got)
	}
}

func TestPerUnitLabels(t *testing.T) {
	for _, c := range []struct {
		unit, label string
		basis       float64
	}{
		{"g", "₹ / 100 g", 100},
		{"ml", "₹ / 100 ml", 100},
		{"kg", "₹ / kg", 1},
		{"", "₹ / piece", 1},
		{"page", "₹ / page", 1},
	} {
		basis, label := perUnitBasis(c.unit)
		if basis != c.basis || label != c.label {
			t.Errorf("perUnitBasis(%q) = %v %q, want %v %q",
				c.unit, basis, label, c.basis, c.label)
		}
	}
}

// A template written before modes existed carries none, and those groups must
// keep working exactly as they did — shown, not ranked.
func TestTemplateWithoutModesRanksNothing(t *testing.T) {
	template := []GroupAttribute{{Name: "Power", Unit: "W"}, {Name: "Brand"}}
	items := []comparable{
		{ID: "a", Title: "A", Price: 100, Values: map[string]string{"Power": "65", "Brand": "Anker"}},
		{ID: "b", Title: "B", Price: 120, Values: map[string]string{"Power": "100", "Brand": "boAt"}},
	}
	for _, r := range rank(template, items) {
		if r.Winner != "" {
			t.Errorf("%s was ranked without a mode: %q", r.Name, r.Winner)
		}
	}
}
