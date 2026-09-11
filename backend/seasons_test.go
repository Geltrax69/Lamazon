package main

import (
	"net/http"
	"strings"
	"testing"
	"time"
)

func iso(t time.Time) string { return t.UTC().Format(time.RFC3339) }

// A season is a date-bounded skin for the shop. The dates are the whole point:
// nobody should have to remember to switch Diwali off.
func TestSeasonGoesLiveAndLeavesOnItsOwn(t *testing.T) {
	h := testAPI(t)
	admin := adminSignIn(t, h)
	now := time.Now()

	save := func(id string, from, to time.Time, ink string) (int, map[string]any) {
		return callAs(t, h, admin, http.MethodPut, "/api/admin/seasons/"+id, map[string]any{
			"name":     "Ganesh Chaturthi",
			"startsAt": iso(from),
			"endsAt":   iso(to),
			"ground":   "#7A1F12",
			"accent":   "#F2B441",
			"ink":      ink,
			"hints":    []string{"ganesh idol", "modak", "decorative lights"},
			"enabled":  true,
		})
	}

	// Nothing scheduled: the shop is simply itself, and that is not an error.
	if code, body := callAs(t, h, "", http.MethodGet, "/api/storefront/season", nil); code != 200 || body["season"] != nil {
		t.Fatalf("with nothing scheduled: %d %v", code, body["season"])
	}

	// Scheduled for next month — not live yet.
	if code, body := save("future", now.AddDate(0, 1, 0), now.AddDate(0, 1, 7), "#FFFDF8"); code != 200 {
		t.Fatalf("save future: %d %v", code, body)
	}
	if _, body := callAs(t, h, "", http.MethodGet, "/api/storefront/season", nil); body["season"] != nil {
		t.Fatal("a season that has not started is live")
	}

	// Already over — also not live.
	if code, body := save("past", now.AddDate(0, 0, -9), now.AddDate(0, 0, -2), "#FFFDF8"); code != 200 {
		t.Fatalf("save past: %d %v", code, body)
	}
	if _, body := callAs(t, h, "", http.MethodGet, "/api/storefront/season", nil); body["season"] != nil {
		t.Fatal("a season that has ended is still live")
	}

	// Now.
	if code, body := save("live", now.Add(-time.Hour), now.Add(time.Hour), "#FFFDF8"); code != 200 {
		t.Fatalf("save live: %d %v", code, body)
	}
	_, body := callAs(t, h, "", http.MethodGet, "/api/storefront/season", nil)
	season, ok := body["season"].(map[string]any)
	if !ok {
		t.Fatalf("the live season is missing: %v", body)
	}
	if season["id"] != "live" || season["ground"] != "#7A1F12" {
		t.Fatalf("wrong season came back: %v", season)
	}
	if hints := season["hints"].([]any); len(hints) != 3 || hints[0] != "ganesh idol" {
		t.Fatalf("hints did not survive: %v", season["hints"])
	}

	// The admin sees all three, and which one is current.
	_, all := callAs(t, h, admin, http.MethodGet, "/api/admin/seasons", nil)
	rows := all["seasons"].([]any)
	if len(rows) != 3 {
		t.Fatalf("admin should see every season, got %d", len(rows))
	}
	var active int
	for _, raw := range rows {
		if raw.(map[string]any)["active"] == true {
			active++
		}
	}
	if active != 1 {
		t.Fatalf("exactly one season should be active, got %d", active)
	}

	// Switching it off takes it down without deleting the schedule.
	if code, _ := callAs(t, h, admin, http.MethodPut, "/api/admin/seasons/live", map[string]any{
		"name": "Ganesh Chaturthi", "startsAt": iso(now.Add(-time.Hour)),
		"endsAt": iso(now.Add(time.Hour)), "ground": "#7A1F12",
		"accent": "#F2B441", "ink": "#FFFDF8", "enabled": false,
	}); code != 200 {
		t.Fatal("could not disable the season")
	}
	if _, body := callAs(t, h, "", http.MethodGet, "/api/storefront/season", nil); body["season"] != nil {
		t.Fatal("a disabled season is still live")
	}
}

// A palette that cannot name a readable foreground is a bug that ships,
// because the app cannot refuse to draw what an admin already saved.
func TestSeasonRefusesUnreadableAndMalformedPalettes(t *testing.T) {
	h := testAPI(t)
	admin := adminSignIn(t, h)
	now := time.Now()

	base := map[string]any{
		"name": "Test", "startsAt": iso(now), "endsAt": iso(now.Add(time.Hour)),
		"ground": "#7A1F12", "accent": "#F2B441", "ink": "#FFFDF8",
		"enabled": true,
	}
	with := func(k string, v any) map[string]any {
		out := map[string]any{}
		for key, val := range base {
			out[key] = val
		}
		out[k] = v
		return out
	}

	for _, probe := range []struct {
		what string
		body map[string]any
	}{
		{"dark text on a dark ground", with("ink", "#8A2F22")},
		{"a ground that is not a colour", with("ground", "maroon")},
		{"a season that ends before it starts", with("endsAt", iso(now.Add(-time.Hour)))},
		{"no name", with("name", "")},
	} {
		if code, _ := callAs(t, h, admin, http.MethodPut, "/api/admin/seasons/probe", probe.body); code != http.StatusBadRequest {
			t.Fatalf("%s should be refused, got %d", probe.what, code)
		}
	}

	// And the readable version of the same palette is accepted.
	if code, body := callAs(t, h, admin, http.MethodPut, "/api/admin/seasons/probe", base); code != 200 {
		t.Fatalf("a readable palette should save: %d %v", code, body)
	}
}

// The public read is public; everything that changes a season is not.
func TestSeasonRoutesAreAdminOnly(t *testing.T) {
	h := testAPI(t)
	adminSignIn(t, h)

	if code, _ := callAs(t, h, "", http.MethodGet, "/api/storefront/season", nil); code != 200 {
		t.Fatal("the active season has to be readable before anyone signs in")
	}
	for _, probe := range []struct {
		method, path string
		body         any
	}{
		{http.MethodGet, "/api/admin/seasons", nil},
		{http.MethodPut, "/api/admin/seasons/x", map[string]any{"name": "x"}},
		{http.MethodDelete, "/api/admin/seasons/x", nil},
	} {
		// call() carries a shopper token, not an admin one.
		if code, _ := call(t, h, probe.method, probe.path, probe.body); code != http.StatusUnauthorized {
			t.Fatalf("%s %s should reject a shopper, got %d", probe.method, probe.path, code)
		}
	}
}

// The contrast helper the validator leans on, against values from the WCAG
// worked examples.
func TestContrastMatchesWCAG(t *testing.T) {
	for _, c := range []struct {
		a, b string
		want float64
	}{
		{"#FFFFFF", "#000000", 21},
		{"#FFFFFF", "#FFFFFF", 1},
		{"#FFFDF8", "#143E32", 11.70}, // the app's own ink on its own forest
	} {
		got := contrast(c.a, c.b)
		if got < c.want-0.3 || got > c.want+0.3 {
			t.Fatalf("contrast(%s,%s) = %.2f, want about %.2f", c.a, c.b, got, c.want)
		}
	}
}

// Two seasons live at once is an ambiguous shop: whichever the ORDER BY picks
// is what shoppers see, and an admin has no way to predict which. Overlaps
// used to be accepted silently.
func TestSeasonRefusesOverlappingWindows(t *testing.T) {
	h := testAPI(t)
	admin := adminSignIn(t, h)
	now := time.Now()

	save := func(id string, from, to time.Time, enabled bool) (int, map[string]any) {
		return callAs(t, h, admin, http.MethodPut, "/api/admin/seasons/"+id, map[string]any{
			"name": id, "startsAt": iso(from), "endsAt": iso(to),
			"ground": "#7A1F12", "accent": "#F2B441", "ink": "#FFFDF8",
			"enabled": enabled,
		})
	}

	// Starts an hour ago, not "now": starts_at is this process's clock and the
	// liveness check is Postgres's, so a season beginning at this instant is a
	// coin flip on which of the two is a millisecond ahead.
	from, to := now.Add(-time.Hour), now.AddDate(0, 0, 7)
	if code, body := save("diwali", from, to, true); code != 200 {
		t.Fatalf("the first season should save: %d %v", code, body)
	}

	for _, probe := range []struct {
		what     string
		from, to time.Time
	}{
		{"starting inside it", now.AddDate(0, 0, 3), now.AddDate(0, 0, 10)},
		{"ending inside it", now.AddDate(0, 0, -3), now.AddDate(0, 0, 3)},
		{"swallowing it whole", now.AddDate(0, 0, -2), now.AddDate(0, 0, 9)},
		{"sitting inside it", now.AddDate(0, 0, 2), now.AddDate(0, 0, 4)},
	} {
		code, body := save("clash", probe.from, probe.to, true)
		if code != http.StatusConflict {
			t.Fatalf("a season %s should be refused, got %d %v", probe.what, code, body)
		}
		// The admin has to be able to act on it, which means knowing which
		// season it clashed with.
		if msg, _ := body["error"].(string); !strings.Contains(msg, "diwali") {
			t.Fatalf("the refusal should name the other season, got %q", msg)
		}
	}

	// A handover is not an overlap: the windows are half-open, so one ending
	// where the next begins is exactly one live season all the way through.
	if code, body := save("after", to, now.AddDate(0, 0, 14), true); code != 200 {
		t.Fatalf("a season starting as the last one ends should save: %d %v", code, body)
	}

	// A disabled season is a draft, not a schedule, so it may overlap freely.
	if code, body := save("draft", now.AddDate(0, 0, 1), now.AddDate(0, 0, 2), false); code != 200 {
		t.Fatalf("a disabled season should save over a live one: %d %v", code, body)
	}

	// And editing a season without moving it does not clash with itself.
	if code, body := save("diwali", from, to, true); code != 200 {
		t.Fatalf("a season should not conflict with itself: %d %v", code, body)
	}

	// Exactly one is live, which is the property all of this exists to keep.
	_, public := callAs(t, h, "", http.MethodGet, "/api/storefront/season", nil)
	season, ok := public["season"].(map[string]any)
	if !ok || season["id"] != "diwali" {
		t.Fatalf("the live season should be the only enabled one: %v", public["season"])
	}
}

// "invalid season" told an API client nothing. The message now says what it
// could not read, and which format it wanted.
func TestSeasonDecodeFailureSaysWhy(t *testing.T) {
	h := testAPI(t)
	admin := adminSignIn(t, h)
	code, body := callAs(t, h, admin, http.MethodPut, "/api/admin/seasons/x", map[string]any{
		"name": "x", "startsAt": "18 October", "endsAt": "25 October",
		"ground": "#7A1F12", "accent": "#F2B441", "ink": "#FFFDF8",
	})
	if code != http.StatusBadRequest {
		t.Fatalf("an unparseable date should be refused, got %d", code)
	}
	msg, _ := body["error"].(string)
	if !strings.Contains(msg, "RFC 3339") || msg == "invalid season" {
		t.Fatalf("the refusal should say what it wanted, got %q", msg)
	}
}
