package main

import (
	"context"
	"crypto/tls"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// Staff paste links, and a link is not a file. These are the two things that
// have to hold: a web page resolves to the picture it is about, and our server
// never fetches an address that belongs to our own network.

// The guard refuses to dial anything private, so a test server on 127.0.0.1 is
// unreachable by design. Swapping the client leaves the guard itself to
// TestOurOwnNetworkIsNotReachable, which tests it directly.
func unguarded(t *testing.T) {
	t.Helper()
	was := fetcher
	fetcher = &http.Client{
		Timeout: fetchTimeout,
		// The test origins below are httptest's self-signed TLS, so the https
		// rule in checkRemoteURL stays under test rather than being relaxed.
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, //nolint:gosec // test origin
		},
		CheckRedirect: was.CheckRedirect,
	}
	t.Cleanup(func() { fetcher = was })
}

func serving(t *testing.T, kind, body string) string {
	t.Helper()
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", kind)
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return srv.URL
}

func TestOurOwnNetworkIsNotReachable(t *testing.T) {
	// An admin can paste anything, including an address that only means
	// something from inside our own network. Checked at dial time, on the
	// address actually resolved, so a hostname that points at one of these
	// is caught too.
	for _, address := range []string{
		"127.0.0.1:443",      // ourselves
		"10.4.1.9:443",       // private
		"192.168.0.5:443",    // private
		"172.16.3.1:443",     // private
		"169.254.169.254:80", // the cloud metadata service
		"100.64.0.1:443",     // carrier NAT, not covered by IsPrivate
		"[::1]:443",          // ourselves again
		"[fe80::1]:443",      // link local
	} {
		if err := publicOnly("tcp", address, nil); err == nil {
			t.Errorf("%s should have been refused", address)
		}
	}
	if err := publicOnly("tcp", "93.184.216.34:443", nil); err != nil {
		t.Errorf("a public address should be allowed: %v", err)
	}
}

func TestOnlyAFullHTTPSLinkIsAccepted(t *testing.T) {
	unguarded(t)
	for _, link := range []string{
		"",
		"not a link at all",
		"http://example.test/a.png",          // plaintext
		"ftp://example.test/a.png",           // not the web
		"https://user:pw@example.test/a.png", // credentials in a URL
		"file:///etc/passwd",
		"https://example.test/" + strings.Repeat("a", 2100),
	} {
		if _, err := mediaBehind(context.Background(), link); err == nil {
			t.Errorf("%.40q should have been refused", link)
		}
	}
}

func TestAPictureLinkIsUsedAsItIs(t *testing.T) {
	unguarded(t)
	for _, kind := range []string{"image/png", "image/gif", "video/mp4"} {
		origin := serving(t, kind, "not really, but the header is what counts")
		got, err := mediaBehind(context.Background(), origin)
		if err != nil || got != origin {
			t.Errorf("%s: got %q, %v", kind, got, err)
		}
	}
}

func TestAWebPageResolvesToThePictureItIsAbout(t *testing.T) {
	unguarded(t)
	// This is what a Pinterest pin actually serves: a megabyte of HTML whose
	// head names the picture. Pasting the page without this stores the HTML.
	page := `<html><head>
	  <meta property="og:title" content="Diwali lights"/>
	  <meta content="https://i.pinimg.com/736x/b3/b8/fc/b3b8fc29.jpg" property="og:image"/>
	  </head><body>` + strings.Repeat("x", 4096) + `</body></html>`
	got, err := mediaBehind(context.Background(), serving(t, "text/html; charset=utf-8", page))
	if err != nil {
		t.Fatal(err)
	}
	if got != "https://i.pinimg.com/736x/b3/b8/fc/b3b8fc29.jpg" {
		t.Fatalf("got %q", got)
	}
}

func TestATagBuriedUnderAMegabyteOfScriptIsStillFound(t *testing.T) {
	unguarded(t)
	// Not hypothetical. A real Pinterest pin puts og:image at byte 1,133,825,
	// behind a megabyte of inline script, and a 512 KB read found nothing and
	// told the admin their link was unusable. This is the regression.
	page := `<html><head><meta property="og:site_name" content="Pinterest"/>` +
		`<script>` + strings.Repeat("/*filler*/", 110_000) + `</script>` +
		`<meta content="https://i.pinimg.com/736x/deep.jpg" property="og:image"/>` +
		`</head></html>`
	if len(page) < 1<<20 {
		t.Fatalf("the fixture is meant to be over a megabyte, it is %d", len(page))
	}
	got, err := mediaBehind(context.Background(), serving(t, "text/html", page))
	if err != nil || got != "https://i.pinimg.com/736x/deep.jpg" {
		t.Fatalf("got %q, %v", got, err)
	}
}

func TestAPageShowingAClipPrefersTheClip(t *testing.T) {
	unguarded(t)
	page := `<html><head>
	  <meta property="og:image" content="https://cdn.test/poster.jpg">
	  <meta property="og:video:secure_url" content="https://cdn.test/reel.mp4">
	  </head></html>`
	got, err := mediaBehind(context.Background(), serving(t, "text/html", page))
	if err != nil || got != "https://cdn.test/reel.mp4" {
		t.Fatalf("got %q, %v — the clip is what the page is showing", got, err)
	}
}

func TestAPageThatNamesNothingSaysWhatToDoInstead(t *testing.T) {
	unguarded(t)
	_, err := mediaBehind(context.Background(),
		serving(t, "text/html", "<html><body>no meta tags here</body></html>"))
	if err == nil {
		t.Fatal("a page with no picture in it is not a banner")
	}
	// The message has to be actionable: this is the one an admin will read.
	if !strings.Contains(err.Error(), "Copy image address") {
		t.Fatalf("unhelpful message: %v", err)
	}
}

func TestSomethingThatIsNeitherIsRefused(t *testing.T) {
	unguarded(t)
	if _, err := mediaBehind(context.Background(),
		serving(t, "application/pdf", "%PDF-1.4")); err == nil {
		t.Fatal("a PDF is not a banner")
	}
}

// The last line of defence. A source that lies about its content type gets
// past mediaBehind, so the resource type Cloudinary decided on is checked too
// — otherwise a web page becomes a 1 MB banner that renders as nothing.
func TestAPageThatLiesAboutItselfStillCannotBecomeABanner(t *testing.T) {
	unguarded(t)
	h := testAPI(t)
	admin := adminSignIn(t, h)

	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "image/png") // it is not
		_, _ = w.Write([]byte("<html>a web page</html>"))
	}))
	t.Cleanup(srv.Close)

	// The stub reads the resource type off the link, so ".html" is how the
	// test says "Cloudinary decided this was raw".
	code, body := callAs(t, h, admin, http.MethodPost, "/api/admin/campaign-media",
		map[string]any{"url": srv.URL + "/pin.html"})
	if code != 400 {
		t.Fatalf("expected a refusal, got %d %v", code, body)
	}
	if msg, _ := body["error"].(string); !strings.Contains(msg, "not a picture or a clip") {
		t.Fatalf("unclear refusal: %v", body)
	}
}

func TestAPastedPictureIsStoredOnOurOwnCDN(t *testing.T) {
	unguarded(t)
	h := testAPI(t)
	admin := adminSignIn(t, h)
	origin := serving(t, "image/png", "pretend png")

	code, body := callAs(t, h, admin, http.MethodPost, "/api/admin/campaign-media",
		map[string]any{"url": origin + "/festival.png"})
	if code != 200 {
		t.Fatalf("expected the import to work, got %d %v", code, body)
	}
	// Not the address that was pasted: hotlinking somebody else's server is a
	// banner that breaks the day they tidy up.
	if url, _ := body["imageUrl"].(string); !strings.HasPrefix(url, "https://res.cloudinary.com/") {
		t.Fatalf("expected our own CDN, got %v", body)
	}
}
