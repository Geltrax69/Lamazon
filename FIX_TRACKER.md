# Functionality fix tracker

Source: [QA_REPORT.md](QA_REPORT.md), 9 September 2026.

Work order: functionality and data integrity first. Visual redesign, styling,
category imagery and other presentation changes wait for the user's instruction.
Only verified batches are committed and pushed to GitHub. The `web` branch
triggers the existing API/web deployment pipelines; a push is not proof of a
successful deployment.

## Current status

Latest functionality work is on `codex/functionality-checkout`, draft PR
[#1](https://github.com/Geltrax69/Lamazon/pull/1) targeting `web`. Only batches 1–2
are deployed; later batches need coordinated API, web and mobile rollout.

| QA IDs | Status | Result / remaining work |
|---|---|---|
| B1 | Fixed; rollout pending | Atomic basket checkout, one delivery fee, matching totals and durable retry IDs. |
| B2 | Fixed locally | Cart and wishlist survive restart. Cross-device synchronization remains open. |
| B3 | Code fixed; staffing pending | All checkout routes refuse new orders without active riders. Actual rider staffing is operational work. |
| B4 | Code fixed; owner content needed | Unfinished policy templates cannot be published or shown publicly. Real business/legal documents remain a launch requirement. |
| B5 | Fixed | Fabricated notifications removed; real notification history remains unimplemented. |
| B6 | Fixed | Persistent password/PIN rate limits with concurrent-request coverage. Proxy-aware network limiting needs infrastructure review. |
| B7 | Partial | New/reset PINs are six digits; unassigned rider pool hides recipient details. Existing short PINs still require admin reset. |
| B8 | Fixed | Wrong delivery code preserves rider login and allows retry. |
| B9 | Fixed by removing dead control | Unwired promo field removed; promotion engine remains unimplemented. |
| B10–B11 | Fixed | Server-persisted notification preferences and functional policy links. |
| B12 | Partial | Fake support contacts removed. Working contact details must come from the owner. |
| B13–B14 | Core actions fixed | Buyer cancellation before acceptance, order details and status refresh. GPS tracking and ETA remain open. |
| B15–B17 | Fixed | Optimized image delivery, visible detail-page cart feedback, dead cart control removed. |
| B18, B20, B32 | Deferred by request | Visual design, icons and imagery. |
| B19, B21–B22 | Fixed | Department navigation, clearable search scope and accurate drawer empty state. |
| B23–B26, B29 | Fixed | Server validation, product photo requirements and persistent address defaults. Product edits retain an omitted category. |
| B27 | Fixed | Consistent delivered revenue and visible admin order amounts. |
| B28, B33 | Content pending | Live test-product cleanup and catalogue corrections need the intended records/content confirmed; no production data changed. |
| B30–B31, B34–B37 | Fixed | Honest OTA/version display, form guidance, pluralization, location dismissal and address editing. |
| B38 | Verified existing behavior | Switch-off and permanent removal are distinct and describe retained history. |

## Remaining functionality queue

- Coordinate rollout for older installed clients. Historical order accounting
  is not rewritten.
- Real support/policy content, existing rider PIN resets and delivery staffing.
- Payment processing, receipts, reviews, notification history and promotions.
  These features are not implemented merely by removing their misleading controls.
- Cross-device cart/wishlist sync, grouped order presentation, GPS tracking/ETA,
  product stock display and preservation of selected product options in orders.
- Admin search/filter/date range/pagination/export, bulk/user actions, audit log,
  additional admin identities and MFA; seller store closure; offline indication.
- UI redesign remains deferred until the user requests it.

## Verification and GitHub history

- Created an isolated local PostgreSQL container, `lamazon-functional-qa`, on
  loopback port 55433, database `lamazon_test`. Tests never target production.
- Batch 1: all 60 Flutter tests pass (including four new persistence tests).
- Full Go suite passes against isolated PostgreSQL, including wrong-code retry.
- Flutter analysis: no errors/warnings; two pre-existing style infos in
  `session.dart` and `notify_banner.dart`.
- Batch 1 pushed: B2, B5, B8, B11.

### Batch 1 — `3c3a51a`

Pushed to `origin/web`. GitHub Actions **Deploy API succeeded** (run
34276373488). Vercel also reports a successful deployment for the later `9760655` batch.

### Batch 2 — `9760655` — authentication

Pushed to `origin/web`. Deploy API succeeded (run 34276608426).

Full Go suite passes with `-race`, including normalized account identifiers,
concurrent attempts from different addresses, expiry/recovery, restart survival,
spoofed forwarding headers and six-digit PIN generation. Deployment CI now starts
PostgreSQL so integration tests run rather than silently skipping for lack of a DB.

The network limit uses the direct peer address, not untrusted forwarding headers.
Behind a reverse proxy, its 100-attempt budget is shared by that proxy's users.
Per-account limits remain independent; trusted-proxy configuration needs a later
infrastructure review. No existing rider PINs were rotated automatically.

### Batch 3 — `03c25f4` — checkout accounting

Draft pull request: [#1](https://github.com/Geltrax69/Lamazon/pull/1),
branch `codex/functionality-checkout`, targeting `web`.

- New authenticated `POST /api/orders/checkout` submits all basket lines in one
  PostgreSQL transaction. Item locks use a stable order to avoid deadlocks.
- `amount` now includes `deliveryFee`. One ₹15 fee is assigned to the first item
  by sorted ID; remaining lines carry no additional fee. All collections sum to
  the basket total. Historical records retain their original totals and zero fee.
- Expected total is checked against server prices; mismatches roll back the
  complete basket. No client can choose or waive the fee.
- Cart removal uses submitted item IDs and quantities, not product-name prefixes.
  Failed baskets remain intact; successful removal is persisted even after leaving
  the screen.
- Verified: full Go race suite, all 60 Flutter tests, release web compilation
  and Android APK compilation. No new static-analysis findings.
  New integration tests check buyer/seller/rider totals, one delivery fee, missing
  items, stock shortages, duplicate lines, invalid quantities and stale prices.
- **Rollout requirement:** old single-line clients lack a confirmed total and
  receive an update/reload message. Deploy the new mobile and web builds alongside
  this API change. This batch is kept off the live deployment branch until that
  rollout is ready; earlier batches are already on `web`.
- Android build output: `frontend/build/app/outputs/flutter-apk/app-release.apk`.
  The existing Gradle release configuration uses debug signing. This is a local
  validation build, not a published app release; iOS build was not exercised.
- Published batches cover API/web deployment. Existing installed apps do not
  automatically receive these source changes through a push to `web`.
- Follow-up at that time: request idempotency (completed in batch 6), cross-device
  cart sync, grouped order presentation, and historic amount reconciliation. No production orders or catalogue records were changed by tests.

### Batch 4 — address integrity, validation and preferences

Implemented and verified on `codex/functionality-checkout` (PR #1):

- **B23/B24:** validate recipient/profile names, phone numbers, address lengths and
  optional pincodes on the API. Indian mobile numbers are normalized only after
  validation. Markup in plain-text fields and oversized values are rejected.
- **B29:** selected addresses now become the server default. Owner-scoped default
  selection, creation and deletion serialize against the user row, preventing
  concurrent saves from leaving multiple defaults.
- **B37:** address editing, recipient details and deletion confirmation. Failed
  saves/deletes no longer fabricate successful local changes. Form data remains
  available when the server refuses a save.
- **B25 (partial)/B26:** bounded product title/description, real category checks,
  price/MRP ceilings and currency precision, stock bounds, and generic server
  errors in seller handlers. Photo requirements remain open.
- **B10:** server-persisted notification preferences, partial updates without
  overwriting other flags, disabled controls until loaded, save errors and retry.
  Order-event emails/push and push delivery honor these flags. Marketing consent
  is saved separately; there is no active marketing sender. Removed the fake GPS
  toggle; location remains manual. Unsupported preferences are read-only.

Validation: 61 Flutter tests pass, including server-backed address/preferences
and failed-write regression coverage. Full PostgreSQL Go suite passes with race
checking, including concurrent defaults, ownership, edit, validation and actual
notification suppression. Two old smoke assertions were updated because they
expected the broken local-only settings/address behavior.

These changes are pushed for review with the checkout batch; they are not yet
on the production `web` branch. Business/support information has been requested
from the owner and remains needed for B4/B12.

### Batch 5 — order actions, honest controls and publication guards

Implemented and verified:

- **B3:** the atomic checkout endpoint refuses new baskets without active riders.
  Rider recruitment and sufficient coverage remain operational requirements.
- **B7:** unassigned rider-pool entries no longer disclose recipient names,
  numbers or addresses. Assigned/claimed deliveries retain the details needed.
- **B4 (code complete; content pending):** reject policy saves with template
  placeholders; expose original drafts only through an authenticated admin API.
  Public and offline policy views no longer render unfilled templates. Actual
  business/legal text is still needed from the owner.
- **B9:** removed the unwired promo field rather than accepting codes silently.
- **B12 (partial):** removed fake phone/email/chat channels and response-time
  promises. Support opens published contact information. Real contacts pending.
- **B13/B14:** order details refresh status and show address, total and delivery
  code. Buyers can cancel only their own orders before seller acceptance.
  Cancellation uses the existing rejected terminal state with the explicit
  reason `Cancelled by customer`; reservations are released atomically.
- **B15:** existing tile padding already had Cloudinary optimization. Extended
  optimization to full-bleed requests and allowed 1024px product detail sources.
- **B16/B17:** product-page confirmation uses its own ScaffoldMessenger; added
  working wishlist/cart actions there and removed the dead cart-header control.
- **B19/B21/B22:** leaf department browsing no longer nests a tile of itself;
  removable search scope and stale-response protection; drawer empty-copy fix.
- **B25/B26:** new listings require uploaded photos; last-photo deletion is
  refused. Requests have photo-count/body-size bounds. Real category and numeric
  validation applies before writing listings; test fixtures exercise multipart
  uploads with a stubbed Cloudinary service.
- **B27:** ranked-store/item revenue counts delivered receipts, matching totals;
  Orders placed now counts all orders consistently. Admin order cards show amounts.
- **B30/B31/B34/B35/B36:** hide unavailable OTA diagnostics, explain incomplete
  login/address inputs, fix product pluralization, source versions from bundled
  pubspec, and provide visible location-dialog dismissal.
- **Other controls:** Share copies the current web URL or native release link;
  About opens app information. Money formatting preserves paise across checkout,
  seller editing, buyer orders, rider collection and admin views.
- **B38 verification:** current code already distinguishes Switch off from
  permanent deletion and describes retained history; no further relabeling needed.

Validation: 66 Flutter tests pass; full Go suite passes with `-race -count=1`.
Regression tests cover product-page feedback, clearable search scope, version
loading, money precision, image transformations, cancellation ownership/cutoff,
no-rider checkout, policy guards and mandatory product photos.

The Docker test database developed an I/O error. It was not used to certify this
batch. A separate native PostgreSQL 16 test cluster is running at
`127.0.0.1:55434`, data directory `/tmp/lamazon-functional-pg`, database
`lamazon_test`. Explicit `LAMAZON_TEST_URL` failures now fail tests rather than
silently skipping integration coverage. Other Docker projects were left alone.

### Batch 6 — safe checkout retries and product-edit integrity

- Atomic checkout requires a request ID. PostgreSQL serializes concurrent requests
  for that buyer/ID and stores the resulting confirmation in the same transaction
  as the orders. Replays return those orders without reserving stock again or
  sending duplicate order notifications. Reusing an ID for a changed payload is
  rejected. Failed transactions do not consume the ID.
- Cart storage migrates to one `cart.v2` envelope holding the product snapshot and
  retry ID together. Quantity/product changes rotate the ID; retries and app
  restarts preserve it. Existing `cart.v1` baskets are migrated automatically.
- Checkout address reads use the existing transaction, avoiding connection-pool
  starvation when multiple requests wait for the same basket lock.
- Seller product edits preserve the existing category when omitted, instead of
  silently moving a listing into an empty category.
- Regression coverage: simultaneous identical requests with only one item in
  stock and a one-connection pool; recovery after address deletion/rider shutdown;
  different payload rejection; exactly one resulting order; persistent/migrated
  cart IDs; category preservation.

Validation: full PostgreSQL Go suite passes with `-race -count=1` (22.3 seconds),
all 66 Flutter tests pass, `flutter analyze` reports no issues, and release web
and Android APK builds succeed. Android output is a local validation APK using
the repository's existing signing configuration; no app-store release or iOS
verification is claimed. Batch is pushed on the PR branch, not deployed to `web`.

### Batch 7 — delivery availability on every checkout route

The shared checkout transaction now checks rider availability for both the atomic
basket endpoint and legacy buyer/seller single-line routes. A confirmed total no
longer lets an older client bypass the no-rider guard. Existing committed basket
retries still recover their confirmation when riders have since switched off.

Tests cover all three entry points with zero active riders. Existing fulfilment
fixtures now explicitly onboard riders before checkout; the switch-off test places
an order while a rider is active, then verifies acceptance after that rider goes
inactive does not assign them work. Delivery, notifications and ownership behavior
remain covered by the complete PostgreSQL race suite.

Verified: full Go suite passes with `-race -count=1` against isolated PostgreSQL
(22.5 seconds). This backend-only follow-up does not change the frontend source
used for batch 6's passing tests, analysis and release builds.
