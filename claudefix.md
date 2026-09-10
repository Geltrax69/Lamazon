# claudefix — what was fixed against CHECK 2

Work done against the release gate in `checks2.md` (build `codex/functionality-checkout` @ `519ebf0`).
Every item below is a code change in this repo, verified by a test, a measurement, or a
screenshot. Items I did **not** fix are listed in §7 with the reason — the point of this file
is to be accurate about both halves.

**Verification baseline:** 102 frontend widget tests and the full Go backend suite pass;
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

## 7c. Third pass — hierarchy, density, and the last of the button system

Driven by looking at the running app at 1280×800 and 375×812 rather than by the register alone.

| Area | Fix |
|---|---|
| **Search landing** (§4.2) | The department tiles were `crossAxisCount: 2` at `childAspectRatio: 2.6` — 613×236 px each to carry one 24 px icon and one word, so two fit per viewport and reaching the ninth took four screens. Now `GridView.extent` at 240 px max, aspect 3.6: **all eight departments fit in one band**, five across on desktop and two on a phone. Departments, categories and real products now sit above the fold together. Verified in the browser before and after. |
| C2-044 | Two primary buttons remained — `ActionButton` at a hardcoded 23 px radius (26 uses) and Material's `FilledButton` at `featuredRadius` 18 (24 uses), so the same action looked like a pill on one screen and a rounded rectangle on the next. Rather than convert 50 call sites, `LamazonTheme.pill` (a `StadiumBorder`) now shapes the filled, outlined and text button themes, and `ActionButton` drops its magic number. Cards keep the rounded rectangle. |
| C2-047 | Product images letterboxed with grey bands. Two causes compounding: Cloudinary padded the source into a square (`c_pad`, `b_auto`), then `BoxFit.contain` letterboxed that square into a taller box against a `#F2F2EC` ground — two band colours per card. Now no square pad, contained once, on the card's own surface. Also: home was the one grid using its own `maxCrossAxisExtent: 240` instead of `productTileMax`, which is why the same card measured 232 px on home and 193 px in search. |
| PAT-008 follow-up | "Batteries" and "Chargers & Cables" shared a glyph. Batteries got its own; verified visually that all six Electronics shelves now show six different icons. |
| C2-036 | The remaining stacked empty states. `_Empty` is now a proper empty state (icon on a surface) rather than a bare grey sentence, and the search box, status dropdown and date range are hidden when the underlying list has no rows at all — three controls that could not do anything. |
| §4.2 admin | Six KPI tiles in two rows took ~150 px of an 800 px viewport **on every section**, not just an overview. One row of six on desktop halves it; the phone keeps the 3-up reflow the report praised. |
| §4.3 admin | Department cards were a `Wrap`, which sizes each child to its own content — "Gifts" stood 64 px tall beside "Beauty" at 96 px in the same row. Rows of two with `CrossAxisAlignment.stretch` make each pair agree on the taller. |
| Duplicate constant | I introduced a second `deliveryEta` in `addresses.dart` when one already existed in `catalog.dart`. Removed; the three screens now import the original. |

**Not done in this pass:** the admin panel itself was verified by analyzer and tests, not in the
browser — reaching it means typing a password into a login form, which I don't do.


---

## 7d. Found by using the app, not by reading the register

Driving the guest shopping flow end to end turned up a defect in **my own** C2-007 fix.

The cart's `+` at the stock cap was correctly inert — pressing it did nothing — but it kept its
full lime fill and raised shadow. A disabled control that looks live reads as a broken button,
not as a limit, and the reason ("That is all the shop has") was only carried as a tooltip, so
only a mouse that happened to hover ever saw it. `TactileIconButton` now renders `track` fill
with no shadow when `onPressed` is null, which is the pattern the out-of-stock product card was
already using correctly — grey **plus** a text label, never colour alone. One shared widget, so
every disabled icon button in the app (cart steppers, the details-screen quantity stepper, the
seller's stock ±) is fixed at once. `test/disabled_control_test.dart` pins both states.

### Verified live in the running app during this pass

| Behaviour | Result |
|---|---|
| Add 6 of a product with stock 5 | Refused at 5 with **"Your cart already holds every one the shop has."** Cart badge reads 5. |
| Out-of-stock product card | Red "Out of stock" text **and** a greyed control — not colour alone. |
| In-stock product at 5 units | Reads "In stock", not a false "Only 5 left" — the split scarcity threshold working. |
| Cart quantity | Renders **5**, not "05". |
| Cart summary | "Arrives in about 12 mins" present, total ₹75 correct. |
| Cart `+` at cap | Inert, labelled "That is all the shop has" in the accessibility tree. |
| Bottom nav | Nothing hidden behind it on the cart at 1280×800. |
| Search landing | Eight departments in one band; categories and real products above the fold. |
| Category glyphs | Six distinct icons across the six Electronics shelves. |
| Product images | No letterbox bands. |
| Unpublished policy | Still renders the placeholder, and the sign-in line still reads "Read our". |
| Accessibility tree | Every control carries a role and `tabindex="0"`; labels announce once. |


---

## 7e. The home header: three controls that did not earn their place

Raised by the user looking at the header, not by the register. All three turned out to be real.

**The hamburger (top left).** It opened a drawer listing departments and their categories. But
the department strip sits 60 px below it, a titled grid per department sits below that, and
search has "Shop by department" as well — **four routes to the same destination on one screen.**
The drill-down it added was already provided by the home category tiles, with artwork. Removed,
along with `_BrowseDrawer`, `_DrawerDepartment`, `_DrawerCategory` and the `_all` field that
existed only to feed it.

**The account avatar (top right).** `Navigator.pushNamed(context, AppRoutes.account)` — the
exact route the bottom bar's Account tab already goes to, and that tab is always visible and
carries a label. The same destination twice, 40 px apart. Removed.

**The chevron beside it.** This one was not a duplicate, it was mis-placed. It has always
belonged to the delivery location — it lives inside that row's `InkWell` — but the location text
was `Expanded`, which pushed the chevron to the far right edge, flush against the avatar. So it
read as the avatar's dropdown. It is `Flexible` now, so the chevron follows the text it belongs
to, and it is lime like the pin at the other end of the line.

What is left is what a shop header is for: who you are shopping with, and where the order is
going. The location gets the full width as a side effect, so a long saved address no longer
ellipses. `test/header_test.dart` pins the absences, because a removed duplicate is exactly the
kind of thing that grows back.


---

## 7f. Admin QA pass, and the Stack Overflow

### The crash (C2-046, re-diagnosed)

A debug build rendered the admin sign-in card as a red **"Stack Overflow"** box where the
password field should be. The release gate blamed "the Lucide icon library, 571 scripts". That
was directionally right and mechanically wrong, and the wrong mechanism sent me down two dead
ends before I found it.

What it actually is: `_shown ? LucideIcons.eyeOff : LucideIcons.eye` reads those statics **at
runtime**. `LucideIcons` is one class holding **27,874 static consts**, and DDC initialises them
lazily on first runtime access — which exhausts the stack. The shield icon at the top of the
same card always rendered fine because it sits inside a `const` subtree and is folded at compile
time. Written as two `const Icon(...)` arms instead of one `Icon` holding a conditional, the
initialiser never runs.

Release builds compile with dart2js and were never affected, which is why this survived: it was
broken only for whoever was developing the panel.

Two dead ends worth recording, because the measurements looked convincing:
- **Widget depth.** The reveal icon sat at element depth 255 against the field's 186, and
  `InputDecorator`'s suffix slot costs 19 levels on its own. Flattening it to 220, then 211, then
  187 via a `Stack` — all still crashed, while the username field at 186 rendered. A one-level
  difference is not a threshold, which is what finally ruled depth out.
- **The suffix slot.** Removing `suffixIcon` entirely did fix it, which looked like proof. It was
  a coincidence: removing the slot also removed the only runtime Lucide read on the screen.

The decisive test was swapping `LucideIcons.eye` for `Icons.visibility` and watching the card
render. Three more conditional Lucide reads in the same library (`_ProductRow`'s hide toggle, a
disclosure chevron, the policy preview toggle) are hoisted to file-level consts for the same
reason.

### The QA harness

`test/admin_qa_test.dart` drives the real `AdminScreen` against a mocked API — the only way to
exercise the panel without typing a password into a login form. Every one of its twelve sections,
at 375, 834 and 1440.

| Found | Fix |
|---|---|
| **`_StoreCard` overflowed by 322px at 375** — the store-approval queue, the first thing an admin sees. Four controls and a `Spacer` needed 629px in 307. | The actions are a `Wrap`. Splitting it also gave the card the hierarchy the single row hid: the approve/reject decision the card exists for, then the two upkeep tools below it at lower weight rather than beside it at equal weight. |
| **`_amber` `#EF6C00` measured 2.85:1 on canvas** — below even the 3:1 floor for large text, on "waiting for review", "needs restock" and the low-stock badge. Stock Material orange, the last off-system colour in admin. | `LamazonTheme.warning` `#9A5B12`: 5.33:1 on canvas, 5.00:1 on surface, and a warm ochre rather than a safety cone. Replaced in three other files carrying the same value. |
| Status pills printed the raw column value — "pending", "approved". | "Waiting for review", "Live in the shop". |
| A store with no phone rendered `owner@x.test · ` with the separator dangling. | Joined, not interpolated. |

The harness also asserts every icon-only control has a tooltip and meets the 44px floor, that the
panel keeps heading semantics, and that the products section shows all three stock numbers. A
contrast case checks every ink against both grounds — verified by putting the old orange back and
watching it fail.

**Also cleared 4.1 GB of disk**: the machine was down to 125 MiB free, which was breaking builds.
Removed `frontend/build` (3.7 GB of repeated web builds) and `.playwright-mcp` (415 MB) — both
git-ignored and regenerable. Nothing tracked was touched.


---

## 7g. Banners that move: GIFs and video on the home screen

Asked for: *"in banner i want to add gifs, Videos, that will be displayed on
homepage so fix the code."*

A banner already had one field for artwork, `image_url`, holding an HTTPS URL.
Nothing about that field had to change — Cloudinary files a clip under
`/video/upload/` exactly the way it files a picture under `/image/upload/`, so
the URL already says which it is. Reading the kind back off the URL means no
new column, no migration, and no row that can end up disagreeing with the
asset it points at.

**A GIF is delivered as video, not as a GIF.** This is the part worth writing
down, because the obvious implementation is wrong and looks right.

Flutter's `Image.network` plays animated GIF and WebP natively, so the first
version simply asked Cloudinary for `c_limit,w_1600,f_auto,q_auto` and let it
animate. It worked. It also pulled **6.13 MB** for one banner, measured in the
release build in a browser.

Two things caused that, and both are worth knowing:

  * `f_auto` picks a format from the browser's `Accept` header. Flutter fetches
    images over XHR, which sends `*/*`, so Cloudinary cannot tell that the
    browser supports WebP or AVIF and falls back to the original format. The
    same URL fetched with a real browser `Accept` returns 61 KB of AVIF; fetched
    the way Flutter fetches it, 6.13 MB of GIF. **A format that is chosen is a
    size that can be relied on; a format that is negotiated is not.**
  * GIF stores every frame as its own image. It is a 1987 format and it shows.

So anything with frames now goes through the video path, GIF included —
`f_mp4` on delivery, which Cloudinary does server-side with the original left
untouched. Measured on the same animation, end to end in the release build:

| | before | after |
|---|---|---|
| animated banner, first paint | 6,130 KB (GIF) | 11 KB (JPEG poster) |
| animated banner, the motion | — | 131 KB (H.264) |
| **total** | **6,130 KB** | **142 KB** |

**What was built**

  * `bannerKind()`, `bannerArtwork()` and `bannerVideo()` in `data/catalog.dart`
    — three string inserts, no image pipeline, in the style of the transforms
    already there. Every transform in them was measured against Cloudinary
    before it was written, not assumed.
  * `widgets/banner_media.dart` — `BannerMedia` picks the branch: a picture is
    drawn, anything with frames that can be delivered as a clip is played
    muted, looped and without controls. A GIF hosted somewhere we cannot
    transform stays a GIF and `Image.network` animates it, which is the one
    case the video path cannot improve.
  * `CampaignBanner` uses it, so the admin banner list and the live draft
    preview play the artwork too — one change, three places.
  * The deck gives a clip a 12-second dwell instead of 6. Six seconds of a
    fifteen-second film is a banner whose ending nobody ever sees. The timer
    became one-shot rather than periodic so each slide gets its own dwell.

**Accessibility.** WCAG 2.2.2 asks for a way to stop anything that moves by
itself for more than five seconds. Reduced motion is that person having
answered in advance, so under it no player is constructed at all: the banner
is the first frame — `so_0` for a clip, `pg_1` for an animation — which is the
same picture without the movement. The deck already stopped advancing under
the same setting.

**Failure.** A banner is not worth a broken home screen. If the clip will not
initialise — a dead URL, a codec nobody has, autoplay refused — the poster
stays up and the page carries on. That path is covered by a test, because it
is the one that runs when something is wrong and nobody is watching.

**Backend.** `POST /api/admin/campaign-photos` now accepts MP4, WebM and
QuickTime alongside the four image types, at 25 MB rather than 10, and the
Cloudinary endpoint moved from `/image/upload` to `/auto/upload` so a clip is
filed as a video. Product photos deliberately did **not** get this: a video in
a product grid is a different app, and one seller uploading a 20 MB film would
slow the grid down for everyone. `photoBytes` now takes its allow-list as a
parameter, so the difference lives at the route that knows about it.

`ImagePicker.pickImage(imageQuality: 80)` re-encodes, which turns a GIF into a
single frame — silently, and only for the one person who wanted the animation.
Banner uploads use `pickMedia()` instead, and pass the real filename through so
Cloudinary files the upload by what it is rather than by a hardcoded `.jpg`.

**Cost.** `video_player` (the Flutter team's own plugin, all platforms) added
**61 KB** to `main.dart.js` — 3.30 MB to 3.36 MB. That is less than half of one
banner clip, and 1% of the GIF it replaces.

**Covered by** `test/banner_media_test.dart` — 8 tests: the kind read off the
URL, GIF delivered as a clip, the still of anything with frames being a chosen
JPEG rather than `f_auto`, clips capped and silent, foreign and
already-transformed URLs left alone, a hosted GIF played while a foreign one is
drawn, reduced motion getting a frame and never a player, and a clip that will
not play leaving the poster up.

**Known hole.** A GIF pasted from a host we cannot transform keeps moving under
reduced motion, because nothing client-side can extract a frame from it.
Everything staff upload goes through Cloudinary, so it takes a pasted foreign
URL to reach.

---

## 7h. Paste a link, and eight themes instead of three

Asked for: *"they can just paste the link of animation, videos and other file
formats — it auto detects and previews them, and then they can add"*, *"add
more colours in banner theme"*, and *"i cant add pinterest images or videos"*.

### Why Pinterest did not work

The links were `assets.pinterest.com/ext/embed.html?id=…` and
`in.pinterest.com/pin/…/`. Neither is a picture. The embed URL returns **524
bytes of HTML, byte-identical for every id** — an iframe shell that loads the
pin with JavaScript. The pin URL returns about **1.2 MB of HTML**. Putting
either in an image field stores a web page, which renders as nothing.

So the fix is not to make the field accept them; it is to work out what the
link is actually about. `POST /api/admin/campaign-media` takes a pasted link
and:

  1. fetches it and reads the content type;
  2. an image or a video is used as it is;
  3. HTML is read for `og:video`, then `og:image` — the tag a page publishes
     so link previews know what it is showing;
  4. Cloudinary is handed the resulting URL and **stores** it, so the banner
     lives on our own CDN.

Storing rather than hotlinking is deliberate. A banner pointed at somebody
else's server breaks the day they tidy up, and it puts our shoppers' requests
in their logs.

**Two things this got wrong first, both found by running it against the real
web rather than a fixture:**

  * **512 KB was not enough.** Open Graph tags are supposed to sit near the top
    of `<head>`. Pinterest puts a megabyte of inline script between
    `og:site_name` and `og:image` — measured at **byte 1,133,825** on a real
    pin. The first version read 512 KB, found nothing, and told the admin their
    link was unusable. The cap is 2 MB now, and there is a regression test
    built from a fixture over a megabyte long.
  * **`auto/upload` stores a web page as `raw`.** Cloudinary does not refuse
    HTML, it files it as a raw asset — verified, 1.1 MB of it. A source that
    lies about its content type would sail past step 1, so the resource type
    Cloudinary decided on is checked as well, and anything that is not `image`
    or `video` is refused.

**Verified against the real thing.** All five pins resolve to their
`i.pinimg.com` picture and import; the embed URL is refused with the message
that says what to do instead. The probe assets were deleted from Cloudinary
afterwards and the folder confirmed empty.

### Fetching a URL from our own server

This endpoint makes our server request an address a stranger chose, so it is
held to public addresses only. The check runs in the dialler's `Control` hook
— on the address actually resolved, not on the text of the URL — which is what
closes DNS rebinding: a hostname that resolves to `169.254.169.254` is refused
at connect time. Loopback, RFC1918, link-local and carrier NAT (`100.64/10`,
which `IsPrivate` does not cover) are all rejected, redirects are re-checked
per hop and capped at five, and only `https` is accepted. Covered by tests.

### Auto-detect and preview

The editor already had a live preview; it did not react to the URL field, and
the field had no idea what had been pasted into it. Now:

  * The preview updates as you type, trailing the field by 350 ms. Without the
    delay every keystroke in a URL is a different address, and each one starts
    and abandons a video request.
  * A line under the field says what the link is: *Clip — plays muted, loops,
    no sound* / *Animation — delivered as a clip, not as a GIF* / *Photo* /
    *Use a full https:// link*. The detection is `bannerKind()` from §7g, so
    the label and the rendering can never disagree.
  * A **Fetch** button next to it runs the import above, for a page — or for
    any link worth moving onto our own CDN.
  * Uploads use `pickMedia()`, so picking a GIF from disk still works.

### Eight themes, and a bug the eighth found

Five palettes added — Teal / Reef, Indigo / Iris, Berry / Blush, Marigold /
Maroon, Saffron / Amber — alongside Forest, Ink and Cacao. Every one was
measured before it was written: the headline clears 4.5:1 on its ground and
the button label clears 4.5:1 on the button, worst case 6.06:1.

Writing the test for those found a real defect in the **custom hex** path,
which predates this work. It chose text by a luminance threshold
(`luminance < .42` → white), and a threshold guesses wrong in the middle:
`#7F7F7F` took white text at **4.00:1**, under the floor. Worse, no choice
of white-or-ink saves every colour — `#A56F81` tops out at 4.05:1 either way.

So light grounds now keep their colour and take ink, and everything else is
deepened — hue intact — until white clears 4.5:1. It is a small move in
practice: `#7F7F7F → #757575`, `#FF0000 → #EB0000`, and light grounds such as
`#FDF6E3` are untouched at 15:1. A test sweeps **4,913 grounds across the whole
colour cube** and asserts every one is legible, and that fewer than half are
altered at all — so the guarantee is not bought by repainting everything.

`CampaignPalette` moved to `lib/widgets/campaign_palette.dart`. It is a palette
definition, and the colour ratchet exempts palette files rather than screens —
which let the ratchet **tighten from 69 literals to 60** and from 41 distinct
hex values to 35, instead of being raised to accommodate the new themes.

**Covered by** `remote_media_test.go` (9 tests: the private-address guard, the
https rule, direct media passthrough, og:image resolution, og:video preferred
over og:image, the megabyte-deep tag, a page that names nothing giving an
actionable message, a non-media type refused, and the `raw` guard),
`test/banner_theme_test.dart` (6, including the cube sweep) and
`test/campaign_editor_test.dart` (3: every theme offered, the detected line for
each kind, and Fetch enabling only with a link).

**Not done.** The admin panel itself was not driven in a browser — that needs a
sign-in, and I do not type passwords. The editor is covered by widget tests
instead, and the import path was proven end to end against the real Pinterest
and the real Cloudinary.

**Worth saying once:** most Pinterest images are somebody else's copyrighted
work. Importing one puts a copy on our CDN and a real shop's banner in front of
customers, which is a licensing question rather than a technical one. The
importer does not judge that; you do.

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

**Paste-a-link and banner themes (§7h):** `backend/remote_media.go` (new),
`backend/remote_media_test.go` (new), `backend/cloudinary.go`,
`backend/campaigns.go`, `backend/main.go`,
`lib/widgets/campaign_palette.dart` (new, moved out of `storefront.dart`),
`test/banner_theme_test.dart` (new), `test/campaign_editor_test.dart` (new),
`lib/screens/campaign_manager.dart`, `lib/data/api.dart`,
`lib/data/campaigns.dart`, `lib/widgets/photo_picker.dart`,
`test/palette_ratchet_test.dart`.

**Banner media (§7g):** `lib/widgets/banner_media.dart` (new),
`test/banner_media_test.dart` (new), `lib/data/catalog.dart`,
`lib/widgets/storefront.dart`, `lib/widgets/photo_picker.dart`,
`lib/data/api.dart`, `lib/screens/campaign_manager.dart`,
`backend/campaigns.go`, `backend/photos.go`, `backend/forms.go`,
`backend/cloudinary.go`.

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
