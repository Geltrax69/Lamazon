# Lamazon API

Go 1.22+ stdlib only — `net/http` pattern routing, no framework, no database.
State lives in memory behind a mutex, seeded from the same catalog the Flutter
app ships, so both sides agree on prices and stores.

```bash
go run ./...          # listens on :8080, or $PORT
go test ./...
```

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
| GET/POST | `/api/seller/items` | inventory + summary / add a line |
| PATCH | `/api/seller/items/{id}/stock` | `{"delta"}` or `{"stock"}`, floors at 0 |
| DELETE | `/api/seller/items/{id}` | remove a line |
| GET/POST | `/api/seller/orders` | orders + stage counts / place one |
| POST | `/api/seller/orders/{id}/accept` | reserve |
| POST | `/api/seller/orders/{id}/deliver` | hand over — this is what decrements stock |

## Rules worth knowing

- Accepting an order reserves it; **delivering** is what removes units from stock.
- Stock floors at zero; a delivery can never drive it negative.
- Delivering twice returns 409 rather than double-decrementing.
- A store outside the serviceable area is refused at creation.

## Not built yet

No persistence, no auth tokens, no payments. The handlers do not care where
the data comes from — swap the maps in `store.go` for a database and they stay
as they are.
