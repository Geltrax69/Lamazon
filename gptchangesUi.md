# gptchangesUi

What the previous agent (Codex/GPT) changed in the Lamazon UI before it ran out
of budget mid-edit, what it left unfinished, and what a QA pass on the home
screen found and fixed.

Branch: `codex/functionality-checkout`. Baseline for every diff below is commit
`349ad74 Redesign storefront with admin campaigns`.

---

## Part 1 — What GPT changed

### 1.1 The direction it replaced

The previous storefront gave every department its own colour, its own artwork
and its own themed shelf, stacked one after another down the home screen. GPT
threw that out and rewrote `DESIGN.md` around a single palette: deep forest,
warm ivory, one lime accent, with peach reserved for sale attention. Visual
variety is now supposed to come from the products and from one curated artwork
family, not from per-department colour.

### 1.2 Design tokens — `frontend/lib/widgets/design_system.dart`

The colour names were made semantic and the old ones kept as aliases so
un-migrated screens still compile:

| old | new | value |
|---|---|---|
| `ink` | `text` | `#17221D` |
| `muted` | `muted` | `#66716A` |
| `green` | `strong` | `#1D4939` |
| `line` | `track` | `#E1E5DD` |
| `canvas` | `canvas` | `#F7F6F0` (was `#F1F1EF`) |
| — | `surface` | `#FFFDF8` |
| — | `forest` | `#143E32` |
| `accent` | `lime` | `#C6EE63` (was `#A6D544`) |
| — | `peach` | `#F58268` |
| — | `danger` | `#B93643` |

The same tokens were mirrored as CSS custom properties in
`frontend/web/index.html` so the page background matches before Flutter boots.

### 1.3 Typography

Inter Tight was vendored as a variable font
(`frontend/assets/fonts/InterTight-Variable.ttf`, declared in `pubspec.yaml`)
and set as the app-wide `fontFamily`. The type scale matches the brief exactly:

- Titles — 22/28, semi-bold, `-0.7` tracking (`LamazonTheme.titleText`)
- Section headers — 19/24, semi-bold, `0.6` tracking (`sectionText`)
- Body / labels — 14.5/18, regular, `0.3` tracking (`bodyText`, `mutedBodyText`)

### 1.4 Surfaces, shadows, controls

Borders were removed as a structural device and replaced with layered shadows —
a tight contact shadow plus a broad ambient one (`surfaceShadows`,
`raisedShadows`, `tactileShadows`). Radii became depth-dependent:
`smallRadius` 12, `radius` 16, `featuredRadius` 18.

Four new shared widgets carry it:

- `ElevatedSurface` — shadow-led card, no visible outline, optional tap.
- `TactileIconButton` — 38–46px circle with a white top-left inset highlight
  over the base colour, plus the layered drop shadow. `ActionIcon` and
  `ScreenHeader`'s back button were re-pointed at it.
- `ActionButton` — the same material as a 46px-tall text action.
- `SectionHeading`, `TrackDivider` — one section header and one 1px `track`
  divider for every screen.

Input fields lost their borders entirely (`BorderSide.none`) and rely on fill +
a forest focus ring. Filled buttons went from lime-on-dark-text to
forest-on-white. Gutters became responsive: 16 / 24 / 32 at phone / 720 / 1200.

### 1.5 Campaigns — `frontend/lib/widgets/storefront.dart`

The biggest structural change. Previously an uploaded banner image decided its
own text colour by luminance, which is why banners drifted apart visually. GPT
replaced that with three named presets — **Forest/Lime**, **Cacao/Peach**,
**Ink/Mist** — resolved through `CampaignPalette.resolve()`, which also
translates the old pastel hex values onto the new family. A custom hex still
works, but the template derives readable foreground and action contrast itself.

Every banner now gets the same enforced treatment regardless of the image:
16:9-ish fixed height (230 phone / 348 wide), image pinned to the right, a
four-stop horizontal scrim, and the copy in a protected left field with a
category tag, title, subtitle and one CTA pill. An admin can no longer upload an
image that breaks the layout.

`CampaignDeck` kept manual paging with an expanding-dot indicator instead of
auto-rotation, and `CollectionShelf` was flattened so product cards no longer
sit as cards inside a second decorative card.

### 1.6 Home screen — `frontend/lib/screens/home_screen.dart`

Rewritten (~1886 lines changed). The repeated themed shelves are gone. The
order is now: forest service header (menu / brand / delivery address / account)
→ prominent search launcher → department strip → one campaign → visual category
board → "Around you" discount shelf → store rail → saved-for-later → product
grid → closing forest card with back-to-top. A `_BrowseDrawer` holds the full
department/category tree.

The auto-advancing store carousel was replaced by `_StoreRail`, a plain
horizontal list — a deliberate call, recorded in `DESIGN.md` as preferring the
shopper's reading pace over an auto-rotating banner.

### 1.7 Artwork

Two new bundled images: `category-atlas-v2.png` (the 4×2 sprite sheet
`CategoryVisual` slices for department tiles) and `campaign-forest.png` (the
default campaign backdrop). Both are one still-life family — shared camera
height, warm floor, forest background, soft upper-left shadow.

### 1.8 Navigation — `frontend/lib/widgets/app_nav.dart`, `main.dart`

`AppBottomNav` became a floating rounded bar with shadow instead of a full-width
white bar with a top border, and grew a peach cart badge. More importantly, it
stopped importing the four screens it opens: it now pushes named paths
(`AppRoutes.cart` / `.saved` / `.store` / `.account`) that `main.dart` resolves,
because the old arrangement was an import cycle that DDC could not link.

### 1.9 Other screens touched

`cart_screen`, `details_screen`, `order_confirmation_screen`, `admin_screen` and
`campaign_manager` were migrated onto the new tokens and components.
`campaign_manager` gained the palette-preset picker.

---

## Part 2 — Where GPT stopped

The session ended mid-edit. Left behind:

1. **`_CategoryBoard` was broken for every department except "All".** The whole
   entry list sat inside `if (activeTab == 0)`, so choosing Electronics (or any
   department) rendered the heading "Find your next thing" and its subtitle over
   an empty grid.
2. **`frontend/test/tmp_depth_test.dart`** — a scratch probe measuring widget
   tree depth, left in the test directory.
3. **Two failing tests** in `shop_carousel_test.dart`, still asserting the
   auto-advancing store `PageView` that GPT had deliberately replaced.
4. **A new import cycle**: `home_screen` → `profile_screen` → `login_screen` →
   `home_screen`, created by importing `ProfileScreen` for the account
   shortcut — the exact pattern GPT had just finished removing from `app_nav`.
5. **The migration is partial.** `login_screen`, `settings_screen`,
   `shop_screen` and `seller_dashboard_screen` still use the old palette, and
   two of them still hard-code `fontFamily: 'Georgia'`.

---

## Part 3 — QA pass on the home screen

Verified against a release web build at 375×812 (mobile) — the debug
`web-server` device cannot be used, see the note at the end.

### Fixed

| # | Finding | Fix |
|---|---|---|
| 1 | Empty category board on any department but "All" (Part 2.1) | Made the scoped branch a real `else` that lists the department's own categories; the board hides itself when a department has none. |
| 2 | "All" appeared as a tile inside "Shop by need", reusing Food's burger artwork verbatim — and made the grid 9 tiles, leaving an orphan row with one tile and a large gap | Dropped it. "All" is a filter, not a need. Eight departments now fill a clean 4×2. |
| 3 | Product images were different heights side by side. The image is `Expanded`, so a one-line product name handed its card a taller photo than the two-line card beside it | The name now always occupies two lines, so every card gives the picture the same leftover height. |
| 4 | `SectionHeading` rendered a "See all" text button *and* a circular arrow button beside it, both firing the same callback. The pair took enough width to wrap "Discover local favourites" onto two lines | One control: `See all →`. |
| 5 | The department strip's hover wash covered the whole 66×92 column including the label, reading as a grey slab rather than highlighting the 54px tile | Hover suppressed on that control; the press ripple stays. |
| 6 | Import cycle from Part 2.4 | `_AccountShortcut` pushes `AppRoutes.account` instead of importing `ProfileScreen`. |
| 7 | Two obsolete carousel tests + the scratch depth probe | Obsolete tests removed with the behaviour they guarded; the narrow-phone overflow guard kept. `tmp_depth_test.dart` deleted. |

### Reported, not fixed

- **The debug web target does not boot.** `flutter run -d web-server` dies with
  a `StackOverflowError` in DDC's `initializeAndLinkLibrary` while building
  `LoginScreen`. **This is pre-existing** — verified by stashing every change on
  this branch and reproducing it on `349ad74`. Release and profile builds are
  unaffected, so this is a local-development problem, not a shipping one.
- The migration is partial (Part 2.5). The login screen a shopper sees *first*
  is still on the old palette, which undercuts the rest of the work.
- "Around you" shows the same products that appear in the grid immediately
  below it, because both draw from the same small catalogue.
- Section headers and shelf headers still differ slightly: a section shows
  `See all →`, a shelf shows a bare circular arrow.

### Verification

- `flutter analyze` — no issues
- `flutter test` — 70 passed (was 68 passed / 2 failed)
- `flutter build web --release` — succeeds
- Home screen walked end to end at 375×812 on a release build

Backend untouched.
