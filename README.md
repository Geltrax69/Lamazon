# Lamazon

> ## Status: 🟢 Completed
>
> <progress value="90" max="100"></progress>
> **Progress: 90%** — Live marketplace: Flutter storefront + Go API in production; CI green. Open items are operational, not broken code.

<p align="center">
  <img src="banner.webp" alt="Lamazon banner" width="100%" />
</p>

![Flutter](https://img.shields.io/badge/flutter-3.x-blue)
![Go](https://img.shields.io/badge/go-1.25-00ADD8)
![Postgres](https://img.shields.io/badge/postgres-16-336791)

## What it is

Lamazon is a full Amazon-style marketplace, not a demo UI. A **Flutter** app (web at `/app` via Vercel, Android APK built by CI) talks to a **Go REST API** backed by **PostgreSQL** — live in production at `https://api.geltrax.engineer`. Shoppers browse a catalog, compare products, fill a cart and check out; sellers onboard stores, manage items, photos, stock and orders; riders accept and deliver; admins manage policies, campaigns and photos. The Go backend uses only the standard library's `net/http` mux plus `pgx` — no web framework — and the schema self-applies with seeded policies on boot, so a fresh database is ready with no manual steps.

## What works (verified)

- ✅ Catalog: products, categories, campaigns, compare groups, shops, storefront season — verified by reading `backend/catalog.go`, `categories.go`, `campaigns.go`, `compare.go` + frontend `lib/screens/` (28 screens: home, search, details, compare, shops, cart…).
- ✅ Auth: emailed sign-in codes, password login, refresh tokens, rate-limited login/PIN — verified in `backend/auth.go`, `login_limit.go` + `login_screen.dart`.
- ✅ Cart & atomic checkout: one delivery fee, matching totals, durable retry IDs — verified in `backend/orders.go`, `checkout_test.go`.
- ✅ Order lifecycle: place, seller accept/reject/deliver, buyer cancel-before-acceptance — verified in `backend/orders.go`, `orders_screen.dart`.
- ✅ Seller dashboard: store onboarding, items, photo upload (Cloudinary), stock, listings — verified in `backend/catalog.go` seller handlers + `seller_dashboard_screen.dart`.
- ✅ Admin console + rider delivery flow — verified in `backend/` admin/photo handlers + `admin_screen.dart`, `delivery_screen.dart`.
- ✅ Web push notifications (FCM), notification preferences, address book, wishlist, policies — verified in `backend/notify.go`, `policies.go`, `preferences.go`.
- ✅ CI green on `web`: **Deploy API** runs `go test ./...` against Postgres then builds and ships the binary (health-checked after restart); **Build APK** runs `flutter pub get`, `flutter test`, builds the APK (last runs: 2026-09-12, all success).

Verified by code reading + GitHub Actions results. The app was **not run in this environment** (no Go/Flutter toolchain here).

## Tech stack

| Layer | Tech |
|---|---|
| Frontend | Flutter 3 (Dart), web (WASM) via Vercel + Android APK via CI |
| Backend | Go 1.25, stdlib `net/http` mux (no framework), `pgx` |
| Database | PostgreSQL 16 (schema self-applies on boot, seeds policies/admin) |
| Images | Cloudinary |
| Email | Resend (sign-in codes; falls back to logging codes) |
| Push | Firebase Cloud Messaging + Web Push |
| Deploy | Hetzner box (API binary + systemd), Vercel (web app), Cloudflare tunnel |

## How to run

From the repo's own docs (`dev.sh`, `backend/README.md`) — **not executed in this environment** (needs Docker + Flutter):

```sh
./dev.sh              # from repo root: Postgres + API + app in Chrome
./dev.sh macos        # any flutter device id
PUBLIC=1 ./dev.sh     # app talks to the live API instead of localhost
PORT=8081 ./dev.sh    # if 8080 is taken
```

Backend by hand:

```sh
docker run -d --name lamazon-pg \
  -e POSTGRES_USER=lamazon -e POSTGRES_PASSWORD=lamazon -e POSTGRES_DB=lamazon \
  -p 5433:5432 postgres:16-alpine

cd backend
go run .              # http://localhost:8080
go test ./...         # runs against DATABASE_URL, skips if no database
```

`DATABASE_URL` defaults to `postgres://lamazon:lamazon@localhost:5433/lamazon?sslmode=disable`. Set `ADMIN_USER`/`ADMIN_PASSWORD`, `RESEND_API_KEY`, `CLOUDINARY_*` and FCM credentials via `.env` (gitignored) for full functionality.

## Screenshots

No UI screenshots are checked into the repo. The banner at the top is the only visual.

## What you can add more

Honest open items from the repo's own `FIX_TRACKER.md` (Sep 2026 QA):

- [ ] Cross-device cart/wishlist sync — currently survives restart, not devices.
- [ ] Real policy/legal documents — templates are guarded from public view until the owner supplies content.
- [ ] Notification history — fabricated notifications were removed; a real history view is unimplemented.
- [ ] Promotion engine — the unwired promo field was removed; no engine exists yet.
- [ ] GPS tracking + delivery ETA — order statuses refresh, tracking is open.
- [ ] Merge the `codex/functionality-checkout` work — draft PR #1 targets `web`; only batches 1–2 are deployed.

## Project structure

```
frontend/                      # Flutter app (web + Android + iOS/desktop shells)
  lib/main.dart                # app entry + theme
  lib/screens/                 # 28 screens: home, search, details, cart, orders,
                               #   seller dashboard, admin, delivery, settings…
  lib/data/                    # API client, cart, session, geo, push, money…
  lib/models/                  # Product / Category models
  assets/                      # logo, category art, fonts
  test/                        # 35 widget/unit test files
  tool/prune_fonts.py          # trims fonts for the Vercel web build
backend/                       # Go API (module github.com/Geltrax69/Lamazon/backend)
  main.go                      # boot: DB, seeds, mail/push/cloud, routes, server
  catalog.go / categories.go / campaigns.go / compare.go   # storefront
  auth.go / login_limit.go     # sign-in codes, passwords, rate limits
  orders.go                    # cart checkout + order lifecycle
  *_test.go                    # 19 test files (run in CI against Postgres)
  schema embedded via go:embed
dev.sh                         # whole stack: Postgres (Docker) + API + Flutter
deploy.sh / tunnel.sh          # release helpers
vercel.json                    # Flutter web build + /app routing
DESIGN.md / QA_REPORT.md / FIX_TRACKER.md   # design, pre-launch QA, fix tracker
.github/workflows/
  deploy-api.yml               # go test → build → ship to Hetzner → health check
  build-apk.yml                # flutter test → release APK on every push
```

---
*README written after code audit on 2026-10-08.*
