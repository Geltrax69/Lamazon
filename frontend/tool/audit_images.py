#!/usr/bin/env python3
"""Report which product photographs are not catalogue quality.

A grid looks like a catalogue when the tiles agree. `catalogueImage()` in
`lib/data/catalog.dart` makes every tile the same centred, filled square,
which is most of the way there — but it cannot invent a photograph, and it
cannot turn a dark restaurant shot into a white packshot without Cloudinary's
paid background-removal add-on.

So this says what is actually wrong with each image, in the terms a person
can act on: shoot this one, re-upload that one, leave the rest alone.

    python3 tool/audit_images.py                  # against the live API
    python3 tool/audit_images.py http://localhost:8080

Exit code is 1 when anything needs attention, so CI can fail on it.
"""

import io
import json
import sys
import urllib.request
from collections import Counter

try:
    from PIL import Image
except ImportError:
    sys.exit("audit_images needs Pillow: pip install Pillow")

MARK = "/image/upload/"
# Small enough to be quick, large enough to judge. The audit reads the
# original, not the transform, because it is the source that has to be fixed.
PROBE = "c_limit,w_240,f_jpg,q_auto"

# A photograph uses thousands of distinct colours. Flat artwork — clipart, a
# logo, a plate-and-cutlery placeholder — uses tens. 900 sits in the empty
# space between the two, well clear of both.
FLAT_COLOURS = 900


def fetch(url, timeout=25):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read()


def probe(url):
    """The image as bytes, small, or None if it cannot be read."""
    try:
        return Image.open(
            io.BytesIO(fetch(url.replace(MARK, MARK + PROBE + "/")))
        ).convert("RGB")
    except Exception:
        return None


def verdict(image):
    """What is wrong with this picture, or None when nothing is."""
    width, height = image.size
    # None means more colours than the cap, which only a photograph reaches.
    colours = image.getcolors(maxcolors=1 << 24)
    if colours is not None:
        distinct = len({(r >> 3, g >> 3, b >> 3) for _, (r, g, b) in colours})
        if distinct < FLAT_COLOURS:
            return ("no photograph", f"flat artwork, {distinct} colours")

    edge = (
        [image.getpixel((x, 1)) for x in range(0, width, 4)]
        + [image.getpixel((x, height - 2)) for x in range(0, width, 4)]
        + [image.getpixel((1, y)) for y in range(0, height, 4)]
        + [image.getpixel((width - 2, y)) for y in range(0, height, 4)]
    )
    dark = sum(1 for p in edge if max(p) < 90) / len(edge)
    light = sum(1 for p in edge if min(p) > 232) / len(edge)

    if dark > 0.5:
        return ("dark background", f"{dark:.0%} of the border is near-black")
    if light > 0.6:
        return None  # already catalogue-ready
    return ("busy background", f"{light:.0%} light, {dark:.0%} dark border")


def main():
    base = (sys.argv[1] if len(sys.argv) > 1 else "https://api.geltrax.engineer").rstrip("/")
    try:
        products = json.loads(fetch(f"{base}/api/products"))
    except Exception as error:
        sys.exit(f"could not read {base}/api/products: {error}")

    findings = Counter()
    rows = []
    unreadable = []

    for product in products:
        url = (product.get("imageUrl") or "").strip()
        name = product.get("name", "?")
        store = product.get("store", "?")
        if not url:
            findings["no image at all"] += 1
            rows.append(("no image at all", store, name, "nothing uploaded"))
            continue
        image = probe(url)
        if image is None:
            unreadable.append((store, name))
            continue
        result = verdict(image)
        if result is None:
            findings["catalogue-ready"] += 1
            continue
        kind, detail = result
        findings[kind] += 1
        rows.append((kind, store, name, detail))

    total = len(products)
    ready = findings["catalogue-ready"]
    print(f"\n{total} product images\n")
    print(f"  catalogue-ready       {ready:3d}   {ready / max(total, 1):.0%}")
    for kind in ("no photograph", "dark background", "busy background", "no image at all"):
        if findings[kind]:
            print(f"  {kind:21} {findings[kind]:3d}")
    if unreadable:
        print(f"  could not be read     {len(unreadable):3d}")

    order = {"no photograph": 0, "no image at all": 1, "dark background": 2, "busy background": 3}
    rows.sort(key=lambda r: (order.get(r[0], 9), r[1], r[2]))
    if rows:
        print("\nNeeds attention, worst first:\n")
        current = None
        for kind, store, name, detail in rows:
            if kind != current:
                print(f"  {kind.upper()}")
                current = kind
            print(f"    {store[:18]:20} {name[:44]:46} {detail}")

    print(
        "\nA transform makes every tile the same square and centres what is in it."
        "\nIt cannot invent a photograph, and turning a dark restaurant shot into a"
        "\nwhite packshot needs Cloudinary's background-removal add-on, which is not"
        "\nenabled on this account. Everything above is a re-shoot or a re-upload.\n"
    )
    return 1 if rows or unreadable else 0


if __name__ == "__main__":
    raise SystemExit(main())
