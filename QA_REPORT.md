# Lamazon — Pre-Launch QA Report

**Date:** 9 September 2026
**Build under test:** `web` branch, commit `5ab6083`
**Environment:** locally-built Flutter web app pointed at the live production API (`https://api.geltrax.engineer`)
**Roles exercised:** guest, shopper (`lalit@lamazon.in`), seller, admin (`/admin/log_IN`), delivery rider (`/delivery`)

## Test data created and cleaned up

| Artefact | Final state |
|---|---|
| `ORDER-3` (1 × Aloo Tikki Burger, ₹84 charged / ₹69 recorded) | **Still open** on PURE BITES — cancel from the shop side if unwanted |
| `ORDER-1` (stale since 16 Aug) | Completed as delivered during the rider test |
| Test address (`Room 1`, junk name/phone) | Deleted |
| `QA TEST STORE do not approve` | Created → approved → **rejected** (not shopper-visible) |
| `item-43` (500-char title test product) | Deleted |
| Rider `9999900001` "QA Rider" | Deactivated (soft-deleted; still listed as inactive) |

Catalogue back to 42 products, public shops back to 2.

---

# Executive Summary

Lamazon looks far more finished than it is. The visual design is genuinely good — consistent, calm, well-spaced, with real empty states and loading states in the right places. Underneath, a large share of the interface is scenery: a promo-code box that isn't wired to anything, a notifications screen of invented orders and payments, a settings screen whose toggles forget everything, three support channels that all answer "coming soon", and five live legal documents still containing `[Date]` and `[Company Name]`.

The core loop (browse → cart → order → shop accepts → rider delivers) does work — it was run end to end. But it only works if a rider exists, and **production has zero riders**, which is why a real order sat at "Accepted — being prepared" for 22 days.

| Dimension | Score |
|---|---|
| Functionality | 5/10 |
| UX | 5/10 |
| UI | 7/10 |
| Reliability | 4/10 |
| Accessibility | 2/10 |
| Performance | 3/10 |
| Security posture | 3/10 |
| Production readiness | 3/10 |

**Overall: 4/10**

### Would you ship this application to real users today?

**NO.** Three reasons, each independently disqualifying:

1. The customer is charged ₹84 at checkout and the order, the shop and the rider all record ₹69 — the delivery fee exists only in the cart UI.
2. The cart empties on page refresh, because it is never persisted anywhere.
3. The live Terms, Privacy, Shipping, Refunds and Contact pages that the signup screen makes users agree to still contain unfilled template placeholders, including the grievance-officer fields Indian e-commerce rules require.

Add zero riders on the platform and the app cannot complete an order today even when everything else behaves.

---

# Critical Problems

### 1. Money mismatch: the ₹15 delivery fee is charged but never recorded

Cart says "Place order · ₹84". `GET /api/orders` returns `amount: 69`. My Orders shows ₹69. The rider screen shows ₹69. `handlePlaceOrder` writes `price*units` and nothing else (`backend/orders.go:121`); `shipping` is a client-only getter (`frontend/lib/data/cart.dart:24`). A cash-on-delivery rider will collect ₹69 for an ₹84 order, every time.

### 2. Cart and wishlist do not survive a refresh

`Cart` and `Wishlist` are in-memory `ChangeNotifier`s. `localStorage` after a session contains only 4 session keys — nothing for cart or wishlist. Adding an item to the wishlist and reloading leaves the heart empty. On a web store this is a P0-class conversion bug.

### 3. Zero riders exist, so nothing can be delivered

Admin → Delivery: "No delivery numbers yet", Riders = 0. `ORDER-1` had been stuck at `accepted` since 16 Aug. The admin Orders tab even explains riders are auto-assigned, with no warning that there are none.

### 4. Live legal documents contain unfilled placeholders

All five are flagged "has blanks to fill in" in the admin, and they are shopper-visible. Extracted from `/api/policies`:

| Policy | Unfilled placeholders |
|---|---|
| terms | `[Company Name]`, `[Date]`, `[Registered Business Address]` |
| privacy | `[Date]`, `[support@email.com]` |
| shipping | `[Date]` |
| refunds | `[Date]` |
| contact | `[Company Name]`, `[Date]`, `[Days and Time]`, `[Name]`, `[Phone Number]`, `[Registered Business Address]`, `[grievance@email.com]`, `[support@email.com]` |

The login screen says "By continuing, you agree to our Terms and Conditions".

### 5. Fabricated notification history shown to real users

`screens/notifications_screen.dart` hardcodes: "Order out for delivery — #LMZ-2481", "Payment successful — ₹1,299 paid for order #LMZ-2475", "40% off at Velora Store", "Rate your last order — Tell us how Spice Kitchen did." None of those orders, payments or stores exist. Telling a user a payment succeeded is not a harmless placeholder.

### 6. No rate limiting on any password/PIN endpoint

12 rapid wrong passwords → 12 × 401, no throttle, no lockout, no captcha, on all three of `/api/admin/login`, `/api/login/password`, `/api/delivery/login`. Rider auth is a phone number plus a **4-digit PIN** (10,000 combinations) and grants a stranger every customer's name, phone number and delivery address. `Access-Control-Allow-Origin: *` means this is reachable from any page.

The emailed-code path *does* have a cooldown and a 5-attempt cap — it is only the password/PIN paths that are open.

### 7. A wrong delivery code signs the rider out

`explainFailedDelivery` returns **401** for a wrong code (`backend/staff.go:1216`), and `_staffCall` treats any 401 as a dead token and calls `staff.signOut()` (`frontend/lib/data/api.dart:553`). Reproduced: mistyped one digit → correct error message → immediately back at the delivery sign-in screen, mid-run. Fix is one line: return 400/422, not 401.

---

# Complete Bug List

| ID | Sev | Category | Page/Feature | Problem | Impact |
|---|---|---|---|---|---|
| B1 | P0 | Data/Logic | Cart → Orders | ₹15 delivery fee charged in UI, never persisted (`amount` = price×units) | Customer, shop and rider see three different totals; cash collected is wrong |
| B2 | P0 | Bug | Cart / Wishlist | In-memory only; cleared by refresh | Lost carts, lost sales |
| B3 | P0 | Product/Ops | Admin → Delivery | 0 riders on the platform | Orders can be accepted but never delivered |
| B4 | P0 | Legal | Policies (all 5) | Live documents contain `[Date]`, `[Company Name]`, `[grievance@email.com]` etc. | Users consent to unfinished templates; regulatory exposure |
| B5 | P1 | Bug | Notifications | Entirely hardcoded fake orders/payments/stores | Fabricated financial info shown as the user's own |
| B6 | P1 | Security | admin/shopper/rider login | No rate limit or lockout on any password/PIN endpoint | Unlimited online brute force |
| B7 | P1 | Security | Delivery panel | 4-digit PIN + phone unlocks all customer PII | Trivially guessable access to names, phones, addresses |
| B8 | P1 | Bug | Delivery → "Delivered" | Wrong code returns 401 → client signs the rider out | Rider loses session mid-delivery on a typo |
| B9 | P1 | Dead UI | Cart → Promo code | Field + "Apply" are a `TextField` and a `Container`; no handler at all | Users type codes that silently do nothing |
| B10 | P1 | Bug | Settings | All 4 toggles in-memory (`settings_screen.dart:22-26`); never sent to server | "Email offers: off" is a lie; opt-out doesn't work |
| B11 | P1 | Dead UI | Settings → Privacy/Terms | Show "— coming soon" although real policies exist elsewhere in the app | Legal docs unreachable from the place users look |
| B12 | P1 | Dead UI | Help & Support | Chat, Call (`1800-000-1234`), Email (`help@lamazon.app`) all "coming soon" | A customer with a problem has no working channel |
| B13 | P1 | UX/Copy | Help → FAQ | "You can cancel free of charge until the store accepts it" — no cancel control exists anywhere | Promised behaviour is impossible |
| B14 | P1 | UX/Copy | Help → FAQ | "tap an order to see live status" — orders list has no `onTap` at all | Dead-end instruction |
| B15 | P1 | Perf | Home / search | Catalogue images are unoptimised originals: 1.01 MB, 2.55 MB, 2.68 MB PNGs for ~140px thumbnails | Multi-MB home page; slow on campus mobile data |
| B16 | P2 | Bug | Product detail | "Added to Basket" toast never renders on the PDP; it appears on the previous screen after you go back | Add-to-cart looks like it did nothing |
| B17 | P2 | Dead UI | Cart header | Top-right cart icon is `const _RoundIcon(...)` with no `onTap` | Button that does nothing |
| B18 | P2 | Data | Categories | Snacks & Drinks uses the *headphones* icon; Stationery & Games uses the *paintbrush* icon | Wrong iconography on home, drawer and admin |
| B19 | P2 | Bug | Home → Gifts | Department with no children renders a tile of itself | Tapping "Gifts" inside "Gifts" |
| B20 | P2 | Content | Categories | 33 of 57 subcategories have no image (Beauty, Household, Grocery, Snacks, Stationery: 0/33) | Large grey placeholder grids on the home page |
| B21 | P2 | UX | Search from a category tile | Silently scoped to the department, no chip, no clear | Searching "burger" from Stationery returns "No products found" |
| B22 | P2 | Bug | Menu drawer | "Categories appear here once the catalogue loads." shown *below* a fully loaded category list | Contradictory copy |
| B23 | P2 | Validation | Add address | Phone only needs length ≥ 10; `abcdefghijabc12` accepted and stored | Rider can't call the customer |
| B24 | P2 | Validation | API `/api/addresses` | 229-char name with `<script>` tags stored unvalidated (emails *are* escaped, so no XSS) | No server-side input limits |
| B25 | P2 | Validation | API `/api/seller/items` | 500-char titles accepted; non-existent category `NotARealCategory` accepted; photo-less items accepted although the UI mandates a photo | Unbrowsable/broken listings; client and server disagree |
| B26 | P2 | Bug | API `/api/seller/items` | Large price returns raw `ERROR: numeric field overflow (SQLSTATE 22003)` | DB error text surfaced to sellers |
| B27 | P2 | Data | Admin → Insights | `topStores.revenue` = ₹138 while `totals.revenue` = ₹69 on the same screen; header "Orders 3" vs "Orders placed 2" | Same word, two meanings, no way to tell which is right |
| B28 | P2 | Content | Live catalogue | `item-42` "cake", ₹799, filed under **Breads**, photo is a screenshot of an image viewer with visible ✕ and thumbnail strip | Junk test data on the shop's front page |
| B29 | P2 | Data | Address book | UI badges the new address "DELIVERING HERE" while the API reports `isDefault: false` on it | Client and server disagree on delivery target |
| B30 | P3 | Bug | Home footer | "dev build — no OTA" is shown to every web user (Shorebird is never available on web) | Developer diagnostics in a consumer UI |
| B31 | P3 | UX | Login, Add address | Primary button is disabled with no explanation of what's missing | Silent dead-end; the seller form does this correctly |
| B32 | P3 | UI | Profile footer | Logo asset is white text on a grey box; sub-tagline is illegible | Looks broken |
| B33 | P3 | Content | Catalogue | "Aloo **Chesse** Burger", "Double **Chesse** burger", "Mac & **Chesse**", "Aloo **TIkki**" | Sloppy storefront |
| B34 | P3 | Bug | Admin → Approved | "1 products" | Plural bug |
| B35 | P3 | Consistency | Version strings | Home badge "v1.0.1", Settings "1.0.0", Help "v1.0.0" | Three sources, two answers |
| B36 | P3 | UX | Guest first run | Blocking location modal with no visible dismiss (Escape works, nothing says so) | Hard gate on the very first screen |
| B37 | P3 | UX | Address book | No edit; delete is instant with no confirm or undo; recipient name/phone never shown | Two "Home" rows are indistinguishable |
| B38 | P3 | UX | Admin → Riders | "Remove" is a soft delete; the rider stays listed as inactive | Label doesn't match behaviour (history preservation is reasonable — the word isn't) |

## OBSERVED — needs developer verification

- Admin offers "Assign rider" on an order still in `received` (shop hasn't accepted it) — unclear whether the backend permits assignment before acceptance.
- A newly created product rendered without an add-to-cart button while neighbouring cards had one; the product was deleted before the cause was isolated.
- `Access-Control-Allow-Origin: *` on the whole API. Low risk today because auth is bearer-token, not cookie — but it widens every endpoint above to any origin.
- Session token **and** refresh token are stored in `localStorage`. Standard for SPAs; worth a conscious decision rather than a default.

---

# Missing Features

- **Payment. There is none at all.** No method selection, no COD confirmation, no receipt — yet the Refunds policy promises money back "to the original payment method".
- **Order cancellation** (promised in the FAQ), **order detail page**, **live tracking**, **ETA**.
- **Ratings and reviews.** "Rate your last order" appears in the fake notification list; the feature doesn't exist.
- **Cart/wishlist persistence and server-side sync.**
- **Address editing.** Only create and delete.
- **Stock/availability on the product page.** Stock is enforced server-side but never shown.
- **Admin:** search, filters, date ranges, pagination, CSV export, order amounts, bulk actions, any action on a user (suspend/reset/delete), audit log, a second admin account, MFA.
- **Seller:** no way to close or delete a store — store creation is irreversible from the UI.
- **Multi-item orders.** A 3-line cart becomes 3 independent orders, non-atomically; partial failure leaves some placed.
- **Offline state.** There is an offline fallback in search but no offline indicator anywhere.

---

# UX Problems

### Add to Cart gives no feedback where you're standing
**Experience:** tapping "Add to Cart" four times produced no visible change.
**Problem:** the only confirmation is a `SnackBar` rendered on the parent scaffold, so it appears on the *search* screen after pressing back. There is also no cart badge or cart link on the PDP, so you cannot check.
**Fix:** show the toast on the detail scaffold and put a cart entry point in the PDP header.

### Search silently inherits a department scope
**Experience:** tapping a Stationery subcategory then typing "burger" returns "No products found" — with four burgers in the catalogue.
**Problem:** `SearchScreen.tab` is invisible in the UI.
**Fix:** show a removable scope chip ("in Stationery & Games ✕") and offer "search all departments" on a zero-result page.

### Disabled buttons that won't say why
Login "Continue" and address "Check availability" grey out silently. The seller onboarding screen already solves this — it prints "Add your business name" under the button. Use that pattern everywhere.

### No delivery address on the checkout screen
The cart shows a promo box and totals but never where the order is going. It quietly picks the selected-or-first address. Show it, with a change link.

### No order confirmation
Placing an order drops you into a list with a 4-second snackbar. No confirmation screen, no order number call-out, no ETA.

### Empty states have no exit
"No products found" and "Nothing saved yet" offer no CTA. The empty cart does it right ("Start shopping") — copy that.

### Bottom nav is inconsistent
Labelled pill with an active state on home; unlabelled and with no active state on search and category screens.

---

# Admin Panel Findings

Genuinely the strongest part of the product. It is desktop-usable (the shop is phone-shaped everywhere), and destructive actions are handled thoughtfully — rejecting a store *requires* a reason the seller will read, deleting a category confirms and the server refuses if stock is still filed under it, and a rider's PIN is shown exactly once and never stored readably.

**Consistency verified in both directions:**

- Admin approve → the store appeared in public `/api/shops` immediately.
- A rider added via admin appeared in the panel's own counters on refresh.
- A delivery completed by the rider moved `totals.delivered` to 1 and `revenue` to ₹69.
- A product deleted → catalogue returned to 42 immediately.

**What is wrong with it:**

- **Read-only where it matters.** The People tab lists 4 users and offers zero actions — no suspend, no reset, no delete, no export, no search.
- **No order amounts anywhere** in the Orders tab. An admin cannot see what an order was worth.
- **No filters, no search, no date range, no pagination** on any list. Fine at 3 orders, unusable at 300.
- **Insights are all-time only**, with the revenue contradiction in B27, and no export.
- **`_approve` has no confirmation** while `_reject` does — the asymmetric one is the one that puts a store in front of customers.
- **The tab strip overflows** with no scroll affordance; four of ten tabs are off-screen at 1000px.
- **A single shared admin credential** from `ADMIN_USER`/`ADMIN_PASSWORD`, 12-hour session, no MFA, no per-admin accounts, no audit trail of who approved or rejected what.
- Data quality visible from here: a user named `jyotiiiiiiiiiiiiii`, another named `Lalit Singh [10lalitsingh01@gmail.com]`. No name validation anywhere.

---

# User Journey Results

| Journey | Result | Where it failed | Severity |
|---|---|---|---|
| A. New visitor → browse → understand the product | Partial | Blocking location modal with no visible dismiss; 5 of 8 departments are grey placeholder grids | P3 |
| B. Sign in with password → browse → add to cart → order | Partial | Works, but ₹84 charged / ₹69 recorded; no address shown; no payment step; no confirmation screen | P0 |
| C. Refresh the page mid-shop | **Fail** | Cart and wishlist wiped; session survives | P0 |
| D. Apply a promo code | **Fail** | Field and Apply button are decoration | P1 |
| E. Change notification preferences | **Fail** | Toggles reset on navigation, never reach the server | P1 |
| F. Get help with an order | **Fail** | Chat/Call/Email all "coming soon"; FAQ promises a cancel button that doesn't exist | P1 |
| G. Read the terms you just agreed to | Partial | Reachable from login/Help, but contain `[Date]`/`[Company Name]`; the Settings links say "coming soon" | P0 |
| H. Open a store → add stock → sell | Partial | Onboarding and approval work well; empty state says "add your first one" while the button is hidden until approval; no way to close a store afterwards | P2 |
| I. Admin approves a store → shopper sees it | **Pass** | — | — |
| J. Admin adds a rider → rider signs in → picks up → delivers | Partial | Full flow works, but one mistyped delivery code logs the rider out | P1 |
| K. Admin deletes a product → it disappears for shoppers | **Pass** | — | — |
| L. Order reaches the customer without staff intervention | **Fail** | Zero riders exist in production | P0 |

---

# Security Findings

*Non-destructive checks only. No exploitation was attempted.*

1. **No rate limiting on password or PIN authentication** — CONFIRMED. 12 rapid failures on each of `/api/admin/login`, `/api/login/password`, `/api/delivery/login`; all plain 401s. The emailed-code path *does* enforce a resend cooldown and a 5-attempt cap; the password paths never got the same treatment.
2. **4-digit rider PIN protecting customer PII** — CONFIRMED. Phone number + 4 digits, unlimited guesses, and a signed-in rider sees every unassigned order's customer name, phone and address before picking anything up.
3. **Single shared admin account, 12-hour token, no MFA, no audit trail** — CONFIRMED. Every admin action is attributable to "the admin".
4. **No server-side input validation on user-supplied strings** — CONFIRMED. 229-char names, letters as phone numbers, 500-char product titles, non-existent categories. Emails *are* HTML-escaped (`html.EscapeString` in `email_template.go`), so this is a data-integrity problem rather than an injection one — but the limits belong on the server.
5. **Raw database errors returned to clients** — CONFIRMED. `ERROR: numeric field overflow (SQLSTATE 22003)`. Wrap DB errors before they leave the process.
6. **`Access-Control-Allow-Origin: *` on the whole API** — potential issue, requires developer verification. Low impact with bearer-token auth; it does mean every endpoint above is callable from any web page.
7. **Tokens in `localStorage`** — potential issue, requires developer verification. Conventional for SPAs; worth confirming it is deliberate given the refresh token sits there too.

**Correctly handled, and worth saying:** passwords are hashed and compared safely; order placement locks the item row `FOR UPDATE` and counts live reservations so stock cannot oversell; the delivery-code check is a single conditional `UPDATE` that also prevents a rider closing someone else's order; the `SKIP_LOGIN_CODE` dev shortcut is gated on loopback *and* the flag; delivery addresses are copied onto the order so editing the address book cannot redirect a bag already out.

---

# Performance Findings

- **Catalogue images are unoptimised Cloudinary originals.** Measured: 2.68 MB, 2.55 MB, 1.01 MB, 0.37 MB PNGs — rendered into ~140px tiles. No `f_auto`, no `q_auto`, no `w_` transform anywhere in the URLs. The home page pulls dozens of these. Single biggest performance defect and the cheapest to fix.
- **Visible progressive loading.** Category tiles and product cards render as blank/coloured rectangles for 2–5 seconds on a fast connection. No skeletons.
- **Screen transitions take 3–5 seconds** with nothing on screen during the slide.
- **Flutter web/CanvasKit payload** — large initial bundle, unavoidable given the stack, but it compounds the image problem.
- **Not testable from the available interface:** real-world TTFB from campus mobile networks, server load behaviour, DB query timings.

---

# Accessibility Findings

Measured, not assumed:

- **No accessibility tree at all.** `flt-semantics-host` is empty; an accessibility snapshot returned a 0-byte document. Screen readers get nothing until the user finds Flutter's hidden "Enable accessibility" affordance. This is the default CanvasKit behaviour, and it means the app is effectively unusable with a screen reader out of the box.
- **Zero `<img>` elements.** Everything is painted to canvas, so no product image can carry alt text.
- **No visible focus indicators.** Six Tab presses scrolled the page and highlighted nothing. The entire app is one `tabindex=0` host element.
- **Tap targets below minimum.** Cart quantity buttons are 28×28 px (`cart_screen.dart`), against a 44×44 recommendation.
- **Low-contrast text throughout:** "Sold by PURE BITES" and price sub-labels in `#9A9A9A` on light backgrounds; the profile footer logo is white on grey and genuinely unreadable.
- **No form labels** in the accessibility sense — placeholders only, which vanish on input.

---

# What's Actually Good

Not generic praise — these specific things hold up:

- **The visual design.** Consistent spacing, restrained palette, good typography, sensible card and pill language. It reads as a real product.
- **The seller onboarding form** is the best-validated screen in the app: it explains *why* the button is disabled ("Add your business name"), warns when MRP sits below the selling price ("buyers would see a markup, not a discount"), and trims whitespace-only input.
- **Admin destructive-action design.** Rejecting a store forces a reason the seller will actually read; category deletion confirms *and* the server refuses while stock is filed under it; rider PINs are shown once and never stored readably.
- **Order placement concurrency.** `FOR UPDATE` on the item row plus a live reservation sum means stock cannot oversell under concurrent orders. A real engineering decision, not an accident.
- **The delivery panel.** Clean, single-purpose, correct information hierarchy for someone on a bike. The pick-up → code → delivered flow is exactly right (once the 401 bug is fixed).
- **Search debouncing with stale-response guarding** — a slow reply for an old query cannot overwrite a newer one.
- **Graceful degradation on bad data.** A broken image URL renders a tidy placeholder; a 500-character title truncates with an ellipsis instead of wrecking the grid.
- **Session persistence** survives refresh correctly (it is only cart and wishlist that do not).

---

# Top 10 Things To Fix First

### #1 — The ₹15 delivery fee is charged but never recorded
- **Why:** the customer, the shop and the rider see three different numbers, and cash collection is wrong on every order.
- **What:** add a `delivery_fee` column, send it with the order, include it in `amount` or alongside it, and show it in My Orders and the rider card.
- **Priority:** P0, blocks launch.

### #2 — Persist cart and wishlist
- **Why:** refresh = empty cart, on a web-first store.
- **What:** `shared_preferences` at minimum; server-side for cross-device.
- **Priority:** P0.

### #3 — Fill in the five legal documents
- **Why:** users are made to agree to templates containing `[Company Name]` and `[grievance@email.com]`.
- **What:** complete all placeholders, then make the admin's "has blanks to fill in" flag a publish blocker.
- **Priority:** P0.

### #4 — Onboard riders, or turn off ordering
- **Why:** with zero riders the app cannot complete an order; a real one sat for 22 days.
- **What:** recruit and add riders before launch, and surface "no riders available" in the admin and to shoppers.
- **Priority:** P0.

### #5 — Delete the fake notifications screen
- **Why:** it tells users a ₹1,299 payment succeeded for an order that does not exist.
- **What:** wire it to real order events, or ship an honest empty state.
- **Priority:** P1.

### #6 — Rate-limit password and PIN authentication; lengthen the rider PIN
- **Why:** unlimited guesses against a 4-digit PIN that unlocks every customer's address.
- **What:** per-IP and per-account backoff and lockout on all three endpoints; 6 digits minimum, ideally OTP.
- **Priority:** P1.

### #7 — Return 400, not 401, for a wrong delivery code
- **Why:** one mistyped digit ejects the rider mid-run.
- **What:** change `explainFailedDelivery`'s default branch to `StatusBadRequest`. One line.
- **Priority:** P1.

### #8 — Remove or implement every "coming soon" control
- **Why:** promo code, all three support channels, Settings→Privacy/Terms, Payment methods, Language, Currency, Share, About. A user in trouble currently has no working way to reach anyone.
- **What:** hide what is not built; wire Settings→Privacy/Terms to the policy screens that already exist; publish a real support email.
- **Priority:** P1.

### #9 — Make Settings toggles real
- **Why:** "Email offers: off" is currently a lie, which is a consent problem, not just a bug.
- **What:** persist to the server and honour the flags in `notify.go`.
- **Priority:** P1.

### #10 — Serve resized images
- **Why:** 2.7 MB PNGs behind 140px thumbnails, dozens per page, on campus mobile data.
- **What:** insert `f_auto,q_auto,w_400` (and `w_1000` for the PDP) into the Cloudinary URLs.
- **Priority:** P1. Cheapest large win in the codebase.

---

# Production Readiness

## MUST FIX BEFORE LAUNCH

- Delivery-fee accounting (B1)
- Cart/wishlist persistence (B2)
- Complete the legal documents; block publishing while blanks remain (B4)
- Onboard riders, or gate ordering behind rider availability (B3)
- Remove the fabricated notifications screen (B5)
- Rate limiting on all password/PIN endpoints; longer rider PIN (B6, B7)
- Fix the wrong-code → sign-out bug (B8)
- Remove or implement every "coming soon" control, and give customers one working support channel (B9, B11, B12)
- Make notification/consent toggles real (B10)
- Decide and state the payment model; align the Refunds policy with it
- Purge test data from the live catalogue (`item-42` "cake") and remove "dev build — no OTA" (B28, B30)
- Server-side input validation: title/name lengths, phone format, category existence, price ceiling, photo requirement (B23–B26)

## SHOULD FIX SOON

- Order cancellation and an order detail page (the FAQ already promises both)
- Show the delivery address at checkout; add an order confirmation screen
- Add-to-cart toast on the PDP; remove the dead cart-header button (B16, B17)
- Search scope chip and a clear control (B21)
- Fix category icons and add the 33 missing subcategory images (B18, B20)
- Image transforms (B15)
- Admin: order amounts, search, filters, date ranges, pagination, export; per-admin accounts with an audit trail
- Address editing; recipient name/phone in the list; confirmation on delete (B37)
- Resolve the `isDefault` disagreement between client and server (B29)
- Fix the Insights revenue contradiction and the drawer's contradictory copy (B27, B22)
- Proofread the catalogue ("Chesse" ×3, "TIkki")
- Explain disabled buttons everywhere, as the seller form already does (B31)

## NICE TO HAVE

- Ratings and reviews; stock and ETA on the product page
- Atomic multi-item orders instead of N independent ones
- Accessibility: enable semantics, add focus indicators, raise tap targets to 44px, fix low-contrast text
- Guest cart that survives sign-in
- Seller: ability to close a store; richer sales analytics
- Recent/popular searches; a CTA on every empty state
- Push notifications actually driven by the Settings toggle
- One version number, sourced once

---

# Final Verdict

A QA lead should not approve this for production, and it would not be a close call. Not because the engineering is bad — parts of it are notably careful, and the concurrency handling in order placement and the admin's destructive-action design are better than usual at this stage — but because the app currently misrepresents itself to its users in ways that go past "unfinished". It charges ₹84 and records ₹69. It shows people a payment confirmation for money nobody paid. It asks them to agree to terms that still say `[Company Name]`. It offers three support channels and answers all three with "coming soon". It lets them switch off marketing email and quietly ignores them. Each of those is individually fixable in an afternoon; together they mean the interface cannot be trusted as a description of what the system does, and that is the specific thing QA exists to block.

The operational picture is just as decisive and much simpler: there are zero riders. The delivery flow was only provable by creating one. Without that, an order placed today goes to a shop, gets accepted, and stops — exactly as `ORDER-1` did for 22 days. You cannot launch a delivery marketplace with no delivery.

The good news is that the hard parts are done. The catalogue, the ordering transaction, the store-approval workflow, the rider handoff with its delivery code — all of that exists and works. What is left is mostly deletion and honesty: strip the scenery, wire up the handful of controls worth keeping, put real numbers where fake ones are, hire riders, and finish the paperwork. That is roughly two focused weeks, not a rewrite. After the twelve MUST FIX items, this would be signed off.
