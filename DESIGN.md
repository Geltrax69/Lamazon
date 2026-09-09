# Lamazon UI system

Mobile-first refinement of the existing Flutter app. Preserve the lime accent,
charcoal ink, warm grey canvas and platform typography. The primary task is to
find local products, understand the offer and place a confirmed order.

- Canvas #F1F1EF, surface #FFFFFF, ink #1A1A1A, muted ink #62645E,
  accent #A6D544, success #1D4A3C, outline #DADDD4. Dark ink on lime buttons.
- Platform sans serif remains the UI face. Hierarchy: 28/24 page headings,
  20 section headings, 16 body, 14 labels, 12 supporting metadata.
- Spacing scale 4/8/12/16/20/24/32/48. Mobile page gutters 20; tablet 24;
  desktop 32. Card radius 16, controls 12. Minimum interactive size 48.
- Shopping content grows to 1400px. Two product columns on phones; additional
  columns on wider screens. Details and checkout split at 900px. Reading and
  account forms retain a readable 620px column.
- All bottom navigation destinations keep labels and selected states. Search
  and category browsing belong to Home. Desktop navigation spans the content.
- Product photography is authoritative seller content. Category artwork may
  use bundled generic still life imagery; never pass it off as merchandise.
- Real price/MRP only; no fabricated reviews, stock, availability or delivery
  times. Display unavailable information honestly or omit unsupported badges.
- Use native focusable buttons, semantic image labels, persistent input labels,
  keyboard focus, generous hit areas and reduced-motion-aware skeletons.
- Shared theme and widgets own recurring controls. Preserve authenticated
  workflows, atomic checkout, retry IDs, preferences and address integrity.
