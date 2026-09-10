# Claude UI Changes

Design and UX decisions, with the reasoning that produced them. Small CSS edits
are recorded only when they represent a system-level decision.

## 2026-09-10

### Section headings track negative, like every other heading

**Area:** design system — `LamazonTheme.sectionText` (every section header in the app)

**Decision:** IMPROVE

**Problem**
Section headers carried `letter-spacing: +0.6`. Titles use `-0.7` and the
typographic rule for this product is negative tracking on headings. One
heading level was tracking the wrong direction.

**Why it mattered**
At 19px semi-bold, positive tracking loosens a heading until it reads as a
label — the opposite of what a section header is for. "Shop by need", "Stores
near you" and "Discover local favourites" all sat slightly apart from the
titles above them for no reason a user could name, only feel. It is the kind
of inconsistency that makes an interface feel assembled rather than designed.

**Before**
Headings at two different levels tracked in opposite directions.

**Decision**
`-0.6`, matching the title scale's `-0.7`.

**Reasoning**
Fixed at the token rather than per screen. Every section header in the app
inherits `sectionText`, so one value corrects the home screen, both product
shelves, and every screen that adopts the system later. Patching call sites
would have left the next screen free to get it wrong again.

**Change**
`letterSpacing: 0.6` → `-0.6` in `sectionText`.

**Files**
- `frontend/lib/widgets/design_system.dart`

**Verification**
- [x] Visual
- [x] Responsive — tracking is size-independent
- [x] Functional — no behaviour touched
- [x] Accessibility — no contrast or semantic change
- [x] Regression — analyze clean, 70 tests pass

**Result**
Headings read as one family. Section headers now sit compact and intentional
against the titles above them.

**Remaining**
The brief given on 2026-09-10 03:49 specifies `-0.6px`, superseding an earlier
instruction that read `0.6px`. Recorded here because the value was implemented
faithfully to the original brief and changed deliberately, not by accident.

### The first screen joins the design system

**Area:** `LoginScreen` — the screen every new user sees before anything else

**Decision:** REPLACE (presentation only; no auth logic touched)

**Problem**
The redesign stopped at the shopping surfaces. Login still ran on its own
palette — six hard-coded colours including a cool blue-grey canvas `#F7F9FC`
against the app's warm ivory `#F7F6F0` — its own hand-rolled input, its own
flat button, and typography set by hand with no tracking.

**Why it mattered**
This is the first impression, and the colour temperature visibly jumps the
moment a shopper enters the shop. A product whose entrance belongs to a
different design than its interior does not read as premium; it reads as
half-finished. It also meant the screen could not inherit any later
improvement to the system.

**Before**
Cool blue-grey screen, white card, grey inset field with an underline focus
ring inside a rounded box, a flat near-black button, 11.5px helper text, and
policy links that were bare `GestureDetector`s.

**Decision**
Rebuilt the presentation on tokens and shared components. Every auth code
path — `_start`, `_verifyCode`, `_verifyPassword`, `_go` — is untouched.

**Reasoning**
Four things were solved by deletion rather than restyling:

- The input was ~40 lines re-implementing what `inputDecorationTheme` already
  provides. Replaced with a themed `TextField` and a `prefixIcon`. The
  underline focus ring inside a rounded container was incoherent anyway; the
  system's forest ring is one shape.
- The submit button read `backgroundColor: _valid ? _ink : _yellow`, but the
  button is disabled whenever `!_valid`, so `disabledBackgroundColor` always
  won and the yellow branch could never render. Dead styling, and the last
  thing keeping the logo-yellow constant alive. Both removed.
- The card was a hand-rolled `Container` with its own shadow. It is an
  `ElevatedSurface` now, so it tracks the system's elevation.
- The helper line showed "Enter a valid email address to continue." before the
  user had typed a single character — telling somebody they are wrong before
  they have done anything. It now waits until the field is non-empty, and
  shows the reassurance line until then.

**Change**
Tokens throughout; `sectionText` for the card heading; title scale with `-0.9`
tracking for the tagline; themed input; `ActionButton` for both actions;
`danger` for errors; helper text 11.5px → 13px; marquee tile placeholder from
cool blue `#EAF4FB` to `track`.

**Files**
- `frontend/lib/screens/login_screen.dart`
- `frontend/lib/widgets/image_marquee.dart`

**Verification**
- [x] Visual — profile web build at 375×812
- [x] Responsive — `ReadableBody(maxWidth: 440)` retained
- [x] Functional — all three sign-in paths and Skip login unchanged
- [x] Accessibility — see Result
- [x] Regression — analyze clean, 70 tests pass

**Result**
The entrance and the shop are now one product; the colour temperature no
longer jumps. Accessibility improved in three places: the policy links are
real buttons, so they take keyboard focus, announce themselves as controls and
carry a 44px target instead of a ~14px text hitbox on legally-significant
links; the helper line is a live region, so a screen reader announces failures
instead of leaving them silent; and error text went from 11.5px to 13px.

**Remaining**
- The disabled primary button is the system's `Opacity(.5)`, which puts white
  text on a washed forest at roughly 2.3:1. WCAG 1.4.3 exempts inactive
  controls, and the treatment is shared app-wide, so changing it is a
  system-level decision rather than a login one.
- The marquee animates continuously and is the screen's largest element. It
  honours reduced motion, but its value is worth testing against its cost.
- `settings_screen`, `shop_screen` and `seller_dashboard_screen` are still off
  the system; two of them hard-code `fontFamily: 'Georgia'`.

### Store names stop rendering as a different font per platform

**Area:** `ShopScreen`, `SellerDashboardScreen` — store name headings

**Decision:** REPLACE

**Problem**
Both screens set `fontFamily: 'Georgia'` on the store name. `pubspec.yaml`
declares exactly one font family, `InterTight`. Georgia is not bundled.

**Why it mattered**
This is not a token preference, it is a rendering bug. Georgia is a system
font on iOS and macOS and absent on Android and most web contexts, so the
store name came out serif on some devices and fell back to the default sans on
others. The same screen looked like two different designs depending on who
opened it — and a shop's own name is the most identity-carrying text on it.

**Before**
`fontSize: 22` / `fontSize: 24`, `fontFamily: 'Georgia'`, `w600`, no tracking,
two arbitrary sizes for the same semantic element.

**Decision**
`LamazonTheme.titleText` on both.

**Reasoning**
A store name is the page title of that screen, which is what the title token
is for. Using it also collapses the two arbitrary sizes into one and picks up
the `-0.7` tracking, so a store name now reads like every other title in the
app instead of like a leftover from a different design.

**Change**
Two hand-written `TextStyle`s replaced by the token. Last `Georgia` reference
in the codebase.

**Files**
- `frontend/lib/screens/shop_screen.dart`
- `frontend/lib/screens/seller_dashboard_screen.dart`

**Verification**
- [x] Visual
- [x] Responsive — no layout dependency on the old sizes
- [x] Functional — text only
- [x] Accessibility — no contrast change; size stays well above minimum
- [x] Regression — analyze clean, 70 tests pass

**Result**
Store names render identically on every platform, at the app's title scale.

**Remaining**
Roughly 200 hard-coded hex colours remain across ~20 screens, concentrated in
`compare_screen`, `admin_screen`, `seller_dashboard_screen`, `profile_screen`
and `location_screen`. That is a migration, not a fix, and is best done a
screen at a time behind visual checks rather than by find-and-replace.

### A card stops swallowing everything inside it

**Area:** design system — `ElevatedSurface`, `ActionButton`, `TactileIconButton`
(23 call sites; every card and every action in the app)

**Decision:** IMPROVE (root cause, found by reading the accessibility tree
rather than the screenshot)

**Problem**
Two separate defects, both invisible on screen:

1. `ElevatedSurface` wrapped its child in `Semantics(button: onTap != null,
   label: semanticLabel)` unconditionally. `button: false` is still an
   annotation, so a passive card collapsed its whole subtree into one node.
2. `ActionButton` carried no semantics of its own. Its button role came from
   `InkWell`, and an `InkWell` with `onTap: null` has none — so a disabled
   action vanished from the tree as ordinary text.

**Why it mattered**
On the sign-in card, the first defect produced a single node reading
`textbox "Log in or sign up Email address Continue We only use your email for
order updates and receipts."` — a screen reader announced the heading, the
field, the button and the helper text as one text field, and the Continue
button was not a button. The second meant that once Continue *was* separated
out, it still disappeared whenever it was disabled: a blind user could not
tell there was an action waiting for valid input. `EmptyState` and the home
screen's "Nothing here" panel had the first defect too — both are passive
cards containing a real button.

**Before**
The sign-in card was one text field to assistive technology. Disabled actions
were invisible as controls.

**Decision**
A card that is only a card annotates nothing. A button says it is a button and
whether it is enabled.

**Reasoning**
Fixed in the two shared components rather than at any call site. The bug was
not on the login screen, it was in what the login screen used — and it was
already affecting `EmptyState`, `_NothingHere` and every disabled quick-add
button. `ProductCard` deliberately passes both `onTap` and `semanticLabel`, so
it still merges into one "product name, button" node, which is what a card
that behaves as a single control should do.

**Change**
- `ElevatedSurface` returns its unannotated surface when it has no `onTap` and
  no `semanticLabel`.
- `ActionButton` wraps in `Semantics(button: true, enabled: onPressed != null)`.
- `TactileIconButton` gained the same `enabled` flag.

**Files**
- `frontend/lib/widgets/design_system.dart`

**Verification**
- [x] Visual — no pixel change; verified the card renders identically
- [x] Responsive — no layout involvement
- [x] Functional — 70 tests pass
- [x] Accessibility — accessibility tree read before and after, see Result
- [x] Regression — analyze clean

**Result**
Before: `textbox "Log in or sign up Email address Continue We only use your
email for order updates and receipts."`

After:
```
button   "Skip login"
generic  "Log in or sign up"
textbox  "Email address"
button   "Continue"
generic  "We only use your email for order updates and receipts."
button   "Terms and Conditions"
button   "Privacy Policy"
```

**Remaining**
`generic` is the tree's rendering of an unroled text node. "Log in or sign up"
would be better exposed as a heading; Flutter's web semantics does not emit
heading levels from `Semantics(header: true)` in a way this reader surfaces,
so it is left as-is rather than faked.

### The checkout button stops promising an order it will refuse

**Area:** `CartScreen` — `_CheckoutPanel`, the primary conversion action

**Decision:** IMPROVE

**Problem**
"Place order · ₹3613" was rendered at full primary emphasis for everyone,
including guests. `_placeOrder` then checked `Session.instance.loggedIn`,
showed a four-second snackbar — "Sign in first — an order has to belong to
someone." — and returned. Nothing else on the screen said an account was
needed.

**Why it mattered**
Skip login is on the very first screen, so shopping as a guest is a normal
path, not an edge case. Such a shopper can browse, fill a cart, add a delivery
address, and press the largest and most committed button in the app — and get
a toast that disappears. It is a dead end at the exact moment the product asks
for trust, and the requirement is invisible until the user has already failed.

The screen was also inconsistent with itself: the *address* requirement is
stated plainly in the delivery card ("Choose a delivery address before placing
your order") and tapping through actually navigates to the address screen. Only
sign-in behaved as a hidden trapdoor.

**Before**
Guest presses "Place order · ₹3613" → snackbar → nothing happens.

**Decision**
For a signed-out shopper the button reads "Sign in to place order" and goes to
sign-in. Signed in, it is unchanged.

**Reasoning**
Considered and rejected: adding a "you need an account" notice above the
button. That solves it by adding UI, and the button would still be lying until
the user read the notice. Relabelling costs nothing, cannot be missed, and
turns a refusal into the step the shopper actually asked for.

The amount is deliberately dropped from the guest label. For a guest the
button is navigation, not payment, and pricing a navigation step is the same
false promise in smaller type. The total stays visible in the Total row
directly above it, which is where the two existing tests were really getting
their assurance from.

Routed by name (`AppRoutes.login`) rather than by importing `LoginScreen`,
because that import would close a cycle back through home — the same trap that
had already caught the bottom bar and the account shortcut.

**Change**
- `AppRoutes.login` added and registered in `main.dart`.
- The action is wrapped in a `ListenableBuilder` on `Session.instance`, since
  the panel previously only rebuilt on cart changes and would not have noticed
  a sign-in.
- The signed-out branch of `_placeOrder` navigates instead of toasting.

**Files**
- `frontend/lib/screens/cart_screen.dart`
- `frontend/lib/widgets/app_nav.dart`
- `frontend/lib/main.dart`
- `frontend/test/smoke_test.dart`, `frontend/test/ui_redesign_test.dart`

**Verification**
- [x] Functional — 70 tests pass; two updated to cover the guest label
- [x] Responsive — label is single-line with ellipsis; 320/390/800/1400 with
      1.3 text scale all pass
- [x] Accessibility — `ActionButton` now reports button role and enabled state
- [x] Regression — analyze clean
- [ ] Visual — not re-checked in browser this round, see note below

**Result**
The primary action always describes what it will actually do.

**Remaining**
Two near-identical quantity steppers exist — `_QtyStepper` in details and
`_QtyControls` in cart. They behave differently at qty 1 on purpose (details
disables minus, cart turns it into remove), which is correct for their
contexts, so they were left alone rather than merged behind a mode flag.

### The purchase path moves onto the tokens

**Area:** `CartScreen`, `DetailsScreen`

**Decision:** SIMPLIFY

**Problem**
Twelve hard-coded colours across the two screens a shopper must pass through
to spend money, including two private constants (`_ink`, `_green`) shadowing
tokens that already existed, Material's `#D32F2F` and `#2E7D32` for
error/success, and the pre-redesign canvas `#F1F1EF`.

**Why it mattered**
These are the screens where a product has to look most trustworthy. Off-system
reds and greens read as belonging to a different application, and the private
constants meant the checkout could drift away from the rest of the app any time
a token changed.

**Decision**
All twelve onto tokens. The swipe-to-delete tint is now derived from the token
(`danger` at 14% alpha) rather than being an independent pink, so the tint and
the icon on top of it cannot drift apart.

**Change**
`_ink` → `text`, `_green` → `strong`, `#D32F2F` → `danger`, `#2E7D32` →
`strong`, `#62645E`/`#6B6B6B` → `muted`, `#F1F1EF` → `track`,
`#F8D7DA` → `danger` at 14%.

**Files**
- `frontend/lib/screens/cart_screen.dart`
- `frontend/lib/screens/details_screen.dart`

**Verification**
- [x] Functional — 70 tests pass
- [x] Regression — analyze clean; no hard-coded hex left on the purchase path
- [ ] Visual — not re-checked in browser this round, see note below

**Result**
Zero hard-coded colours remain in cart, details or order confirmation.

**Remaining**
Browser input stopped responding partway through this session — screenshots and
the accessibility tree still read correctly, but clicks no longer register, so
the cart and details screens could not be walked visually after these edits.
The changes are colour-token substitutions and one label, all covered by the
suite, but they have not been seen on screen. Worth a look before release.

### The department board stops repeating the strip above it

**Area:** `HomeScreen` — `_DepartmentStrip` and `_CategoryBoard`

**Decision:** REMOVE (at "All") / MOVE (to a level down)

**Problem**
Home listed the same eight departments twice. The strip under the search bar
showed All, Electronics, Food, Gifts, Beauty… and roughly 300px further down,
"Shop by need" showed Electronics, Food, Gifts, Beauty… — the same
destinations, the same artwork, and the same action (`onSelectDepartment`),
drawn twice in two sizes.

**Why it mattered**
Raised by the user, and correctly: "what's its point?" Two controls that do
the identical thing do not read as two ways in, they read as a mistake — the
shopper stops to work out what the difference is, finds none, and trusts the
page a little less. It also cost roughly 320px, about 40% of a phone viewport,
before the first product. And it was worse than redundant: the strip carries a
selected state, the board did not, so the page showed the same list twice with
only one of them admitting which item was active.

Worth noting this survived my own earlier pass. I applied the removal-first
test to the "All" tile inside the board and never asked it of the board.

**Before**
Strip: All · Electronics · Food · Gifts · Beauty · … (horizontal, stateful)
Board: Electronics · Food · Gifts · Beauty · Household Essentials · … (grid)

**Decision**
The strip keeps the departments. The board drops to the level below and shows
only the categories inside the chosen department. At "All" — which has no
categories, by definition, being the absence of a filter — it renders nothing.

**Reasoning**
The strip has to stay: it is persistent, compact, shows which department is
active, and is the only way back out to another department without the drawer.
Deleting it and keeping the board would have stranded a scoped shopper, since
the board shows categories once scoped.

That left the question of whether the board earns anything. It does, but only
one level down. The live API shows departments carry real shelves with the
shop's own uploaded artwork — Electronics holds Mobile Accessories, Chargers &
Cables, Earphones, Smart Gadgets, Batteries. Those are content the strip
cannot show and the shopper cannot otherwise reach except through the drawer.
So the board became the drill-down it should always have been, and the home
screen gained a real hierarchy: department in the strip, shelf in the board,
product in the grid.

Copy was rewritten with it. "Every department, one calm visual system"
described the design rather than telling anyone what the tiles do.

**Change**
- `_CategoryBoard` lists `active.categories` only, and hides itself when a
  department has none.
- Heading → "Browse by category" / "Narrow {Department} down to one shelf".
- `_CategoryEntry.departmentIndex`, the `onSelectDepartment` branch in the
  tile's tap handler, and the board's `onSelectDepartment` parameter are all
  dead once the board stops selecting departments, and are removed.
- The 34px spacer moves inside the conditional, so a hidden board does not
  leave a 68px hole.

**Files**
- `frontend/lib/screens/home_screen.dart`
- `frontend/test/smoke_test.dart`

**Verification**
- [x] Functional — 70 tests pass
- [x] Regression — analyze clean; no dead parameters left
- [ ] Visual — browser input is not responding this session, see note

**Result**
Every department appears once. The default home screen is ~320px shorter, so
products arrive sooner. Choosing a department now reveals something new rather
than re-showing what was already on screen.

**Remaining**
- The strip shows about five of eight departments at 375px; the rest need a
  horizontal scroll. Acceptable for a learned pattern, and the drawer holds
  the full tree, but worth watching whether the hidden three get traffic.
- `smoke_test`'s "every See all opens something" had to scroll further before
  tapping: the shorter page left that control underneath the floating bottom
  bar, and a tap there hits the bar. That is inherent to a floating bar rather
  than a defect, but it is a real thing a thumb can hit too.
