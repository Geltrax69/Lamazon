package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
)

func TestPasswordEndpointsThrottleNormalizedAccounts(t *testing.T) {
	for _, tc := range []struct {
		path            string
		body, alternate map[string]string
	}{
		{"/api/admin/login", map[string]string{"username": "Boss", "password": "wrong"}, map[string]string{"username": " boss ", "password": "wrong"}},
		{"/api/login/password", map[string]string{"email": "Shopper@example.com", "password": "wrong"}, map[string]string{"email": " shopper@example.com ", "password": "wrong"}},
		{"/api/delivery/login", map[string]string{"phone": "9876543210", "pin": "wrong"}, map[string]string{"phone": "+91 98765 43210", "pin": "wrong"}},
	} {
		t.Run(tc.path, func(t *testing.T) {
			h := testAPI(t)
			for i := 0; i < 10; i++ {
				code, _ := callAs(t, h, "", http.MethodPost, tc.path, tc.body)
				if code != http.StatusUnauthorized {
					t.Fatalf("attempt %d: got %d", i, code)
				}
			}
			code, _ := callAs(t, h, "", http.MethodPost, tc.path, tc.alternate)
			if code != http.StatusTooManyRequests {
				t.Fatalf("normalized account bypassed limit: %d", code)
			}
			// Rebuilding the handler simulates another API process; state is in Postgres.
			other := routes(&API{db: lastTestDB})
			code, _ = callAs(t, other, "", http.MethodPost, tc.path, tc.body)
			if code != http.StatusTooManyRequests {
				t.Fatalf("new process bypassed limit: %d", code)
			}
			if _, err := lastTestDB.sql.Exec(`UPDATE password_attempts SET expires_at = now()-interval '1 second'`); err != nil {
				t.Fatal(err)
			}
			code, _ = callAs(t, other, "", http.MethodPost, tc.path, tc.body)
			if code != http.StatusUnauthorized {
				t.Fatalf("expired lockout did not recover: %d", code)
			}
		})
	}
}

func TestPasswordLimiterConcurrentAttemptsAndRetryHeader(t *testing.T) {
	a := &API{db: testDB(t)}
	var allowed atomic.Int32
	var wg sync.WaitGroup
	for i := 0; i < 24; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			r := httptest.NewRequest(http.MethodPost, "/api/login/password", nil)
			r.RemoteAddr = fmt.Sprintf("192.0.2.%d:1234", i+1)
			w := httptest.NewRecorder()
			if a.allowPasswordAttempt(w, r, "shopper", "one@example.com") {
				allowed.Add(1)
			} else if w.Code != 429 || w.Header().Get("Retry-After") == "" {
				t.Errorf("missing throttle response: %d %v", w.Code, w.Header())
			}
		}(i)
	}
	wg.Wait()
	if allowed.Load() != 10 {
		t.Fatalf("parallel attempts allowed %d, want 10", allowed.Load())
	}
}

func TestPasswordLimiterIPBudgetCannotBeBypassedByForwardingHeader(t *testing.T) {
	a := &API{db: testDB(t)}
	for i := 0; i < 101; i++ {
		r := httptest.NewRequest(http.MethodPost, "/api/admin/login", nil)
		r.RemoteAddr = "192.0.2.1:1234"
		r.Header.Set("X-Forwarded-For", fmt.Sprintf("198.51.100.%d", i))
		w := httptest.NewRecorder()
		allowed := a.allowPasswordAttempt(w, r, "admin", fmt.Sprint(i))
		if allowed != (i < 100) {
			t.Fatalf("IP budget attempt %d allowed=%v", i, allowed)
		}
	}
}

func TestNewRiderPINHasSixDigits(t *testing.T) {
	pin, hash, err := newPIN()
	if err != nil {
		t.Fatal(err)
	}
	if len(pin) != 6 || !passwordMatches(hash, pin) {
		t.Fatalf("invalid generated PIN")
	}
	for _, d := range pin {
		if d < '0' || d > '9' {
			t.Fatal("PIN must contain only digits")
		}
	}
}
