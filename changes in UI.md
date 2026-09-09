# Changes in UI

## Direction

Make Lamazon feel like a lively local marketplace, with smartphone shopping as
the primary experience. Keep the lime identity and readable native typography;
give departments their own colour, photography and voice.

Inspired by the supplied Blinkit screenshot's category discovery and changing
campaigns, [posts.design](https://posts.design)'s campaign compositions,
[loadmo.re](https://loadmo.re)'s mobile layouts and
[60fps.design](https://60fps.design)'s short interaction animations.

## What changed, and why

| Change | Why |
|---|---|
| Campaign-led home with new shopping artwork | Give the opening screen a memorable focal point. |
| Picture-based department grid and themed category pages | Make browsing visual and give every department a distinct mood. |
| Discount shelves, saved finds and department collections | Offer useful next steps throughout browsing, using actual catalogue data. |
| Admin → Banners: create, preview, edit, publish/hide, order and delete | Let staff change campaigns without another app release. |
| Banner image upload, text, colour and category destination | Make campaigns reusable for different occasions and departments. |
| Short category/collection transitions and manual banner paging | Add quick feedback while keeping content easy to read; respect reduced motion. |
| Consistent labelled navigation, prominent search, accessible controls | Make the next action obvious and comfortable on a phone. |
| Product cards with real imagery, stronger prices, real discounts and stock | Help shoppers judge the product before opening it. |
| Larger product galleries and sticky purchase actions | Keep the product and the main action easy to reach. |
| Clearer cart, address, COD payment and order summary | Reduce uncertainty before placing an order. |
| Confirmation screen with actual order numbers and tracking links | Make successful checkout unmistakable. |
| Loading skeletons and useful empty-state actions | Keep loading and empty screens understandable. |
| Wider desktop grids, split product/cart layouts and responsive store cards | Use larger screens naturally. |
| Admin search, status/date filters, pagination and CSV export | Make routine operations easier as records grow. |
| Shared theme, components, touch targets and focus states | Keep screens consistent and usable with touch or keyboard. |

Generic campaign/category artwork is illustrative. Product photos remain the
seller's actual merchandise. Reviews, delivery times and promotional claims are
never invented. Existing checkout integrity and account fixes are preserved.

## Validation / release

Implementation is being checked with Flutter widget tests, Go integration tests
against isolated PostgreSQL, release builds and browser viewport checks.
Changes are being prepared on `codex/functionality-checkout`, PR #1; this file
will record final verification before the batch is pushed. Production rollout
still needs coordinated API, web and installed-app updates.
