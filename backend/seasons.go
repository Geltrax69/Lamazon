package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"strings"
	"time"
)

// Season is a date-bounded skin for the shop: a festival, a sale, a term.
//
// The dates are the point. An admin sets Diwali up in October with the right
// dates and never touches it again — it arrives and leaves on its own, with
// no deploy and nobody remembering to turn it off on the wrong evening.
type Season struct {
	ID       string    `json:"id"`
	Name     string    `json:"name"`
	StartsAt time.Time `json:"startsAt"`
	EndsAt   time.Time `json:"endsAt"`
	// The chrome, what sits on it, and the text over it. All three, because a
	// palette that cannot name its own foreground produces headers nobody can
	// read.
	Ground string `json:"ground"`
	Accent string `json:"accent"`
	Ink    string `json:"ink"`
	// Newline-separated search placeholders, rotated through the field while
	// the season is live. The cheapest merchandising in the app.
	Hints   []string `json:"hints"`
	Enabled bool     `json:"enabled"`
	// Only ever set on the public read, so the app does not have to compare
	// clocks with the server to know what it is looking at.
	Active bool `json:"active,omitempty"`
}

// GET /api/storefront/season — the one that is live now, or nothing.
//
// Public and unauthenticated: it decides what colour the shop is, so it is
// needed before anyone signs in.
func (a *API) handleActiveSeason(w http.ResponseWriter, r *http.Request) {
	// now() on the server, not a date the client sends. A phone with a wrong
	// clock must not be able to summon Diwali in March.
	//
	// ORDER BY starts_at DESC: overlapping seasons are a mistake rather than a
	// feature, and the most recently begun one is the least surprising answer.
	var s Season
	var hints string
	err := a.db.sql.QueryRowContext(r.Context(), `
		SELECT id, name, starts_at, ends_at, ground, accent, ink, hints
		FROM storefront_seasons
		WHERE enabled AND now() >= starts_at AND now() < ends_at
		ORDER BY starts_at DESC
		LIMIT 1`).Scan(&s.ID, &s.Name, &s.StartsAt, &s.EndsAt,
		&s.Ground, &s.Accent, &s.Ink, &hints)
	if errors.Is(err, sql.ErrNoRows) {
		// Not an error. Most of the year the shop is simply itself, and the
		// app has to be able to tell that apart from a failed request.
		writeJSON(w, http.StatusOK, map[string]any{"season": nil})
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load the season")
		return
	}
	s.Hints = splitHints(hints)
	s.Enabled = true
	s.Active = true
	writeJSON(w, http.StatusOK, map[string]any{"season": s})
}

// GET /api/admin/seasons — all of them, past and future, so an admin can see
// what is scheduled rather than only what is live.
func (a *API) handleAdminSeasons(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.sql.QueryContext(r.Context(), `
		SELECT id, name, starts_at, ends_at, ground, accent, ink, hints, enabled,
		       (enabled AND now() >= starts_at AND now() < ends_at) AS active
		FROM storefront_seasons ORDER BY starts_at DESC`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	out := make([]Season, 0)
	for rows.Next() {
		var s Season
		var hints string
		if err := rows.Scan(&s.ID, &s.Name, &s.StartsAt, &s.EndsAt, &s.Ground,
			&s.Accent, &s.Ink, &hints, &s.Enabled, &s.Active); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		s.Hints = splitHints(hints)
		out = append(out, s)
	}
	writeJSON(w, http.StatusOK, map[string]any{"seasons": out})
}

// PUT /api/admin/seasons/{id}
func (a *API) handleSaveSeason(w http.ResponseWriter, r *http.Request) {
	var s Season
	if json.NewDecoder(http.MaxBytesReader(w, r.Body, 16384)).Decode(&s) != nil {
		writeError(w, http.StatusBadRequest, "invalid season")
		return
	}
	s.ID = r.PathValue("id")
	s.Name = strings.TrimSpace(s.Name)

	if !campaignID.MatchString(s.ID) {
		writeError(w, http.StatusBadRequest, "The id may use letters, numbers, hyphens and underscores.")
		return
	}
	if s.Name == "" || len([]rune(s.Name)) > 40 {
		writeError(w, http.StatusBadRequest, "Give the season a name of up to 40 characters.")
		return
	}
	for _, c := range []string{s.Ground, s.Accent, s.Ink} {
		if !campaignColour.MatchString(c) {
			writeError(w, http.StatusBadRequest, "Ground, accent and text each need a hex colour like #143E32.")
			return
		}
	}
	if !s.EndsAt.After(s.StartsAt) {
		writeError(w, http.StatusBadRequest, "The season has to end after it starts.")
		return
	}
	// Text that cannot be read on its own ground is not a theme, it is a bug
	// that ships. Checked here rather than in the app because the app cannot
	// refuse to draw what an admin already saved.
	if contrast(s.Ink, s.Ground) < 4.5 {
		writeError(w, http.StatusBadRequest,
			"The text colour is too close to the ground to read. Pick a lighter or darker one — it needs a contrast ratio of 4.5, for the same reason road signs do.")
		return
	}
	hints := make([]string, 0, len(s.Hints))
	for _, h := range s.Hints {
		if h = strings.TrimSpace(h); h != "" && len([]rune(h)) <= 60 {
			hints = append(hints, h)
		}
	}
	if len(hints) > 12 {
		hints = hints[:12]
	}

	_, err := a.db.sql.ExecContext(r.Context(), `
		INSERT INTO storefront_seasons
		    (id, name, starts_at, ends_at, ground, accent, ink, hints, enabled)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		ON CONFLICT (id) DO UPDATE SET
		    name = EXCLUDED.name, starts_at = EXCLUDED.starts_at,
		    ends_at = EXCLUDED.ends_at, ground = EXCLUDED.ground,
		    accent = EXCLUDED.accent, ink = EXCLUDED.ink,
		    hints = EXCLUDED.hints, enabled = EXCLUDED.enabled`,
		s.ID, s.Name, s.StartsAt, s.EndsAt, s.Ground, s.Accent, s.Ink,
		strings.Join(hints, "\n"), s.Enabled)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	s.Hints = hints
	writeJSON(w, http.StatusOK, s)
}

// DELETE /api/admin/seasons/{id}
func (a *API) handleDeleteSeason(w http.ResponseWriter, r *http.Request) {
	res, err := a.db.sql.ExecContext(r.Context(),
		`DELETE FROM storefront_seasons WHERE id = $1`, r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "no season called "+r.PathValue("id"))
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func splitHints(raw string) []string {
	out := make([]string, 0)
	for _, line := range strings.Split(raw, "\n") {
		if line = strings.TrimSpace(line); line != "" {
			out = append(out, line)
		}
	}
	return out
}

// contrast is the WCAG 2.1 ratio between two "#rrggbb" colours, 1 to 21.
func contrast(a, b string) float64 {
	la, lb := luminance(a), luminance(b)
	if la < lb {
		la, lb = lb, la
	}
	return (la + 0.05) / (lb + 0.05)
}

func luminance(hex string) float64 {
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) != 6 {
		return 0
	}
	channel := func(i int) float64 {
		var v int
		for _, c := range hex[i : i+2] {
			v *= 16
			switch {
			case c >= '0' && c <= '9':
				v += int(c - '0')
			case c >= 'a' && c <= 'f':
				v += int(c-'a') + 10
			case c >= 'A' && c <= 'F':
				v += int(c-'A') + 10
			}
		}
		s := float64(v) / 255
		if s <= 0.03928 {
			return s / 12.92
		}
		return math.Pow((s+0.055)/1.055, 2.4)
	}
	return 0.2126*channel(0) + 0.7152*channel(2) + 0.0722*channel(4)
}
