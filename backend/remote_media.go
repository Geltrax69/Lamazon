package main

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"syscall"
	"time"
)

// Staff paste links. A link to a picture is a picture; a link to a Pinterest
// pin, an Instagram post or a blog is a web page that is *about* a picture,
// and pointing a banner at one stores 1.1 MB of HTML that renders as nothing.
// This turns the second kind into the first, and refuses the rest.

// Nothing here fetches on the shopper's behalf — only an admin who pasted a
// URL — but this is still our server making a request to an address a stranger
// chose, so it is held to public addresses only.

const (
	// Open Graph tags are supposed to sit near the top of <head>. Pinterest
	// puts a megabyte of inline script between og:site_name and og:image —
	// measured at byte 1,133,825 on a real pin — so "near the top" is worth
	// 2 MB before giving up. It is an admin-triggered fetch, one at a time.
	maxPageRead  = 2 << 20
	maxRemoteURL = 2048
	fetchTimeout = 20 * time.Second
	maxRedirects = 5
)

// publicOnly runs after DNS with the address actually being dialled, which is
// what closes the rebinding hole: a hostname that resolves to 169.254.169.254
// is rejected here even though it looked ordinary in the URL.
func publicOnly(_, address string, _ syscall.RawConn) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return err
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsGlobalUnicast() || ip.IsPrivate() ||
		ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() ||
		ip.IsInterfaceLocalMulticast() {
		return errors.New("that link resolves to a private address")
	}
	// 100.64.0.0/10, carrier-grade NAT — not covered by IsPrivate, and where
	// a good deal of cloud metadata lives.
	if v4 := ip.To4(); v4 != nil && v4[0] == 100 && v4[1] >= 64 && v4[1] < 128 {
		return errors.New("that link resolves to a private address")
	}
	return nil
}

var fetcher = &http.Client{
	Timeout: fetchTimeout,
	Transport: &http.Transport{
		DialContext: (&net.Dialer{
			Timeout: 10 * time.Second,
			Control: publicOnly,
		}).DialContext,
	},
	CheckRedirect: func(r *http.Request, via []*http.Request) error {
		if len(via) >= maxRedirects {
			return errors.New("that link redirects too many times")
		}
		return checkRemoteURL(r.URL)
	},
}

func checkRemoteURL(u *url.URL) error {
	if u.Scheme != "https" || u.Host == "" || u.User != nil {
		return errors.New("use a full https:// link")
	}
	if len(u.String()) > maxRemoteURL {
		return errors.New("that link is too long")
	}
	return nil
}

// Both attribute orders, because plenty of pages write content= first.
var ogTag = regexp.MustCompile(
	`(?is)<meta[^>]+(?:property|name)=["']og:(image|video)(?::(?:url|secure_url))?["'][^>]+content=["']([^"']+)["']|` +
		`<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:(image|video)(?::(?:url|secure_url))?["']`)

// mediaBehind returns a URL that holds an actual file: the one given when it
// already does, or the picture or clip a web page says it is about.
func mediaBehind(ctx context.Context, raw string) (string, error) {
	target, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return "", errors.New("that is not a link")
	}
	if err := checkRemoteURL(target); err != nil {
		return "", err
	}

	kind, body, err := head(ctx, target)
	if err != nil {
		return "", err
	}
	defer body.Close()

	switch {
	case strings.HasPrefix(kind, "image/"), strings.HasPrefix(kind, "video/"):
		return target.String(), nil
	case !strings.HasPrefix(kind, "text/html"):
		return "", errors.New("that link is a " + kind + ", not a picture or a clip")
	}

	page, err := io.ReadAll(io.LimitReader(body, maxPageRead))
	if err != nil {
		return "", errors.New("that page could not be read")
	}
	// A page that names a clip and a picture means the clip: it is what the
	// page is actually showing.
	found := map[string]string{}
	for _, m := range ogTag.FindAllStringSubmatch(string(page), -1) {
		if m[1] != "" {
			found[m[1]] = m[2]
		} else if m[4] != "" {
			found[m[4]] = m[3]
		}
	}
	for _, want := range []string{"video", "image"} {
		if link, ok := found[want]; ok {
			at, err := target.Parse(link) // relative og:image is legal
			if err != nil || checkRemoteURL(at) != nil {
				continue
			}
			return at.String(), nil
		}
	}
	return "", errors.New(
		"that link is a web page, not a file, and the page does not say " +
			"which picture it is about. Open the image itself and copy its " +
			"address — on Pinterest, right-click the pin and choose " +
			"\"Copy image address\"")
}

// head asks for the content type. It is a GET rather than a HEAD because a
// good number of sites answer HEAD with 405 and then serve the page happily.
func head(ctx context.Context, u *url.URL) (string, io.ReadCloser, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return "", nil, errors.New("that link could not be opened")
	}
	// Some sites serve a stub to anything that does not look like a browser,
	// and Open Graph tags are exactly what they put in it for link previews.
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; LamazonBanner/1.0)")
	req.Header.Set("Accept", "image/avif,image/webp,image/*,video/*,text/html;q=0.9,*/*;q=0.8")
	res, err := fetcher.Do(req)
	if err != nil {
		if strings.Contains(err.Error(), "private address") {
			return "", nil, errors.New("that link resolves to a private address")
		}
		return "", nil, errors.New("that link could not be reached")
	}
	if res.StatusCode != http.StatusOK {
		res.Body.Close()
		return "", nil, errors.New("that link answered " + res.Status)
	}
	kind := strings.ToLower(strings.TrimSpace(
		strings.Split(res.Header.Get("Content-Type"), ";")[0]))
	if kind == "" {
		kind = "file of unknown type"
	}
	return kind, res.Body, nil
}
