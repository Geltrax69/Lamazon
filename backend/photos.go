package main

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"
)

// Room for a phone photo at full resolution; the picker already downscales to
// 80% quality. The global 1 MiB cap does not apply to these two routes.
const maxPhoto = 10 << 20

// Cloudinary rejects anything that is not an image anyway, but sniffing here
// keeps a bad upload from costing a round trip.
var photoTypes = map[string]bool{
	"image/jpeg": true, "image/png": true, "image/webp": true, "image/gif": true,
}

// uploadedPhotos parses the body and returns the attached images.
func uploadedPhotos(r *http.Request) ([][]byte, error) {
	if err := r.ParseMultipartForm(maxPhoto); err != nil {
		return nil, err
	}
	return photoBytes(r, "file")
}

// POST /api/seller/store/photo — the store's cover picture, filed under
// Lamazon/<StoreName>/store_image.
func (a *API) handleStorePhoto(w http.ResponseWriter, r *http.Request) {
	if a.cloud == nil {
		writeError(w, http.StatusServiceUnavailable, "photo storage is not configured")
		return
	}
	store, err := a.db.store(r.Context(), a.owner(r))
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "open a store before adding its photo")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	imgs, err := uploadedPhotos(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	url, err := a.cloud.upload(r.Context(), storeFolder(store.Name), storePhotoName, imgs[0])
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	if _, err := a.db.sql.ExecContext(r.Context(),
		`UPDATE seller_stores SET photo_url = $2 WHERE owner = $1`,
		store.Owner, url); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"photoUrl": url})
}

// POST /api/seller/items/{id}/photos — one or more product pictures, named
// <store>_<item>_<n> inside that store's folder and numbered from whatever
// the item already has.
func (a *API) handleItemPhotos(w http.ResponseWriter, r *http.Request) {
	if a.cloud == nil {
		writeError(w, http.StatusServiceUnavailable, "photo storage is not configured")
		return
	}
	if _, ok := a.requireApprovedStore(w, r); !ok {
		return
	}
	id := r.PathValue("id")

	// The folder comes from the store, the name from the item, so both have
	// to exist before anything is uploaded — and the item has to be this
	// seller's, or an id guessed from someone else's shop would upload into
	// their listing.
	var storeName, title string
	var existing int
	err := a.db.sql.QueryRowContext(r.Context(), `
		SELECT s.name, i.title, cardinality(i.image_urls)
		FROM inventory_items i JOIN seller_stores s ON s.owner = i.owner
		WHERE i.id = $1 AND i.owner = $2`, id, a.owner(r)).
		Scan(&storeName, &title, &existing)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "no item with id "+id)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	imgs, err := uploadedPhotos(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	urls := make([]string, 0, len(imgs))
	for n, img := range imgs {
		url, err := a.cloud.upload(r.Context(), storeFolder(storeName),
			itemPhotoName(storeName, title, existing+n+1), img)
		if err != nil {
			writeError(w, http.StatusBadGateway, err.Error())
			return
		}
		urls = append(urls, url)
	}

	// Append rather than replace, and read back what is stored so the client
	// sees the same list a later GET will return.
	var saved string
	if err := a.db.sql.QueryRowContext(r.Context(), `
		UPDATE inventory_items SET image_urls = image_urls || $2::text[]
		WHERE id = $1 AND owner = $3
		RETURNING array_to_string(image_urls, E'\n')`, id, urls, a.owner(r)).
		Scan(&saved); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"imageUrls": strings.Split(saved, "\n"),
	})
}
