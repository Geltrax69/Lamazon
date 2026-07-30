package main

import (
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Cloudinary uploads photos and hands back the URL to store in Postgres.
// ponytail: a signed form POST is the whole API we need, so no SDK — the
// signature is one sha1 of the sorted params plus the secret.
type Cloudinary struct {
	cloud, key, secret string
	http               *http.Client
	base               string // overridden by the tests; the real API is not free
}

// cloudinaryFromEnv returns nil when the credentials are absent, which is how
// tests and a fresh checkout run without an account.
func cloudinaryFromEnv() *Cloudinary {
	c := &Cloudinary{
		cloud:  os.Getenv("CLOUDINARY_CLOUD_NAME"),
		key:    os.Getenv("CLOUDINARY_API_KEY"),
		secret: os.Getenv("CLOUDINARY_API_SECRET"),
		http:   &http.Client{Timeout: 30 * time.Second},
		base:   "https://api.cloudinary.com",
	}
	if c.cloud == "" || c.key == "" || c.secret == "" {
		return nil
	}
	return c
}

// Root folder for everything this app uploads.
const cloudRoot = "Lamazon"

// storeFolder is where everything for one seller lives: Lamazon/<Store>.
func storeFolder(store string) string {
	return cloudRoot + "/" + slug(store)
}

// storePhotoName is the cover photo of a store. One name per store, so
// replacing the photo overwrites rather than piles up.
const storePhotoName = "store_image"

// itemPhotoName names an item photo <store>_<item>_<n>, numbered from 1.
func itemPhotoName(store, item string, n int) string {
	return fmt.Sprintf("%s_%s_%d", slug(store), slug(item), n)
}

var notNameChar = regexp.MustCompile(`[^A-Za-z0-9]+`)

// slug keeps public ids readable and keeps user input from inventing folders.
func slug(s string) string {
	out := strings.Trim(notNameChar.ReplaceAllString(s, "_"), "_")
	if out == "" {
		return "unnamed"
	}
	return out
}

// upload stores one image in a Media Library folder and returns its https URL.
// Uploading the same name into the same folder replaces the picture and
// invalidates the CDN copy.
//
// asset_folder is what actually files the image: this product environment uses
// dynamic folders, where a public id like "a/b/c" is just a name with slashes
// in it and everything would otherwise pile up in Home.
func (c *Cloudinary) upload(ctx context.Context, folder, name string, img []byte) (string, error) {
	publicID := folder + "/" + name
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	// Signed params, alphabetical, then the secret appended — Cloudinary's rule.
	sum := sha1.Sum([]byte(
		"asset_folder=" + folder + "&display_name=" + name +
			"&invalidate=true&overwrite=true&public_id=" + publicID +
			"&timestamp=" + ts + c.secret))

	var body bytes.Buffer
	form := multipart.NewWriter(&body)
	for k, v := range map[string]string{
		"api_key":      c.key,
		"timestamp":    ts,
		"public_id":    publicID,
		"asset_folder": folder,
		"display_name": name,
		"overwrite":    "true",
		"invalidate":   "true",
		"signature":    hex.EncodeToString(sum[:]),
	} {
		if err := form.WriteField(k, v); err != nil {
			return "", err
		}
	}
	part, err := form.CreateFormFile("file", "upload")
	if err != nil {
		return "", err
	}
	if _, err := part.Write(img); err != nil {
		return "", err
	}
	if err := form.Close(); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.base+"/v1_1/"+c.cloud+"/image/upload", &body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", form.FormDataContentType())

	res, err := c.http.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return "", err
	}
	if res.StatusCode != http.StatusOK {
		// Cloudinary explains itself in the body; passing it through beats
		// guessing at a bare 401.
		return "", fmt.Errorf("cloudinary %s: %s", res.Status, strings.TrimSpace(string(payload)))
	}
	var out struct {
		SecureURL string `json:"secure_url"`
	}
	if err := json.Unmarshal(payload, &out); err != nil {
		return "", err
	}
	if out.SecureURL == "" {
		return "", fmt.Errorf("cloudinary returned no url: %s", payload)
	}
	return out.SecureURL, nil
}
