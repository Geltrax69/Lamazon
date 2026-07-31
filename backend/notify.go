package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"strings"

	webpush "github.com/SherClockHolmes/webpush-go"
)

// Push sends browser notifications. ponytail: the Web Push protocol directly,
// no Firebase — FCM for the web is a wrapper around this same thing, and the
// wrapper costs a project, two client packages and a service account.
type Push struct {
	publicKey, privateKey, subject string
}

func pushFromEnv() *Push {
	p := &Push{
		publicKey:  os.Getenv("VAPID_PUBLIC_KEY"),
		privateKey: os.Getenv("VAPID_PRIVATE_KEY"),
		subject:    os.Getenv("VAPID_SUBJECT"),
	}
	if p.publicKey == "" || p.privateKey == "" {
		return nil
	}
	if p.subject == "" {
		p.subject = "mailto:admin@example.com"
	}
	return p
}

// A subscription is what the browser hands us: where to deliver, plus the two
// keys that encrypt the payload so the push service cannot read it.
type subscription struct {
	Endpoint string `json:"endpoint"`
	Keys     struct {
		P256dh string `json:"p256dh"`
		Auth   string `json:"auth"`
	} `json:"keys"`
}

// GET /api/push/key — the app needs the public key to subscribe, and baking
// it into the build would mean rebuilding to rotate it.
func (a *API) handlePushKey(w http.ResponseWriter, r *http.Request) {
	if a.push == nil {
		writeError(w, http.StatusServiceUnavailable, "push is not configured")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"publicKey": a.push.publicKey})
}

// POST /api/push/subscribe — one row per browser. The same person on a phone
// and a laptop gets two, and both are notified.
func (a *API) handlePushSubscribe(w http.ResponseWriter, r *http.Request) {
	var in subscription
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if in.Endpoint == "" || in.Keys.P256dh == "" || in.Keys.Auth == "" {
		writeError(w, http.StatusBadRequest, "endpoint and keys are required")
		return
	}
	// Re-subscribing with the same endpoint refreshes it rather than
	// duplicating; browsers hand back the same endpoint until it expires.
	if _, err := a.db.sql.ExecContext(r.Context(), `
		INSERT INTO push_subscriptions (endpoint, email, p256dh, auth)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (endpoint) DO UPDATE SET
			email = EXCLUDED.email, p256dh = EXCLUDED.p256dh, auth = EXCLUDED.auth`,
		in.Endpoint, a.owner(r), in.Keys.P256dh, in.Keys.Auth); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// DELETE /api/push/subscribe — the browser unsubscribed, or the seller turned
// notifications off.
func (a *API) handlePushUnsubscribe(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Endpoint string `json:"endpoint"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if _, err := a.db.sql.ExecContext(r.Context(),
		`DELETE FROM push_subscriptions WHERE endpoint = $1 AND email = $2`,
		in.Endpoint, a.owner(r)); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// POST /api/push/test — proves the whole chain end to end: this backend, the
// push service, the browser, the service worker. The notification carries a
// confirm button, so the seller answering it is the proof it arrived.
func (a *API) handlePushTest(w http.ResponseWriter, r *http.Request) {
	if a.push == nil {
		writeError(w, http.StatusServiceUnavailable, "push is not configured")
		return
	}
	email := a.owner(r)
	subs, err := a.db.pushSubscriptions(r.Context(), email)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if len(subs) == 0 {
		writeError(w, http.StatusNotFound, "this browser is not subscribed yet")
		return
	}

	payload, _ := json.Marshal(map[string]any{
		"title": "Notifications are on",
		"body":  "Tap below to confirm you got this.",
		"tag":   "lamazon-test",
		// The service worker turns this into a button on the notification.
		"confirm": true,
	})
	var sent int
	for _, s := range subs {
		if err := a.push.send(r.Context(), s, payload); err != nil {
			log.Printf("test push to %s: %v", email, err)
			if errors.Is(err, errSubscriptionGone) {
				a.db.sql.ExecContext(r.Context(),
					`DELETE FROM push_subscriptions WHERE endpoint = $1`, s.Endpoint)
			}
			continue
		}
		sent++
	}
	if sent == 0 {
		writeError(w, http.StatusBadGateway, "the push service would not take it")
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{"sent": sent})
}

// notify reaches one person on every channel that is set up: email always,
// because it works on every phone with nothing installed, and a browser
// notification on top wherever they allowed one.
//
// Nothing here is fatal. A failed notification must never fail the order that
// triggered it, so problems are logged and the caller carries on.
func (a *API) notify(ctx context.Context, email, title, body string) {
	if a.mail != nil {
		if err := a.mail.send(ctx, email, title, body, notifyHTML(title, body)); err != nil {
			log.Printf("notify %s by email: %v", email, err)
		}
	}
	if a.push == nil {
		return
	}

	subs, err := a.db.pushSubscriptions(ctx, email)
	if err != nil {
		log.Printf("notify %s: reading subscriptions: %v", email, err)
		return
	}

	payload, _ := json.Marshal(map[string]string{"title": title, "body": body})
	for _, s := range subs {
		if err := a.push.send(ctx, s, payload); err != nil {
			log.Printf("notify %s by push: %v", email, err)
			// A browser that has thrown the subscription away answers 404 or
			// 410 forever. Dropping it keeps the table from filling with dead
			// endpoints that are retried on every order.
			if errors.Is(err, errSubscriptionGone) {
				a.db.sql.ExecContext(ctx,
					`DELETE FROM push_subscriptions WHERE endpoint = $1`, s.Endpoint)
			}
		}
	}
}

var errSubscriptionGone = errors.New("subscription no longer exists")

func (p *Push) send(ctx context.Context, s subscription, payload []byte) error {
	res, err := webpush.SendNotificationWithContext(ctx, payload, &webpush.Subscription{
		Endpoint: s.Endpoint,
		Keys:     webpush.Keys{P256dh: s.Keys.P256dh, Auth: s.Keys.Auth},
	}, &webpush.Options{
		Subscriber:      p.subject,
		VAPIDPublicKey:  p.publicKey,
		VAPIDPrivateKey: p.privateKey,
		TTL:             86400, // a day: an order is still worth reading tomorrow
	})
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusNotFound || res.StatusCode == http.StatusGone {
		return errSubscriptionGone
	}
	if res.StatusCode >= 300 {
		return errors.New("push service said " + strings.TrimSpace(res.Status))
	}
	return nil
}

// pushSubscriptions is every browser this address has registered — a phone and
// a laptop are two rows, and both get told.
func (d *DB) pushSubscriptions(ctx context.Context, email string) ([]subscription, error) {
	rows, err := d.sql.QueryContext(ctx,
		`SELECT endpoint, p256dh, auth FROM push_subscriptions WHERE email = $1`, email)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []subscription
	for rows.Next() {
		var s subscription
		if err := rows.Scan(&s.Endpoint, &s.Keys.P256dh, &s.Keys.Auth); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}
