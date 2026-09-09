package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
)

// Test listings use the same multipart upload flow as the real seller form.
// Only Cloudinary is stubbed; the API still decodes and validates the PNG.
func fixtureCloud(t *testing.T) *Cloudinary {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			t.Error(err)
			w.WriteHeader(400)
			return
		}
		defer r.MultipartForm.RemoveAll()
		if len(r.MultipartForm.File["file"]) != 1 {
			t.Error("missing uploaded file")
		}
		writeJSON(w, 200, map[string]string{"secure_url": "https://res.cloudinary.com/test/image/upload/fixture.png"})
	}))
	t.Cleanup(srv.Close)
	return &Cloudinary{cloud: "test", key: "test", secret: "test", http: srv.Client(), base: srv.URL}
}

func callItemWithPhoto(t *testing.T, h http.Handler, body any) (int, map[string]any) {
	t.Helper()
	var raw bytes.Buffer
	form := multipart.NewWriter(&raw)
	for key, value := range body.(map[string]any) {
		switch value.(type) {
		case string, int, float64:
			_ = form.WriteField(key, fmt.Sprint(value))
		default:
			encoded, _ := json.Marshal(value)
			_ = form.WriteField(key, string(encoded))
		}
	}
	part, err := form.CreateFormFile("file", "product.png")
	if err != nil {
		t.Fatal(err)
	}
	if err = png.Encode(part, image.NewRGBA(image.Rect(0, 0, 2, 2))); err != nil {
		t.Fatal(err)
	}
	if err = form.Close(); err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest("POST", "/api/seller/items", &raw)
	req.Header.Set("Content-Type", form.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+testToken)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}
