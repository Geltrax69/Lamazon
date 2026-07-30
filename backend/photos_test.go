package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
)

// A real 1x1 PNG, so http.DetectContentType agrees this is an image.
var onePixelPNG = []byte{
	0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a,
	0x00, 0x00, 0x00, 0x0d, 'I', 'H', 'D', 'R',
	0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
	0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
	0x89, 0x00, 0x00, 0x00, 0x0a, 'I', 'D', 'A', 'T',
	0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05,
	0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00,
	0x00, 0x00, 'I', 'E', 'N', 'D', 0xae, 0x42, 0x60, 0x82,
}

// fakeCloudinary stands in for the real service: it checks the signature the
// way Cloudinary does and records what it was asked to store.
type fakeCloudinary struct {
	*httptest.Server
	secret string
	// Recorded per upload: where the Media Library will file it, and under
	// what name. Folder placement is the whole point of asset_folder.
	folders   []string
	names     []string
	publicIDs []string
}

func newFakeCloudinary(t *testing.T, secret string) *fakeCloudinary {
	t.Helper()
	f := &fakeCloudinary{secret: secret}
	f.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			t.Errorf("cloudinary got an unparseable body: %v", err)
			return
		}
		id := r.FormValue("public_id")

		// Recompute the signature exactly as Cloudinary documents it: the
		// signed params sorted by name, then the secret.
		raw := fmt.Sprintf(
			"asset_folder=%s&display_name=%s&invalidate=%s&overwrite=%s&public_id=%s&timestamp=%s%s",
			r.FormValue("asset_folder"), r.FormValue("display_name"),
			r.FormValue("invalidate"), r.FormValue("overwrite"), id,
			r.FormValue("timestamp"), f.secret)
		want := sha1.Sum([]byte(raw))
		if got := r.FormValue("signature"); got != hex.EncodeToString(want[:]) {
			t.Errorf("bad signature for %s:\n got %s\nwant %s", id, got, hex.EncodeToString(want[:]))
		}
		if r.FormValue("api_key") == "" {
			t.Error("api_key missing")
		}
		if _, _, err := r.FormFile("file"); err != nil {
			t.Errorf("no file part: %v", err)
		}

		f.publicIDs = append(f.publicIDs, id)
		f.folders = append(f.folders, r.FormValue("asset_folder"))
		f.names = append(f.names, r.FormValue("display_name"))
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"secure_url": "https://res.cloudinary.com/test/image/upload/" + id + ".png",
		})
	}))
	t.Cleanup(f.Close)
	return f
}

// photoAPI is testAPI plus a backend whose uploads go to the fake.
func photoAPI(t *testing.T) (http.Handler, *fakeCloudinary) {
	t.Helper()
	fake := newFakeCloudinary(t, "test-secret")
	return routes(&API{
		db: testDB(t),
		cloud: &Cloudinary{
			cloud: "demo", key: "key", secret: fake.secret,
			http: fake.Client(), base: fake.URL,
		},
	}), fake
}

// postPhotos builds the multipart body the Flutter client sends.
func postPhotos(t *testing.T, h http.Handler, path string, files ...[]byte) (int, map[string]any) {
	t.Helper()
	var body bytes.Buffer
	form := multipart.NewWriter(&body)
	for i, f := range files {
		part, err := form.CreateFormFile("file", fmt.Sprintf("photo_%d.png", i+1))
		if err != nil {
			t.Fatal(err)
		}
		part.Write(f)
	}
	form.Close()

	req := httptest.NewRequest(http.MethodPost, path, &body)
	req.Header.Set("Content-Type", form.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+testToken)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	var out map[string]any
	json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}

func TestPhotosUploadAndPersist(t *testing.T) {
	h, fake := photoAPI(t)

	// Photos need a store to be filed under.
	if code, _ := postPhotos(t, h, "/api/seller/store/photo", onePixelPNG); code != http.StatusNotFound {
		t.Fatalf("photo before store: want 404, got %d", code)
	}
	call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Campus Snacks", "location": "Block 32", "city": "LPU",
		"categories": []string{"Food"},
	})

	code, body := postPhotos(t, h, "/api/seller/store/photo", onePixelPNG)
	if code != http.StatusCreated {
		t.Fatalf("store photo: want 201, got %d (%v)", code, body["error"])
	}
	if fake.publicIDs[0] != "Lamazon/Campus_Snacks/store_image" {
		t.Fatalf("store photo id: %s", fake.publicIDs[0])
	}
	// Without asset_folder every asset lands in Home, whatever the id says.
	if fake.folders[0] != "Lamazon/Campus_Snacks" || fake.names[0] != "store_image" {
		t.Fatalf("store photo filed as %s / %s", fake.folders[0], fake.names[0])
	}
	// The URL has to survive into Postgres, not just the response.
	_, store := call(t, h, http.MethodGet, "/api/seller/store", nil)
	if store["photoUrl"] != body["photoUrl"] {
		t.Fatalf("photoUrl not persisted: %v vs %v", store["photoUrl"], body["photoUrl"])
	}

	_, item := call(t, h, http.MethodPost, "/api/seller/items", map[string]any{
		"title": "Cold Coffee 300ml", "category": "Food", "price": 60, "stock": 10,
	})
	id := item["id"].(string)

	// Two photos in one request, numbered from 1.
	code, body = postPhotos(t, h, "/api/seller/items/"+id+"/photos", onePixelPNG, onePixelPNG)
	if code != http.StatusCreated {
		t.Fatalf("item photos: want 201, got %d (%v)", code, body["error"])
	}
	if got := len(body["imageUrls"].([]any)); got != 2 {
		t.Fatalf("want 2 urls, got %d", got)
	}
	want := []string{
		"Lamazon/Campus_Snacks/Campus_Snacks_Cold_Coffee_300ml_1",
		"Lamazon/Campus_Snacks/Campus_Snacks_Cold_Coffee_300ml_2",
	}
	for i, w := range want {
		if fake.publicIDs[i+1] != w {
			t.Fatalf("item photo %d: got %s want %s", i+1, fake.publicIDs[i+1], w)
		}
		if fake.folders[i+1] != "Lamazon/Campus_Snacks" {
			t.Fatalf("item photo %d filed in %s", i+1, fake.folders[i+1])
		}
	}

	// A third photo continues the numbering instead of restarting.
	postPhotos(t, h, "/api/seller/items/"+id+"/photos", onePixelPNG)
	if last := fake.publicIDs[3]; last != "Lamazon/Campus_Snacks/Campus_Snacks_Cold_Coffee_300ml_3" {
		t.Fatalf("third photo: %s", last)
	}
	// Photos are exempt from the 1 MiB body cap the JSON routes live under.
	big := append(append([]byte{}, onePixelPNG...), make([]byte, 2<<20)...)
	if code, body := postPhotos(t, h, "/api/seller/items/"+id+"/photos", big); code != http.StatusCreated {
		t.Fatalf("2 MB photo: want 201, got %d (%v)", code, body["error"])
	}

	_, listed := call(t, h, http.MethodGet, "/api/seller/items", nil)
	urls := listed["items"].([]any)[0].(map[string]any)["imageUrls"].([]any)
	if len(urls) != 4 {
		t.Fatalf("item should have 4 urls after appending, got %d", len(urls))
	}
}

func TestPhotoRejectsNonImage(t *testing.T) {
	h, _ := photoAPI(t)
	call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "S", "location": "L", "city": "LPU", "categories": []string{"Food"},
	})
	code, body := postPhotos(t, h, "/api/seller/store/photo", []byte("#!/bin/sh\nrm -rf /\n"))
	if code != http.StatusBadRequest {
		t.Fatalf("script as photo: want 400, got %d", code)
	}
	if body["error"] == nil {
		t.Fatal("rejection should say why")
	}
}

// Without credentials the routes have to say so rather than half-work.
func TestPhotosWithoutCredentials(t *testing.T) {
	h := testAPI(t) // built with cloud == nil
	if code, _ := postPhotos(t, h, "/api/seller/store/photo", onePixelPNG); code != http.StatusServiceUnavailable {
		t.Fatalf("no credentials: want 503, got %d", code)
	}
}

// postForm builds a multipart create request: text fields plus optional files.
func postForm(t *testing.T, h http.Handler, path string,
	fields map[string][]string, files ...[]byte) (int, map[string]any) {
	t.Helper()
	var body bytes.Buffer
	form := multipart.NewWriter(&body)
	for k, vs := range fields {
		for _, v := range vs {
			form.WriteField(k, v)
		}
	}
	for i, f := range files {
		part, err := form.CreateFormFile("file", fmt.Sprintf("photo_%d.png", i+1))
		if err != nil {
			t.Fatal(err)
		}
		part.Write(f)
	}
	form.Close()

	req := httptest.NewRequest(http.MethodPost, path, &body)
	req.Header.Set("Content-Type", form.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+testToken)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	var out map[string]any
	json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}

// One call each for store and item, photos included — what the app sends.
func TestCreateWithPhotosInOneCall(t *testing.T) {
	h, fake := photoAPI(t)

	code, store := postForm(t, h, "/api/seller/store", map[string][]string{
		"name": {"Farm"}, "location": {"Block 32"}, "city": {"LPU"},
		"categories": {"Grocery", "Food"},
	}, onePixelPNG)
	if code != http.StatusCreated {
		t.Fatalf("store: want 201, got %d (%v)", code, store["error"])
	}
	if store["photoUrl"] == "" || store["photoUrl"] == nil {
		t.Fatal("store came back without its photo url")
	}
	if len(store["categories"].([]any)) != 2 {
		t.Fatalf("repeated field should give 2 categories, got %v", store["categories"])
	}

	code, item := postForm(t, h, "/api/seller/items", map[string][]string{
		"title": {"Straubery"}, "category": {"Grocery"},
		"price": {"120"}, "stock": {"25"},
	}, onePixelPNG, onePixelPNG)
	if code != http.StatusCreated {
		t.Fatalf("item: want 201, got %d (%v)", code, item["error"])
	}
	if got := len(item["imageUrls"].([]any)); got != 2 {
		t.Fatalf("want 2 urls on the created item, got %d", got)
	}
	if item["price"].(float64) != 120 || item["stock"].(float64) != 25 {
		t.Fatalf("form numbers not parsed: %v / %v", item["price"], item["stock"])
	}

	want := []string{
		"Lamazon/Farm/store_image",
		"Lamazon/Farm/Farm_Straubery_1",
		"Lamazon/Farm/Farm_Straubery_2",
	}
	for i, w := range want {
		if fake.publicIDs[i] != w {
			t.Fatalf("upload %d: got %s want %s", i, fake.publicIDs[i], w)
		}
		if fake.folders[i] != "Lamazon/Farm" {
			t.Fatalf("upload %d filed in %s", i, fake.folders[i])
		}
	}
	// And the item is readable with its photos attached.
	_, listed := call(t, h, http.MethodGet, "/api/seller/items", nil)
	if n := len(listed["items"].([]any)); n != 1 {
		t.Fatalf("want 1 item, got %d", n)
	}
}

// The point of uploading before writing: a Cloudinary failure must not leave a
// store or an item behind for the seller to wonder about.
func TestFailedUploadWritesNothing(t *testing.T) {
	h, _ := photoAPI(t)
	call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Farm", "location": "L", "city": "LPU", "categories": []string{"Grocery"},
	})

	// A text file is rejected before the row is written.
	if code, _ := postForm(t, h, "/api/seller/items", map[string][]string{
		"title": {"Ghost"}, "price": {"10"}, "stock": {"1"},
	}, []byte("not an image at all")); code != http.StatusBadRequest {
		t.Fatalf("bad photo: want 400, got %d", code)
	}
	_, listed := call(t, h, http.MethodGet, "/api/seller/items", nil)
	if n := len(listed["items"].([]any)); n != 0 {
		t.Fatalf("failed upload left %d items behind", n)
	}
}

// A bad number in a form is a 400, not a silently zeroed price.
func TestFormNumbersValidated(t *testing.T) {
	h, _ := photoAPI(t)
	call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Farm", "location": "L", "city": "LPU", "categories": []string{"Grocery"},
	})
	code, body := postForm(t, h, "/api/seller/items", map[string][]string{
		"title": {"Odd"}, "price": {"twelve"}, "stock": {"1"},
	})
	if code != http.StatusBadRequest || body["error"] == nil {
		t.Fatalf("price=twelve: want 400 with a reason, got %d %v", code, body)
	}
}
