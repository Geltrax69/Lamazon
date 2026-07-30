# Lamazon API

Go 1.22+ stdlib routing (`net/http`, no framework) over **PostgreSQL**, via
pgx. The schema applies itself on boot and the catalog seeds once, so a fresh
database is ready without any manual step.

## Running everything

```bash
./dev.sh              # from the repo root: Postgres + API + the app in Chrome
./dev.sh macos        # any flutter device id
PORT=8081 ./dev.sh    # if 8080 is taken
```

It starts (or reuses) the Postgres container, waits for it, builds and starts
the API, blocks until `/api/health` answers, and only then launches Flutter with
`API_BASE_URL` pointed at it — so the app never opens onto a backend that is
still compiling. Quitting Flutter stops the API; Postgres stays up for next time.

## Running the pieces by hand

```bash
docker run -d --name lamazon-pg \
  -e POSTGRES_USER=lamazon -e POSTGRES_PASSWORD=lamazon -e POSTGRES_DB=lamazon \
  -p 5433:5432 postgres:16-alpine

go run .              # http://localhost:8080
go test ./...         # runs against DATABASE_URL, skips if no database
```

`DATABASE_URL` defaults to
`postgres://lamazon:lamazon@localhost:5433/lamazon?sslmode=disable`.

## Calling it from Flutter

The app reads `API_BASE_URL`, defaulting to `http://localhost:8080`:

```bash
cd ../frontend
flutter run -d chrome                                   # localhost
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080   # phone on wifi
```

`loadCatalog()` and `loadShops()` call the API and fall back to the bundled
sample data when it is unreachable, so the app still runs with the backend
down — and so widget tests do not need a server.

## Photos

Uploads go to **Cloudinary**; Postgres keeps the URLs (`seller_stores.photo_url`,
`inventory_items.image_urls`). Credentials come from the environment —
`CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, kept in
the gitignored `.env` at the repo root and loaded by `dev.sh`. Unset, the API
still runs and the two upload routes answer 503.

Everything lands under one folder per store:

```
Lamazon/
  Campus_Snacks/
    store_image
    Campus_Snacks_Cold_Coffee_300ml_1
    Campus_Snacks_Cold_Coffee_300ml_2
```

Non-alphanumeric characters in a store or item name become `_`, so a name
cannot invent a folder. Re-uploading a store photo overwrites `store_image`;
item photos append and keep counting from what the item already has.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | liveness |
| GET | `/api/products` | catalog; `?tab=`, `?category=`, `?q=` stack |
| GET | `/api/products/{id}` | one product |
| GET | `/api/shops` | shops; `?tab=` |
| GET | `/api/shops/{name}/products` | a shop's own listings **plus** items it stocks, at its price |
| GET | `/api/locations` | where delivery runs |
| GET | `/api/locations/check?city=` | serviceability; accepts `LPU`, `lpu, phagwara`, any casing |
| POST | `/api/login` | `{"email"}` — validates format, no password yet |
| GET | `/api/seller/categories` | categories a seller can list under |
| POST/GET | `/api/seller/store` | open / read the seller's store |
| POST | `/api/seller/store/photo` | multipart `file` — store cover, to Cloudinary |
| GET/POST | `/api/seller/items` | inventory + summary / add a line |
| PATCH | `/api/seller/items/{id}/stock` | `{"delta"}` or `{"stock"}`, floors at 0 |
| POST | `/api/seller/items/{id}/photos` | multipart `file` (repeatable) — product photos |
| DELETE | `/api/seller/items/{id}` | remove a line |
| GET/POST | `/api/seller/orders` | orders + stage counts / place one |
| POST | `/api/seller/orders/{id}/accept` | reserve |
| POST | `/api/seller/orders/{id}/deliver` | hand over — this is what decrements stock |

## Rules worth knowing

- Accepting an order reserves it; **delivering** is what removes units from stock.
- Stock floors at zero; a delivery can never drive it negative.
- Delivering twice returns 409 rather than double-decrementing.
- A store outside the serviceable area is refused at creation.

## Where the rules live

Some invariants sit in the schema rather than in Go, so no code path can get
around them:

- `inventory_items.stock` has `CHECK (stock >= 0)`; updates use `GREATEST(..., 0)`
- `inventory_items.owner` is a foreign key to `seller_stores`, which is what
  makes "no stock without a store" a 409 instead of an orphan row
- `orders.stage` is constrained to the three known stages
- Delivering runs the order update and the stock decrement in one transaction

## Not built yet

No auth tokens, no payments. The seller is identified by `X-User-Email` or
`?owner=`, defaulting to a demo account, until the app sends a real session.
