package main

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5/pgconn"
)

// Category is one row of the shop's navigation: a department when Parent is
// empty, one of its categories otherwise.
type Category struct {
	Name     string `json:"name"`
	Parent   string `json:"parent,omitempty"`
	Icon     string `json:"icon,omitempty"`
	Colour   string `json:"colour,omitempty"`
	Position int    `json:"position"`

	// Only filled in on departments, and only by the public listing.
	Children []Category `json:"children,omitempty"`
}

// categories reads every row, newest ordering first, in one query. The tree is
// assembled in Go: at this size sorting a few dozen rows twice costs less than
// a recursive CTE costs to read.
func (d *DB) categories(r *http.Request) ([]Category, error) {
	rows, err := d.sql.QueryContext(r.Context(), `
		SELECT name, parent, icon, colour, position
		FROM catalog_categories ORDER BY position, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var flat []Category
	for rows.Next() {
		var c Category
		if err := rows.Scan(&c.Name, &c.Parent, &c.Icon, &c.Colour,
			&c.Position); err != nil {
			return nil, err
		}
		flat = append(flat, c)
	}
	return flat, rows.Err()
}

// GET /api/categories — the whole navigation, departments with their
// categories nested. Public: it is what the shop draws its tabs from.
func (a *API) handleCategories(w http.ResponseWriter, r *http.Request) {
	flat, err := a.db.categories(r)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	out := make([]Category, 0)
	at := map[string]int{}
	for _, c := range flat {
		if c.Parent == "" {
			at[c.Name] = len(out)
			out = append(out, c)
		}
	}
	// A category whose department was deleted is dropped rather than promoted
	// to a department of its own, which is what appending it to `out` would
	// quietly do.
	for _, c := range flat {
		if c.Parent == "" {
			continue
		}
		if i, ok := at[c.Parent]; ok {
			out[i].Children = append(out[i].Children, c)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// POST /api/admin/categories — add a department, or a category inside one.
func (a *API) handleAddCategory(w http.ResponseWriter, r *http.Request) {
	var in Category
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	in.Name = strings.TrimSpace(in.Name)
	in.Parent = strings.TrimSpace(in.Parent)
	if in.Name == "" {
		writeError(w, http.StatusBadRequest, "name is required")
		return
	}
	// "All" is the everything tab the app draws itself; a real row by that
	// name would show up twice and filter to nothing.
	if strings.EqualFold(in.Name, "All") {
		writeError(w, http.StatusBadRequest,
			`"All" is the built-in tab that shows everything`)
		return
	}
	if in.Parent != "" {
		var parentOf string
		err := a.db.sql.QueryRowContext(r.Context(),
			`SELECT parent FROM catalog_categories WHERE name = $1`,
			in.Parent).Scan(&parentOf)
		if err != nil {
			writeError(w, http.StatusBadRequest,
				"no department called "+in.Parent)
			return
		}
		// One level only. Nesting deeper has nowhere to render, and the tab
		// bar would silently stop showing it.
		if parentOf != "" {
			writeError(w, http.StatusBadRequest,
				in.Parent+" is a category, not a department")
			return
		}
	}

	// Last by default, so a new one appears at the end rather than jumping
	// into the middle of an order the admin arranged.
	if in.Position == 0 {
		a.db.sql.QueryRowContext(r.Context(),
			`SELECT COALESCE(max(position), 0) + 1 FROM catalog_categories
			 WHERE parent = $1`, in.Parent).Scan(&in.Position)
	}

	_, err := a.db.sql.ExecContext(r.Context(), `
		INSERT INTO catalog_categories (name, parent, icon, colour, position)
		VALUES ($1,$2,$3,$4,$5)`,
		in.Name, in.Parent, in.Icon, in.Colour, in.Position)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		writeError(w, http.StatusConflict, in.Name+" already exists")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, in)
}

// DELETE /api/admin/categories/{name} — only when nothing is filed under it.
//
// Removing a department that stock is listed in would leave those items with
// no tab to appear on: still for sale, reachable only by search. Refusing and
// saying how many is more use than a delete that half works.
func (a *API) handleDeleteCategory(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")

	var items, children int
	a.db.sql.QueryRowContext(r.Context(),
		`SELECT count(*) FROM inventory_items WHERE category = $1`,
		name).Scan(&items)
	a.db.sql.QueryRowContext(r.Context(),
		`SELECT count(*) FROM catalog_categories WHERE parent = $1`,
		name).Scan(&children)

	if items > 0 {
		writeError(w, http.StatusConflict, plural(items, "item")+
			" still listed under "+name+". Move them first.")
		return
	}
	if children > 0 {
		writeError(w, http.StatusConflict, plural(children, "category")+
			" still inside "+name+". Remove them first.")
		return
	}

	res, err := a.db.sql.ExecContext(r.Context(),
		`DELETE FROM catalog_categories WHERE name = $1`, name)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "no category called "+name)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// plural writes "1 item" and "3 items". ponytail: the only irregular plural
// here is "category", handled in place.
func plural(n int, noun string) string {
	if n == 1 {
		return "1 " + noun
	}
	if noun == "category" {
		noun = "categorie"
	}
	return strconv.Itoa(n) + " " + noun + "s"
}
