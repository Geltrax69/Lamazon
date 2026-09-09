# Lamazon visual system

<!--
THESIS: Lamazon is a local-market discovery loop: one calm, art-directed
campaign gives way to visual categories, then real nearby products. It refuses
the rainbow-department dashboard and the endless stack of unrelated carousels.
OWN-WORLD: Deep forest, warm ivory and lime carry the brand; photography sits
on the same studio stage. Inter Tight and tactile, softly elevated controls
make browsing feel considered on a phone.
STORY: A shopper understands where their order is going, can search immediately,
then moves from a single meaningful edit into categories and real local stock.
FIRST VIEWPORT: Forest service header, prominent search, quick category strip,
and one editable 16:9 campaign with copy in its protected left field.
FORM: The mobile market-board form uses a dense, touchable discovery rhythm;
desktop expands that same board into an editorial grid instead of centering a
phone layout.
-->

## Purpose

Lamazon helps people discover nearby goods and complete a reliable local order.
The experience is mobile-first, yet supports spacious tablet and desktop browsing.
Product, cart, checkout and administration remain task-first and truthful.

## Color and materials

- `text` `#17221D` is primary copy; `muted` `#66716A` supports it; `strong`
  `#1D4939` carries icons and active states; `track` `#E1E5DD` is the only
  divider color.
- The base is warm ivory `#F7F6F0`; elevated surfaces are `#FFFDF8`. Deep
  forest `#143E32` owns service and campaign regions; lime `#C6EE63` marks
  action. Peach `#F58268` is reserved for sale attention.
- Campaigns use a named Forest/Lime, Cacao/Peach, or Ink/Mist preset. Text is
  always real UI text over a contrast scrim; uploaded imagery never decides the
  reading color or layout.
- Category artwork is one unbranded studio still-life family with shared camera
  height, warm floor, forest background and soft upper-left shadows. Seller
  product photography remains factual and is never replaced by this artwork.

## Typography and layout

- Inter Tight is the application face. Titles are 22/28 semi-bold with `-0.7`
  tracking; section titles are 19/24 semi-bold with `0.6`; body and day labels
  are 14.5/18 regular with `0.3`. Other display headlines use restrained
  negative tracking.
- Mobile gutters are 16px and grow to 24px at tablet, 32px at desktop. Content
  expands through a 1400px grid rather than retaining phone-width panels.
- Headings receive more space above than below. Product grids are two columns on
  phones and scale naturally through the available width.

## Components and interaction

- Cards use 12px, 16px or 18px radii based on depth, with a tight contact shadow
  and a broad ambient shadow; they do not use visible borders.
- Icon actions are tactile 40–44px circles with a soft inset highlight and
  layered drop shadow. Text actions use the same material at 46px tall.
- Dividers are 1px `track`. Focus uses a clear forest ring; all controls target
  at least 44px and retain labels, semantics and keyboard focus.
- Motion is short and purposeful: press feedback, deck paging, quick-add state,
  shared image transitions, and loading shimmer. Reduced motion stops animation.

## Responsive and truthful content rules

- The phone header makes delivery context and search immediately available. One
  primary campaign, visual category board, nearby collection, store row and
  product grid establish the browsing loop without repetitive shelves.
- Desktop uses the same hierarchy with a wider campaign and supporting discovery
  board. Navigation destinations, behavior and accessibility do not change.
- Never fabricate ratings, delivery timing, stock, price, seller facts or review
  counts. Show only data the application actually has.
