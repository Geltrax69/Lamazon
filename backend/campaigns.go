package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/url"
	"regexp"
	"strings"
)

// Campaign content belongs to staff, while navigation remains a catalogue
// category. No arbitrary redirects or fabricated promotion calculations.
type Campaign struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	Subtitle   string `json:"subtitle"`
	CTA        string `json:"cta"`
	Category   string `json:"category"`
	Department string `json:"department"`
	ImageURL   string `json:"imageUrl"`
	Colour     string `json:"colour"`
	Enabled    bool   `json:"enabled"`
	Position   int    `json:"position"`
}

func (a *API) handleCampaigns(w http.ResponseWriter, r *http.Request) {
	admin := strings.HasPrefix(r.URL.Path, "/api/admin/")
	rows, err := a.db.sql.QueryContext(r.Context(), `SELECT id,title,subtitle,cta,category,department,image_url,colour,enabled,position FROM storefront_campaigns WHERE ($1 OR enabled) AND ($1 OR category='' OR EXISTS(SELECT 1 FROM catalog_categories WHERE name=category)) ORDER BY position,id`, admin)
	if err != nil {
		writeError(w, 500, "could not load banners")
		return
	}
	defer rows.Close()
	out := []Campaign{}
	for rows.Next() {
		var c Campaign
		if err := rows.Scan(&c.ID, &c.Title, &c.Subtitle, &c.CTA, &c.Category, &c.Department, &c.ImageURL, &c.Colour, &c.Enabled, &c.Position); err != nil {
			writeError(w, 500, "could not read banners")
			return
		}
		out = append(out, c)
	}
	if rows.Err() != nil {
		writeError(w, 500, "could not read banners")
		return
	}
	if admin {
		writeJSON(w, 200, map[string]any{"campaigns": out})
	} else {
		writeJSON(w, 200, out)
	}
}

var campaignID = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,80}$`)
var campaignColour = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

func (a *API) handleSaveCampaign(w http.ResponseWriter, r *http.Request) {
	var c Campaign
	if json.NewDecoder(http.MaxBytesReader(w, r.Body, 16384)).Decode(&c) != nil {
		writeError(w, 400, "invalid banner")
		return
	}
	c.ID = r.PathValue("id")
	c.Title = strings.TrimSpace(c.Title)
	c.Subtitle = strings.TrimSpace(c.Subtitle)
	c.CTA = strings.TrimSpace(c.CTA)
	c.Category = strings.TrimSpace(c.Category)
	c.Department = strings.TrimSpace(c.Department)
	c.ImageURL = strings.TrimSpace(c.ImageURL)
	if !campaignID.MatchString(c.ID) || len(c.Title) == 0 || len([]rune(c.Title)) > 65 || len([]rune(c.Subtitle)) > 120 || len(c.CTA) == 0 || len([]rune(c.CTA)) > 28 || !campaignColour.MatchString(c.Colour) || c.Position < 0 || c.Position > 9999 {
		writeError(w, 400, "Use a title up to 65 characters, description up to 120, button up to 28, a hex colour and order from 0 to 9999.")
		return
	}
	if c.ImageURL != "" {
		u, err := url.Parse(c.ImageURL)
		if err != nil || u.Scheme != "https" || u.Host == "" || u.User != nil || len(c.ImageURL) > 2048 {
			writeError(w, 400, "Artwork must be an HTTPS URL.")
			return
		}
	}
	for _, name := range []string{c.Category, c.Department} {
		if name == "" {
			continue
		}
		var exists bool
		if err := a.db.sql.QueryRowContext(r.Context(), `SELECT EXISTS(SELECT 1 FROM catalog_categories WHERE name=$1)`, name).Scan(&exists); err != nil {
			writeError(w, 500, "could not validate category")
			return
		}
		if !exists {
			writeError(w, 400, "Choose an existing category.")
			return
		}
	}
	if c.Department != "" {
		var root string
		if err := a.db.sql.QueryRowContext(r.Context(), `SELECT parent FROM catalog_categories WHERE name=$1`, c.Department).Scan(&root); err != nil || root != "" {
			writeError(w, 400, "Show in must be a department.")
			return
		}
	}
	_, err := a.db.sql.ExecContext(r.Context(), `INSERT INTO storefront_campaigns(id,title,subtitle,cta,category,department,image_url,colour,enabled,position) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) ON CONFLICT(id) DO UPDATE SET title=EXCLUDED.title,subtitle=EXCLUDED.subtitle,cta=EXCLUDED.cta,category=EXCLUDED.category,department=EXCLUDED.department,image_url=EXCLUDED.image_url,colour=EXCLUDED.colour,enabled=EXCLUDED.enabled,position=EXCLUDED.position`, c.ID, c.Title, c.Subtitle, c.CTA, c.Category, c.Department, c.ImageURL, c.Colour, c.Enabled, c.Position)
	if err != nil {
		writeError(w, 500, "could not save banner")
		return
	}
	writeJSON(w, 200, c)
}

func (a *API) handleDeleteCampaign(w http.ResponseWriter, r *http.Request) {
	res, err := a.db.sql.ExecContext(r.Context(), `DELETE FROM storefront_campaigns WHERE id=$1`, r.PathValue("id"))
	if err != nil {
		writeError(w, 500, "could not delete banner")
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, 404, "banner not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Import by link. Staff find artwork on the web and paste its address; this
// works out what that address actually holds, has Cloudinary store it, and
// hands back a URL on our own CDN. Storing rather than hotlinking is the
// point: a banner pointed at somebody else's server is a banner that breaks
// the day they tidy up, and it puts our shoppers' traffic on their logs.
func (a *API) handleCampaignMedia(w http.ResponseWriter, r *http.Request) {
	if a.cloud == nil {
		writeError(w, 503, "photo storage is not configured")
		return
	}
	var body struct {
		URL string `json:"url"`
	}
	if json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body) != nil {
		writeError(w, 400, "send a link to fetch")
		return
	}
	target, err := mediaBehind(r.Context(), body.URL)
	if err != nil {
		writeError(w, 400, upperFirst(err.Error())+".")
		return
	}
	var id [16]byte
	if _, err := rand.Read(id[:]); err != nil {
		writeError(w, 500, "could not prepare upload")
		return
	}
	stored, kind, err := a.cloud.uploadRemote(
		r.Context(), "Lamazon/Campaigns", hex.EncodeToString(id[:]), target)
	if err != nil {
		writeError(w, 502, "that link could not be fetched")
		return
	}
	// "auto" files anything it cannot recognise as raw, so a web page that
	// slipped through above would arrive here as a 1 MB HTML banner.
	if kind != "image" && kind != "video" {
		writeError(w, 400, "That link is not a picture or a clip.")
		return
	}
	writeJSON(w, 200, map[string]string{"imageUrl": stored})
}

func upperFirst(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

// Upload returns a URL without publishing it. The editor previews it, then
// saves the complete campaign in a single request.
func (a *API) handleCampaignPhoto(w http.ResponseWriter, r *http.Request) {
	if a.cloud == nil {
		writeError(w, 503, "photo storage is not configured")
		return
	}
	photos, err := uploadedBanner(r)
	if err != nil {
		writeError(w, 400, err.Error())
		return
	}
	var id [16]byte
	if _, err := rand.Read(id[:]); err != nil {
		writeError(w, 500, "could not prepare upload")
		return
	}
	url, err := a.cloud.upload(r.Context(), "Lamazon/Campaigns", hex.EncodeToString(id[:]), photos[0])
	if err != nil {
		writeError(w, 502, "could not upload banner artwork")
		return
	}
	writeJSON(w, 200, map[string]string{"imageUrl": url})
}
