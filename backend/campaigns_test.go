package main

import (
	"net/http"
	"testing"
)

func TestCampaignPublishingAndStaffBoundaries(t *testing.T) {
	h := testAPI(t)
	admin := adminSignIn(t, h)
	c := Campaign{ID: "test-banner", Title: "Fresh picks", Subtitle: "Explore local groceries", CTA: "Browse food", Category: "Food", Colour: "#DCEACD", Position: 2}
	path := "/api/admin/campaigns/test-banner"
	for _, token := range []string{"", testToken} {
		if code, _ := callAs(t, h, token, http.MethodPut, path, c); code != 401 {
			t.Fatalf("non-staff write: %d", code)
		}
	}
	if code, body := callAs(t, h, admin, http.MethodPut, path, c); code != 200 {
		t.Fatalf("draft: %d %v", code, body)
	}
	if got := callListAs(t, h, "", "/api/campaigns"); len(got) != 0 {
		t.Fatalf("draft visible: %v", got)
	}
	if got := callAs2(t, h, admin, "/api/admin/campaigns")["campaigns"].([]any); len(got) != 1 {
		t.Fatalf("missing admin draft: %v", got)
	}
	c.Enabled = true
	if code, _ := callAs(t, h, admin, http.MethodPut, path, c); code != 200 {
		t.Fatal(code)
	}
	got := callListAs(t, h, "", "/api/campaigns")
	if len(got) != 1 || got[0].(map[string]any)["title"] != "Fresh picks" {
		t.Fatalf("published: %v", got)
	}
	c.Title = "Updated picks"
	c.Position = 1
	callAs(t, h, admin, http.MethodPut, path, c)
	got = callListAs(t, h, "", "/api/campaigns")
	if len(got) != 1 || got[0].(map[string]any)["title"] != "Updated picks" {
		t.Fatalf("edit duplicated or stale: %v", got)
	}
	c.Enabled = false
	callAs(t, h, admin, http.MethodPut, path, c)
	if got := callListAs(t, h, "", "/api/campaigns"); len(got) != 0 {
		t.Fatal("hidden banner still visible")
	}
	if code, _ := callAs(t, h, admin, http.MethodDelete, path, nil); code != 204 {
		t.Fatal(code)
	}
	if got := callAs2(t, h, admin, "/api/admin/campaigns")["campaigns"].([]any); len(got) != 0 {
		t.Fatal("deleted banner remained")
	}
}

func TestCampaignRejectsBrokenDestinationsAndUnsafeImages(t *testing.T) {
	h := testAPI(t)
	admin := adminSignIn(t, h)
	for _, change := range []func(*Campaign){
		func(c *Campaign) { c.Category = "Missing category" },
		func(c *Campaign) { c.ImageURL = "javascript:alert(1)" },
		func(c *Campaign) { c.ImageURL = "http://example.com/image.jpg" },
		func(c *Campaign) { c.Colour = "red" },
		func(c *Campaign) { c.Position = -1 },
		func(c *Campaign) { c.Title = " " },
	} {
		c := Campaign{Title: "A banner", CTA: "Explore", Colour: "#F2E8CE"}
		change(&c)
		if code, _ := callAs(t, h, admin, http.MethodPut, "/api/admin/campaigns/invalid", c); code != 400 {
			t.Fatalf("invalid accepted: %d %+v", code, c)
		}
	}
	if got := callAs2(t, h, admin, "/api/admin/campaigns")["campaigns"].([]any); len(got) != 0 {
		t.Fatal("invalid content saved")
	}
}
