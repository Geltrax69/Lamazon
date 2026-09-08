# Functionality fix tracker

Source: [QA_REPORT.md](QA_REPORT.md), 9 September 2026.

Work order: functionality and data integrity first. Visual redesign, styling,
category imagery and other presentation changes wait for the user's instruction.
Only verified batches are committed and pushed to GitHub. The `web` branch
triggers the existing API/web deployment pipelines; a push is not proof of a
successful deployment.

## Current batch

| QA ID | Status | Change / remaining work |
|---|---|---|
| B1 | Investigating | Delivery fee must be recorded once per basket, with consistent customer/seller/rider totals. Existing checkout creates independent requests per line. |
| B2 | Verified | Restore cart product snapshots, quantities and wishlist IDs before startup; save mutations in order. Guest selections survive sign-in. Device-local storage; cross-device sync remains future work. |
| B5 | Verified | Removed fabricated order/payment/promotion notifications; use the existing empty state until a real history API exists. |
| B8 | Verified | Incorrect delivery codes return 400, preserving rider authentication. Existing delivery test verifies retry with the same token and unchanged stock. |
| B11 | Verified | Settings Privacy and Terms open the existing policy screens. |

| B6 | Verified | Database-backed limits: 10 attempts per account and 100 per network peer per 15 minutes, with HTTP 429 and Retry-After. Counts are atomic and survive restarts. |
| B7 | Partially fixed | New and reset rider PINs have six digits. Existing credentials retained until admin resets them. |

## Queue

- B7 remaining: existing four-digit credentials require an admin PIN reset;
  broader access to customer details in the unassigned rider pool still needs review.
- B3: delivery availability guard; actual rider recruitment/onboarding is operational work.
- B4: prevent publication of unfinished policies. Real business/legal/support details must come from the owner; do not invent them.
- B9–B10, B12–B14: nonfunctional promo/support/settings and order actions.
- B23–B26, B29: server-side validation and delivery-address consistency.
- B15, B16–B17, B19, B21–B22, B27, B30, B34–B35: performance and remaining behavior defects.
- B18, B20, B28, B32–B33: imagery/catalogue content and appearance deferred; live catalogue edits need identified intended content.
- B31, B36–B38 and missing features: assess functionality separately from the deferred visual pass.

## Verification and GitHub history

- Created an isolated local PostgreSQL container, `lamazon-functional-qa`, on
  loopback port 55433, database `lamazon_test`. Tests never target production.
- Batch 1: all 60 Flutter tests pass (including four new persistence tests).
- Full Go suite passes against isolated PostgreSQL, including wrong-code retry.
- Flutter analysis: no errors/warnings; two pre-existing style infos in
  `session.dart` and `notify_banner.dart`.
- Batch 1 ready for GitHub: B2, B5, B8, B11. Deployment status tracked separately.

### Batch 1 — `3c3a51a`

Pushed to `origin/web`. GitHub Actions **Deploy API succeeded** (run
34276373488). Frontend hosting status has not yet been verified.

### Batch 2 — authentication

Full Go suite passes with `-race`, including normalized account identifiers,
concurrent attempts from different addresses, expiry/recovery, restart survival,
spoofed forwarding headers and six-digit PIN generation. Deployment CI now starts
PostgreSQL so integration tests run rather than silently skipping for lack of a DB.

The network limit uses the direct peer address, not untrusted forwarding headers.
Behind a reverse proxy, its 100-attempt budget is shared by that proxy's users.
Per-account limits remain independent; trusted-proxy configuration needs a later
infrastructure review. No existing rider PINs were rotated automatically.
