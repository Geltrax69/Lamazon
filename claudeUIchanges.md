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
