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
