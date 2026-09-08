package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
)

type Preferences struct {
	Push         bool `json:"push"`
	EmailOffers  bool `json:"emailOffers"`
	OrderUpdates bool `json:"orderUpdates"`
}

func (a *API) preferences(ctx context.Context, email string) (Preferences, error) {
	p := Preferences{Push: true, OrderUpdates: true}
	var raw []byte
	err := a.db.sql.QueryRowContext(ctx, `SELECT preferences FROM users WHERE email=$1`, email).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return p, nil
	}
	if err != nil {
		return p, err
	}
	err = json.Unmarshal(raw, &p)
	return p, err
}
func (a *API) handlePreferences(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodPatch {
		var in struct {
			Push         *bool `json:"push"`
			EmailOffers  *bool `json:"emailOffers"`
			OrderUpdates *bool `json:"orderUpdates"`
		}
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
			writeError(w, 400, "invalid preferences")
			return
		}
		patch := map[string]bool{}
		if in.Push != nil {
			patch["push"] = *in.Push
		}
		if in.EmailOffers != nil {
			patch["emailOffers"] = *in.EmailOffers
		}
		if in.OrderUpdates != nil {
			patch["orderUpdates"] = *in.OrderUpdates
		}
		if _, err := a.db.upsertUser(r.Context(), a.owner(r)); err != nil {
			writeError(w, 500, "could not save preferences")
			return
		}
		raw, _ := json.Marshal(patch)
		if _, err := a.db.sql.ExecContext(r.Context(), `UPDATE users SET preferences=preferences||$2::jsonb WHERE email=$1`, a.owner(r), string(raw)); err != nil {
			writeError(w, 500, "could not save preferences")
			return
		}
	}
	p, err := a.preferences(r.Context(), a.owner(r))
	if err != nil {
		writeError(w, 500, "could not load preferences")
		return
	}
	writeJSON(w, 200, p)
}
