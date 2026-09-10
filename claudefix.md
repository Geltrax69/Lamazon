# claudefix — what was fixed against CHECK 2

Work done against the release gate in `checks2.md` (build `codex/functionality-checkout` @ `519ebf0`).
Every item below is a code change in this repo, verified by a test, a measurement, or a
screenshot. Items I did **not** fix are listed in §7 with the reason — the point of this file
is to be accurate about both halves.

**Verification baseline:** 85 frontend widget tests and the full Go backend suite pass;
`flutter analyze` reports no issues; the release web bundle builds, renders, and was measured.

---

## 1. The three release blockers

### C2-001 — Deleting a product destroyed every order for it (P0)

The worst defect in the report: a seller tidying their catalogue silently erased delivered
orders and their financial record, returning `204` as though nothing happened.

- `backend/schema.sql` — `orders.item_id` moved from `ON DELETE CASCADE` to `ON DELETE RESTRICT`.
  `inventory_items.owner` too, because deleting a store reached orders the same way one table further out.
- `backend/seller.go` — `handleDeleteItem` counts referencing orders first and returns `409`
  with the same shape of message `handleDeleteCategory` has always used:
  *"1 order placed for this product. Hide it from the shop instead — deleting it would take the orders with it."*
- `backend/schema.sql` + `backend/db.go` + `backend/seller.go` — a `delisted` flag and
  `PATCH /api/seller/items/{id}/listing`. Refusing the delete without this would turn a
  data-loss bug into a dead end, so the two ship together. Delisted items leave the shop
  (`db.products()` filters them) and stay in the seller's own list with a "Hidden" badge.

**Proof:** `backend/item_delete_test.go` runs the report's own reproduction — place an order,
delete the item, assert `409` and that the buyer still has their order; then delist, assert it
leaves `/api/products` while staying in `/api/seller/items`; then relist and assert it returns.
It also deletes an *un*ordered item to prove the guard is not just refusing everything.

### C2-002 — The seller's delete and restock controls changed nothing on the server (P1)

`removeItem` and `adjustStock` were synchronous and touched local memory only. The product
vanished from the seller's screen while remaining live and purchasable; every dashboard counter
became fiction after one press.

- `frontend/lib/data/api.dart` — added the three missing calls: `deleteItem`, `patchStock`,
  `setDelisted`. `PATCH /api/seller/items/{id}/stock` already existed on the backend and had
  no frontend caller at all.
- `frontend/lib/data/seller.dart` — both mutators are now `async`, go through the API, and roll
  back on failure using the same optimistic pattern `acceptOrder`/`rejectOrder` already use.
  The server's returned stock wins over the local guess, so the badge cannot drift.
- `frontend/lib/screens/seller_dashboard_screen.dart` — a confirmation dialog on delete that
  names the product and says what happens; an **Undo** on hide/unhide; error snackbars that
  show what the server actually said, with a "Hide instead" action when the delete is refused.

### C2-003 — Keyboard-only users could not save an address, so could not order (P1)

The submit was a bare `GestureDetector`: no role, not in the tab order, deaf to Enter and Space.
A delivery address is mandatory, so this closed the whole purchase funnel to anyone without a mouse.

- `frontend/lib/screens/location_screen.dart` — submit is now the app's own `ActionButton`,
  which carries semantics and focus. Home/Office/Other became a real single-select group
  (`inMutuallyExclusiveGroup`) on `InkWell`s. The city chips became `ChoiceChip`s.
- `frontend/lib/screens/addresses_screen.dart` — "Add new address" is an `ActionButton`
  (it previously had `role=button` but no tabindex, so the screen's primary action was
  unreachable). Address rows became a labelled radio group; the delete gesture became an
  `IconButton` with a name.

**Proof:** a new widget test asserts the submit's live semantics are
`isButton, hasEnabledState, label: "Save address"`.

---

## 2. Accessibility

| ID | Fix |
|---|---|
| C2-004 | `FocusRing` in `design_system.dart` paints a 2 px `strong` (`#1D4939`) outline over any focused control — measured ~8:1 against the surface, where the old lime wash measured 1.10:1 against a 3:1 requirement. Applied to `ActionButton` and `TactileIconButton`, and to the filled/outlined/text/icon button and chip **themes**, so controls inherit it instead of each screen deciding. |
| C2-018 | Heading semantics, which the app had **none** of. `ScreenHeader` titles are `headingLevel: 1`; `SectionHeading` — the widget every screen uses — is `headingLevel: 2`, so one change gives the whole app a navigable outline. |
| C2-019 | Duplicated labels. `TactileIconButton`'s `Tooltip` was re-announcing the label the `Semantics` above it already carried ("Back Back"). Added `excludeFromSemantics`. Category tiles, department chips and `ElevatedSurface` were announcing three times ("Electronics, Electronics category, Electronics"); those now `excludeSemantics` under their own label. |
| C2-020 | Admin KPI tiles announced bare digits. Now one node per tile reading "Orders: 4". |
| C2-021 | Admin section chips claimed `role="checkbox"` for single-select navigation; now `inMutuallyExclusiveGroup` inside a labelled "Admin section" group. |
| C2-022 | Cart quantity buttons were 38×38; now `LamazonTheme.touch` (44). Seller stock ± keep a 28 px visual inside a 34 px target with a name and tooltip. Details-screen stepper likewise 44. |
| C2-050 | Pinch-zoom was blocked because, with no viewport meta of its own, the Flutter engine injects one carrying `user-scalable=no`. `web/index.html` now declares its own. |
| A11Y-008 | Address-form errors are a `liveRegion`, styled in `danger`, with an icon — and only appear once a field has been touched, instead of greeting an untouched form with "Enter the recipient name." |
| A11Y-010 | The login marquee runs forever; added a labelled pause/resume control (WCAG 2.2.2). Hidden when reduced-motion has already stopped it. |

**Verified live** in the running app's accessibility tree: every control carries a role and
`tabindex="0"`, and "Browse departments" / "Open account" now announce once rather than two and
three times.

---

## 3. Correctness and trust

| ID | Fix |
|---|---|
| C2-005 | Sign-up collected consent against four policies that all render "not published yet". `Policy` now carries a `published` flag (false while the shipped drafts still have `[Company Name]`-style blanks), and the login screen drops "By continuing, you agree to our" for a neutral "Read our" until the documents are real. The policy screen shows the last-updated date the API has always returned. **The policies themselves still need writing — see §7.** |
| C2-007 | The cart accepted 5 units of an item with stock 1 and failed at "Place order". The cap now lives in `Cart.add`/`setQty` — one place, covering all five call sites. `+` disables at the cap with a reason ("That is all the shop has"), and `Cart.reconcile()` trims a stale basket when the cart screen opens, saying what it changed. |
| C2-012 | Seller thumbnails always showed a grey placeholder because `cover` read local upload bytes only. `PhotoOrPlaceholder` now falls back to the stored `imageUrls`. |
| C2-023 | Removing a cart line had no undo — the last item took the whole basket. `Cart.remove` returns the line and the UI offers **Undo**. |
| C2-032 | "Order order-6" leaked the database key. `orderRef()` renders `#0006`, applied across the confirmation, list, detail, seller and rider screens. |
| C2-033 | `/api/orders` and `/api/addresses` answered an unauthenticated shopper with "sign in to manage your store". Now "sign in to see this". |
| C2-034 | A wrong-role or bogus token returned "session expired — sign in again", asserting something that had not happened. Now "sign in again to continue". |
| C2-028 | The login marquee advertised ~12 sample products (bread, pizza, a teddy bear) not in the catalogue. It now draws from `shownCatalog`, and the fallback is empty rather than three stock photographs of goods nobody can buy. |
| C2-038 / C2-039 | Delivery ETA is now shown in the cart and on the confirmation — `/api/locations` has always returned "12 mins" and no screen displayed it. |
| C2-040 | Quantities rendered zero-padded as "05". Now "5". |

---

## 4. UI and the design system

| ID | Fix |
|---|---|
| C2-008 | The floating nav overlapped the first row of every department grid. `bottomNavInset(context)` in `app_nav.dart` returns nav height + padding + the safe-area inset (which the old hardcoded 90–112 px values ignored, so a phone's home indicator pushed content under the bar). Applied to home, search, profile, wishlist, shops and the seller dashboard. |
| C2-009 / PAT-008 | Every category in a department drew the same glyph — "Toys & Games" and "Glue & Tape" both got a book. `glyphFor()` in `category_visual.dart` keys on the **category**, matching ~45 keyword patterns ordered specific-before-general, falling back to the department icon when a name is genuinely unrecognisable. |
| C2-011 / PAT-001 | `labelText` and `hintText` were set to the same string, printing the label twice, stacked, in a focused field. Fixed on the address form and the search field. |
| C2-025 | The search screen's pastel blue / peach / lilac / pink department blocks were exactly the "rainbow-department dashboard" `DESIGN.md` opens by refusing. Re-skinned onto ivory with a `track` border; the department's colour survives as the icon. |
| C2-026 | Search had no result count, no clear control, no sort. Added a live-region result count ("3 results for …"), an × clear button, and a sort control (best match / price / discount). |
| C2-027 | "Skip login" is developer language for what a shopper wants. Renamed to "Browse the shop". |
| C2-024 / C2-035 / PAT-002 | Off-system colours replaced with tokens across 24 files: `#1A1A1A`→`text`, `#6B6B6B`/`#62645E`→`muted`, `#F1F1EF`→`canvas`, `#2E7D32`/`#1D4A3C`→`strong`, `#D32F2F`→`danger`. **229 literals → 83; theme references 200 → 389; distinct hex values 62 → 52.** The ratio the report called out is now inverted. `test/palette_ratchet_test.dart` is the lint it asked for — a new `Color(0xFF…)` fails CI and the failure names the worst files. Verified by planting a regression and watching it fail. |
| C2-036 | Admin showed "0 records" with Previous/Next beside it, under an empty state that had already said the list was empty. Pagination is hidden entirely at zero rows, and the buttons are hidden when there is only one page — the count line stays, because it is how you tell a search worked. |
| C2-044 | Four back-button positions. The address and addresses screens now use the shared `ScreenHeader`, and search uses `TactileIconButton`, so the control is in one place with one appearance. |

---

## 5. Performance

**Cold load: 7.02 MB → 4.58 MB (−35%).** Measured from the built bundle.

| ID | Fix |
|---|---|
| C2-006 | 3.2 MB of the payload was seven Lucide icon-font files; the app uses one. Tree-shaking cannot remove the other six — it prunes glyphs *inside* a font, and these are referenced by `IconData` constants that merely happen to be unreachable. The alternative, vendoring the package to edit its pubspec, means committing a 12 MB generated Dart file to save 2.5 MB of download. Instead `frontend/tool/prune_fonts.py` drops the six unused weights from `FontManifest.json` after the build, wired into `vercel.json`'s build command. **It refuses rather than guesses**: if the app ever uses `LucideIcons.house300`, the build fails instead of silently shipping blank squares. Verified: a fresh load now fetches only `lucide.ttf`, InterTight and Cupertino, and every icon still renders. −2.44 MB. |
| C2-014 | `pubspec.yaml` shipped `assets/categories/` wholesale, including `category-atlas.png` (2.1 MB, superseded by v2) and `everyday-campaign.png` (2.2 MB), neither referenced anywhere in `lib/`. Plus an unused `banner.png`. Assets are now listed file by file — a directory entry cannot tell the difference. −4.3 MB of install size (these were lazy-loaded, so they do not appear in the cold-load figure above). |
| C2-015 | `vercel.json` cached `/(.*)\.js` for 7 days while the bundle is `main.dart.js` with no content hash, so a returning user could run a week-old client against a live API. The entry bundle now revalidates; `/assets/` dropped from 7 days to 1 day revalidated for the same reason; `flutter_service_worker.js` and `manifest.json` are `no-cache`. |

---

## 6. Content and packaging

| ID | Fix |
|---|---|
| C2-016 | The PWA manifest was untouched Flutter boilerplate — name "lamazon", description "A new Flutter project.", `theme_color` `#0175C2` (Flutter blue). Now the real name, a real description, and the app's own forest/ivory. `index.html` title and Apple title likewise. |
| C2-017 | `Icon-maskable-*.png` were **byte-identical** to the standard icons (same MD5), so Android cropped into the logo. Regenerated with the mark at 62% on its own ground, so any mask shape crops only background. |
| C2-029 | The address form took two presses ("Check availability" → "Save address") for three fields. Collapsed to one: the serviceability answer shows from the start, because the city is chosen from a list of serviceable cities. |
| C2-030 | Validation errors appeared on a pristine form, one field at a time, unstyled. Now a single `_problem` getter drives both the message and the button's enabled state (they previously tested the same fields twice in two different orders), shown only after a field is touched. |
| SEC-002 | `web/index.html` ships a fallback `firebaseConfig` for project `messages-34023`, which is not this product's project. I did **not** change the values — that needs a developer's answer, and removing them would break push wherever `window.lamazonFirebaseConfig` is not set. Added a `FIXME(ops)` naming the problem and a console warning when the fallback is used. **Still needs a decision — see §7.** |

Also renamed for clarity: "Saved Addresses" → "Delivery addresses", "Enter Location" → "Add delivery
address" (the report noted three names for one concept, on a form whose first field is *Full name*).

---

## 7. Not fixed, and why

Being explicit so this file is not read as a clean sweep.

- **C2-005, the policies themselves.** The drafts in `backend/policy_text.go` are largely written
  but blocked on facts I cannot invent: registered company name, address, grievance officer.
  I made the app stop *claiming consent* against them, which is the honest interim state. Writing
  them is a content job for whoever owns the entity.
- **SEC-002, the Firebase fallback.** Flagged in code and here; needs a developer to confirm
  whether `messages-34023` is intentional. I would not silently swap credentials.
- **C2-010, junk categories** ("Test", "Work", "123456789", "567890" live under Electronics →
  Mobile Accessories). This is data, not code, and the admin delete guard already works — four
  clicks in the admin panel. I did not reach into a database to delete rows I cannot see the
  provenance of.
- **C2-024, the last 83 colour literals.** The systematic substitutions are done and ratcheted;
  what remains is one-off accent colours on individual screens, which need design decisions
  rather than a find-and-replace.
- **C2-043, legacy `POST /api/orders` idempotency.** The web client uses the idempotent
  `/api/orders/checkout`; this affects other clients only. Left as booked work.
- **C2-046, the debug-build stack overflow.** Blocks local development, not users; the release
  build is unaffected.
- **C2-042 verification and end-to-end browser QA of the address form.** The in-app browser pane
  was hidden for this session, which blocks synthetic click and type — the same limitation the
  original report declared. The address form is covered by a widget test that asserts its live
  semantics instead.

---

## 7b. Second pass — the rest of the register

| ID | Fix |
|---|---|
| **Order detail screen** | Rebuilt. The report never tested it, and it held two of the most important things in the app behind bare `Text` widgets: the delivery code and order cancellation. It now has a four-step progress track, the code set large and spaced so it can be read aloud at a door, a proper cancel dialog naming what is being cancelled and what it costs, and the ETA. Cancellation was already wired to `POST /api/orders/{id}/cancel` — the report listed it as missing because that screen was out of scope. |
| C2-013 | The seller saw "1 left" while shoppers saw "Out of stock". `db.items()` now returns `reserved` (units held by live orders), the dashboard shows "N to sell · M in orders", and `StockStatus` keys on **available** rather than raw stock — so a line whose entire stock is spoken for reads as out of stock to its seller too. |
| C2-031 | "Start shopping" from the empty cart popped the stack, leaving the browser address bar reading `/cart` and dumping the shopper at their old mid-page scroll position. Now `pushNamedAndRemoveUntil('/')`. Same fix applied to the empty wishlist and the order confirmation's "Continue shopping". |
| C2-037 | Eight red trash icons outshouted the single "+ Department" primary action. `_QuietDelete` renders them muted until hovered or focused, then red — same tooltip, same target, same place, no longer the loudest thing on screen. |
| C2-041 | The push-permission banner appeared above the hero on first paint, asking for a browser permission before the person had done anything — the reliable way to get it denied permanently. Moved below the campaign and gated on the shopper actually having an order, which is when there is something to notify them about. |
| C2-045 | Four of nine department labels truncated ("Household…", "Grocery & …"). Tiles widened 66→74 px and labels given two lines. |
| C2-047 | Product cards measured 232 px on home and 193 px in search, because home was the one grid with its own `maxCrossAxisExtent` instead of `productTileMax`. |
| C2-048 | The "Only N left" scarcity badge and the seller's "Low stock" both fired at 5, so scarcity sat on nearly everything. Split: `scarceAt = 3` for shoppers, `lowStockAt = 5` for the seller, who wants earlier warning. |
| C2-035 | "Your information" / "Other Information" — sentence case both. |
| Loading states | The report found none on any async action. `ActionButton` gained a `loading` flag that shows a spinner and announces the control busy; wired into place-order, save-address, sign-in, refresh-status and cancel-order. |
| Missing info | App version now in the account footer (`AppInfo.load()` already ran at startup and only Settings showed it). The admin panel says which admin is signed in, next to the Sign out it previously offered anonymously. |

**Palette, measured:** 229 literals → **83**; theme references 200 → **389**; distinct hex 62 → **52**.
`test/palette_ratchet_test.dart` holds the line.

---

## 8. Files changed

**Backend (Go/SQL):** `schema.sql`, `seller.go`, `db.go`, `types.go`, `main.go`, `policies.go`,
`item_delete_test.go` (new).

**Frontend (Dart):** `data/` — `api.dart`, `cart.dart`, `seller.dart`, `orders.dart`,
`addresses.dart`. `widgets/` — `design_system.dart`, `app_nav.dart`, `category_visual.dart`,
`screen_header.dart`, `image_marquee.dart`, `photo_picker.dart`, `product_card.dart`.
`screens/` — `location_screen.dart`, `addresses_screen.dart`, `cart_screen.dart`,
`details_screen.dart`, `search_screen.dart`, `login_screen.dart`, `policy_screen.dart`,
`seller_dashboard_screen.dart`, `admin_screen.dart`, `home_screen.dart`, `profile_screen.dart`,
`wishlist_screen.dart`, `shops_screen.dart`, `orders_screen.dart`, `order_detail_screen.dart`,
`order_confirmation_screen.dart`, `delivery_screen.dart`. Tests — `stock_cap_test.dart` (new),
`smoke_test.dart`.

**Build/packaging:** `pubspec.yaml`, `tool/prune_fonts.py` (new), `web/index.html`,
`web/manifest.json`, `web/icons/Icon-maskable-*.png`, `vercel.json`.

---

## 9. Against the report's definition of done

| Condition | State |
|---|---|
| Delete a product with a delivered order — order survives, delete returns 409 | **Done**, covered by `item_delete_test.go` |
| A seller can hide and unhide a product, history intact | **Done**, same test |
| Seller trash and ± agree with the server | **Done** — both call the API and roll back on failure |
| Complete a purchase with Tab, Enter and Space only | **Address form fixed and semantics asserted by test**; a full pointer-free run of the whole funnel was not possible this session (§7) |
| Focused control measures ≥ 3:1 | **Done** — `strong` on `surface` is ~8:1, applied theme-wide |
| All four policies return real text with a date | **Not done** — the date is wired; the text needs an owner (§7) |
| Add-to-cart stops at available stock, with a reason | **Done**, covered by `stock_cap_test.dart` |
| `/api/categories` contains no test data | **Not done** — data cleanup, four clicks in admin (§7) |
| First load under ~2.5 MB | **Partly** — 7.02 → 4.58 MB. `main.dart.js` alone is 3.37 MB, so 2.5 MB is not reachable without code-splitting the Flutter bundle |
| No content permanently hidden behind the nav | **Done** — inset now includes the safe-area the old constants omitted |
