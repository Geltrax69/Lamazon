package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// A push service, stood up locally: the subscription endpoint points here, so
// what the backend actually sends over the wire is what gets recorded.
type fakePushService struct {
	*httptest.Server
	mu    sync.Mutex
	calls int
	auth  string // the VAPID Authorization header it was given
}

func newFakePushService(t *testing.T) *fakePushService {
	t.Helper()
	f := &fakePushService{}
	f.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		f.calls++
		f.auth = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusCreated)
	}))
	t.Cleanup(f.Close)
	return f
}

func (f *fakePushService) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

// These are a throwaway pair, generated for the test only.
const (
	testVAPIDPublic  = "BEXu6aCzSzGET0NM99XhPmm0U-LGEI3W6uOMLUWgzPNB7YGOYSMovkWIg60UQyrRRxYtn_DylCzabljQ-qfd5_4"
	testVAPIDPrivate = "pVbmuDYDghQCq9ojifDYMtzoh6FKQIcccvPD3QbSGeY"
	// A real browser key pair's public half; the payload is encrypted to it.
	testP256dh = "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM"
	testAuth   = "tBHItJI5svbpez7KI4CCXg"
)

// notifyAPI is the handler with both channels stubbed, plus the two stubs.
func notifyAPI(t *testing.T) (http.Handler, *sentMail, *fakePushService) {
	t.Helper()
	sent := &sentMail{}
	mailSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			To      []string `json:"to"`
			Subject string   `json:"subject"`
			Text    string   `json:"text"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		sent.to, sent.text = body.To[0], body.Subject+"\n"+body.Text
		sent.count++
		w.Write([]byte(`{"id":"stub"}`))
	}))
	t.Cleanup(mailSrv.Close)

	push := newFakePushService(t)
	return routes(&API{
		db: testDB(t),
		mail: &Mailer{
			key: "k", from: "auth@simpedu.in", http: mailSrv.Client(), base: mailSrv.URL,
		},
		push: &Push{
			publicKey: testVAPIDPublic, privateKey: testVAPIDPrivate,
			subject: "mailto:auth@simpedu.in",
		},
	}), sent, push
}

// An order has to reach the seller on both channels: email always, and a
// browser notification wherever they allowed one.
func TestOrderNotifiesSellerByEmailAndPush(t *testing.T) {
	h, sent, push := notifyAPI(t)

	call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Farm", "location": "Block 32", "city": "LPU",
		"categories": []string{"Grocery"},
	})
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Straubery", "price": 120, "stock": 25})

	// The browser hands over an endpoint and its keys; ours points at the stub.
	code, _ := call(t, h, http.MethodPost, "/api/push/subscribe", map[string]any{
		"endpoint": push.URL + "/push/abc",
		"keys":     map[string]string{"p256dh": testP256dh, "auth": testAuth},
	})
	if code != http.StatusNoContent {
		t.Fatalf("subscribe: want 204, got %d", code)
	}

	if code, _ := call(t, h, http.MethodPost, "/api/seller/orders",
		map[string]any{"itemId": item["id"], "units": 2}); code != http.StatusCreated {
		t.Fatalf("place order: want 201, got %d", code)
	}

	if sent.count != 1 {
		t.Fatalf("seller should get one email, got %d", sent.count)
	}
	if sent.to != DefaultOwner {
		t.Fatalf("email went to %s", sent.to)
	}
	for _, want := range []string{"2 × Straubery", "Farm", "240"} {
		if !strings.Contains(sent.text, want) {
			t.Fatalf("email missing %q:\n%s", want, sent.text)
		}
	}
	if push.count() != 1 {
		t.Fatalf("want one push delivery, got %d", push.count())
	}
	// Signed, or the push service would reject it in production.
	if !strings.HasPrefix(push.auth, "vapid ") {
		t.Fatalf("push was not VAPID-signed: %q", push.auth)
	}
}

// Push being unconfigured must not cost the seller their email.
func TestEmailStillSendsWithoutPush(t *testing.T) {
	h, sent := mailAPI(t)
	call(t, h, http.MethodPost, "/api/seller/store", map[string]any{
		"name": "Farm", "location": "L", "city": "LPU", "categories": []string{"Grocery"},
	})
	_, item := call(t, h, http.MethodPost, "/api/seller/items",
		map[string]any{"title": "Straubery", "price": 120, "stock": 5})
	sent.count = 0 // the sign-in code test mail does not count here

	call(t, h, http.MethodPost, "/api/seller/orders",
		map[string]any{"itemId": item["id"], "units": 1})
	if sent.count != 1 {
		t.Fatalf("email should still go out with push off, got %d", sent.count)
	}
}

// Subscribing is per-person, so it needs a session like the seller routes.
func TestPushSubscribeNeedsASession(t *testing.T) {
	h := testAPI(t)
	req := httptest.NewRequest(http.MethodPost, "/api/push/subscribe",
		strings.NewReader(`{"endpoint":"https://example.com/x","keys":{"p256dh":"a","auth":"b"}}`))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("subscribe without a token: want 401, got %d", rec.Code)
	}
}

// The test notification is the one the seller answers, so it has to carry the
// confirm flag the service worker turns into a button.
func TestPushTestSendsAConfirmableNotification(t *testing.T) {
	h, _, push := notifyAPI(t)

	// Nothing subscribed yet: say so rather than pretending it went.
	if code, body := call(t, h, http.MethodPost, "/api/push/test", nil); code != http.StatusNotFound {
		t.Fatalf("test before subscribing: want 404, got %d (%v)", code, body["error"])
	}

	call(t, h, http.MethodPost, "/api/push/subscribe", map[string]any{
		"endpoint": push.URL + "/push/abc",
		"keys":     map[string]string{"p256dh": testP256dh, "auth": testAuth},
	})

	code, body := call(t, h, http.MethodPost, "/api/push/test", nil)
	if code != http.StatusOK {
		t.Fatalf("test push: want 200, got %d (%v)", code, body["error"])
	}
	if body["sent"].(float64) != 1 {
		t.Fatalf("want one delivery, got %v", body["sent"])
	}
	if push.count() != 1 {
		t.Fatalf("push service saw %d requests", push.count())
	}
}
