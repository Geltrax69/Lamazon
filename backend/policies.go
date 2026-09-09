package main

import (
	"context"
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"time"
)

// Policy is one written document — terms, privacy, and the rest.
type Policy struct {
	Slug      string    `json:"slug"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// GET /api/policies — all of them, in the order the app lists them. Public:
// they are meant to be read before anyone signs in.
func (a *API) handlePolicies(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.sql.QueryContext(r.Context(), `
		SELECT slug, title, body, updated_at FROM policies
		ORDER BY array_position($1::text[], slug), title`,
		policyOrder())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	out := make([]Policy, 0)
	for rows.Next() {
		var p Policy
		if err := rows.Scan(&p.Slug, &p.Title, &p.Body, &p.UpdatedAt); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if !strings.HasPrefix(r.URL.Path, "/api/admin/") && policyHasBlanks(p.Body) {
			p.Body = "This policy is not published yet. Please check back before placing an order."
		}
		out = append(out, p)
	}
	if strings.HasPrefix(r.URL.Path, "/api/admin/") {
		writeJSON(w, 200, map[string]any{"policies": out})
		return
	}
	writeJSON(w, http.StatusOK, out)
}

// PUT /api/admin/policies/{slug} — the admin rewrites one, in whole.
//
// Upsert rather than update: a policy added to the app after this database was
// seeded has no row yet, and refusing to save it would be a page nobody can
// ever fill in.
func (a *API) handleSavePolicy(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Title string `json:"title"`
		Body  string `json:"body"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	slug := strings.TrimSpace(r.PathValue("slug"))
	in.Title = strings.TrimSpace(in.Title)
	if slug == "" || in.Title == "" {
		writeError(w, http.StatusBadRequest, "slug and title are required")
		return
	}
	// An empty body would publish a blank page over a written one, which is
	// never what an admin means by saving.
	if strings.TrimSpace(in.Body) == "" {
		writeError(w, http.StatusBadRequest, "the policy text cannot be empty")
		return
	}

	if policyHasBlanks(in.Body) || policyHasBlanks(in.Title) {
		writeError(w, 400, "fill all policy placeholders before publishing")
		return
	}
	if len(in.Body) > 100000 || len(in.Title) > 200 {
		writeError(w, 400, "policy is too long")
		return
	}
	valid := false
	for _, allowed := range policyOrder() {
		if slug == allowed {
			valid = true
		}
	}
	if !valid {
		writeError(w, 400, "unknown policy")
		return
	}

	if _, err := a.db.sql.ExecContext(r.Context(), `
		INSERT INTO policies (slug, title, body) VALUES ($1,$2,$3)
		ON CONFLICT (slug) DO UPDATE SET
			title = EXCLUDED.title, body = EXCLUDED.body, updated_at = now()`,
		slug, in.Title, in.Body); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"slug": slug})
}

// seedPolicies writes the shipped draft of anything that has no row yet. Each
// document is filled in on its own, so adding a sixth later brings its text
// with it without touching the five an admin has already edited.
func (d *DB) seedPolicies(ctx context.Context) error {
	for _, p := range shippedPolicies() {
		if _, err := d.sql.ExecContext(ctx, `
			INSERT INTO policies (slug, title, body) VALUES ($1,$2,$3)
			ON CONFLICT (slug) DO NOTHING`, p.Slug, p.Title, p.Body); err != nil {
			return err
		}
	}
	return nil
}

func policyOrder() []string {
	out := make([]string, 0, len(shippedPolicies()))
	for _, p := range shippedPolicies() {
		out = append(out, p.Slug)
	}
	return out
}

var policyBlank = regexp.MustCompile(`\[[^\]\n]+\]`)

func policyHasBlanks(body string) bool {
	for _, span := range policyBlank.FindAllStringIndex(body, -1) {
		// Markdown links are content, not an unfilled template field.
		if span[1] < len(body) && body[span[1]] == '(' {
			continue
		}
		return true
	}
	return false
}
