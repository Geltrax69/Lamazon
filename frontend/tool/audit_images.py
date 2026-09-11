#!/usr/bin/env python3
"""Audit every product image in the catalogue, and fail when they are not good enough.

`catalogueImage()` in `lib/data/catalog.dart` makes every card the same
centred, filled square. That is framing, and framing is the only part of this
a transform can fix. It cannot invent a photograph, it cannot remove a
watermark, and it cannot raise the resolution of a 200px thumbnail.

So this reports what is actually wrong with each source image, in terms
somebody can act on, and exits non-zero when anything fails — which is what
makes it a gate rather than a report.

    python3 tool/audit_images.py                      # the live API
    python3 tool/audit_images.py http://localhost:8080
    python3 tool/audit_images.py --sheet out.jpg      # also write a contact sheet
    python3 tool/audit_images.py --json               # machine-readable

Watermark detection shells out to `tesseract` when it is installed, and says
so loudly when it is not — a check that silently does nothing is worse than
one that admits it did not run.
"""

import argparse
import io
import json
import subprocess
import sys
import urllib.request
from collections import Counter, defaultdict

try:
    from PIL import Image
except ImportError:
    sys.exit("audit_images needs Pillow:  pip install Pillow")

MARK = "/image/upload/"

# Small enough to be quick over a whole catalogue, large enough to judge
# colour and background from. The audit reads the *source*, never the
# catalogue transform: it is the source that has to be fixed.
PROBE = "c_limit,w_320,f_jpg,q_auto"

# --- thresholds, all of them arguable and all of them written down ---------

# A photograph uses thousands of distinct colours; clipart, a logo or a
# plate-and-cutlery placeholder uses tens. 900 sits in the empty space between
# the two populations, well clear of both.
FLAT_COLOURS = 900

# Below this on the short side a product fills a 400px card visibly soft.
# Phone cameras have not shot this small in fifteen years, so anything under
# it is a screenshot or a thumbnail somebody found.
MIN_SHORT_SIDE = 500

# Above this fraction of near-black border the subject is lit against a dark
# ground — good photography, wrong beside a white packshot in a grid.
DARK_BORDER = 0.50

# Below this fraction of light border, with no dark verdict either, the
# background is doing something: a table, a tray, a kitchen.
LIGHT_BORDER = 0.60

# Hamming distance between perceptual hashes under which two images are the
# same picture. 0 is identical after downscaling; 5 survives a re-crop.
DUPLICATE_DISTANCE = 5

# Text that only appears on an image somebody took from a recipe site.
WATERMARK_HINTS = (
    ".com", ".in ", ".net", ".org", "www.", "http",
    "recipe", "copyright", "shutterstock", "istock", "getty",
    "alamy", "dreamstime", "123rf", "depositphotos", "watermark",
)

SEVERITY = {
    "broken": 0,
    "no photograph": 1,
    "watermarked": 2,
    "too low resolution": 3,
    "duplicate": 4,
    "dark background": 5,
    "busy background": 6,
}

# Framing is fixed by the transform. Everything else needs a person: a camera,
# a licence, or a different file.
FIXABLE_BY_FRAMING = {"dark background", "busy background"}


def fetch(url, timeout=25):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read()


def transform(url, spec):
    return url.replace(MARK, MARK + spec + "/") if MARK in url else url


def source_size(url):
    """Original width and height, without downloading the original."""
    try:
        info = json.loads(fetch(transform(url, "fl_getinfo")))
        return info["input"]["width"], info["input"]["height"]
    except Exception:
        return None


def dhash(image, size=8):
    """A perceptual hash: is this the same picture, not the same bytes."""
    small = image.convert("L").resize((size + 1, size), Image.LANCZOS)
    bits = 0
    for y in range(size):
        for x in range(size):
            bits = (bits << 1) | (small.getpixel((x, y)) > small.getpixel((x + 1, y)))
    return bits


def has_tesseract():
    try:
        subprocess.run(
            ["tesseract", "--version"], capture_output=True, check=True, timeout=10
        )
        return True
    except Exception:
        return False


def read_text(png_bytes):
    """Whatever tesseract can read, lowercased. Empty when it reads nothing."""
    try:
        done = subprocess.run(
            ["tesseract", "stdin", "stdout", "--psm", "11"],
            input=png_bytes, capture_output=True, timeout=40,
        )
        return done.stdout.decode("utf-8", "ignore").lower()
    except Exception:
        return ""


def border_profile(image):
    width, height = image.size
    step = max(1, width // 60)
    edge = (
        [image.getpixel((x, 1)) for x in range(0, width, step)]
        + [image.getpixel((x, height - 2)) for x in range(0, width, step)]
        + [image.getpixel((1, y)) for y in range(0, height, step)]
        + [image.getpixel((width - 2, y)) for y in range(0, height, step)]
    )
    dark = sum(1 for p in edge if max(p) < 90) / len(edge)
    light = sum(1 for p in edge if min(p) > 232) / len(edge)
    return light, dark


def inspect(url, ocr):
    """Everything wrong with one image, and its perceptual hash."""
    faults = []
    try:
        raw = fetch(transform(url, PROBE))
        image = Image.open(io.BytesIO(raw)).convert("RGB")
    except Exception as error:
        reason = getattr(error, "code", None) or type(error).__name__
        return [("broken", f"cannot be fetched ({reason})")], None

    colours = image.getcolors(maxcolors=1 << 24)
    flat = False
    if colours is not None:
        distinct = len({(r >> 3, g >> 3, b >> 3) for _, (r, g, b) in colours})
        if distinct < FLAT_COLOURS:
            flat = True
            faults.append(("no photograph", f"flat artwork, {distinct} colours"))

    size = source_size(url)
    if size and min(size) < MIN_SHORT_SIDE:
        faults.append(("too low resolution", f"source is {size[0]}x{size[1]}"))

    if ocr:
        # A larger, lossless render: tesseract reads small type badly out of a
        # 320px JPEG, which is exactly the size a watermark tends to be.
        try:
            text = read_text(fetch(transform(url, "c_limit,w_1000,f_png")))
        except Exception:
            text = ""
        hit = next((w for w in WATERMARK_HINTS if w in text), None)
        if hit:
            snippet = " ".join(text.split())[:50]
            faults.append(("watermarked", f'reads "{snippet}"'))

    # Background only means anything on something that is a photograph.
    if not flat:
        light, dark = border_profile(image)
        if dark > DARK_BORDER:
            faults.append(("dark background", f"{dark:.0%} near-black border"))
        elif light < LIGHT_BORDER:
            faults.append(
                ("busy background", f"{light:.0%} light, {dark:.0%} dark border")
            )

    return faults, dhash(image)


def contact_sheet(products, path, spec, cols=6, tile=190):
    """The grid as a shopper sees it, so the framing can be judged by eye."""
    rows = (len(products) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * tile, rows * tile), (247, 246, 240))
    for i, product in enumerate(products):
        url = (product.get("imageUrl") or "").strip()
        try:
            cell = Image.open(io.BytesIO(fetch(transform(url, spec)))).convert("RGB")
            cell = cell.resize((tile, tile))
        except Exception:
            cell = Image.new("RGB", (tile, tile), (225, 229, 221))
        canvas.paste(cell, ((i % cols) * tile, (i // cols) * tile))
    canvas.save(path, quality=88)
    return path


# Every image bundled into the app ships on the first paint, before anything
# is on screen, so their combined weight is the one asset number a shopper on
# mobile data actually feels. 400 KB is what the current two WebPs need with
# room for one more. Lower it as assets shrink; never raise it to pass a build.
BUNDLE_BUDGET = 400 * 1024


def audit_bundle(root="assets"):
    """Weigh what the app bundles, and fail when it outgrows its budget."""
    import pathlib

    files = sorted(
        f for f in pathlib.Path(root).rglob("*")
        if f.is_file() and f.suffix.lower() not in {".ttf", ".otf", ".yaml"}
    )
    total = sum(f.stat().st_size for f in files)
    print(f"bundled artwork — {total / 1024:.0f} KB of {BUNDLE_BUDGET / 1024:.0f} KB")
    failed = total > BUNDLE_BUDGET
    for f in files:
        size = f.stat().st_size
        heavy = f.suffix.lower() == ".png" and size > 200 * 1024
        failed = failed or heavy
        note = "  <- a photograph in PNG; convert to WebP" if heavy else ""
        print(f"  {size / 1024:7.0f} KB  {f}{note}")
    if failed:
        print("\nover budget. Convert photographs to WebP at q82:")
        print("  python3 -c \"from PIL import Image; im=Image.open('x.png');"
              " im.convert('RGB').save('x.webp','WEBP',quality=82,method=6)\"")
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(
        description="Audit product images and fail when they are not catalogue quality."
    )
    parser.add_argument("api", nargs="?", default="https://api.geltrax.engineer")
    parser.add_argument("--sheet", metavar="FILE", help="write a contact sheet")
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--no-ocr", action="store_true", help="skip watermark detection")
    parser.add_argument(
        "--bundle",
        action="store_true",
        help="weigh the assets bundled into the app instead of the catalogue",
    )
    args = parser.parse_args()

    if args.bundle:
        sys.exit(audit_bundle())

    base = args.api.rstrip("/")
    try:
        products = json.loads(fetch(f"{base}/api/products"))
    except Exception as error:
        sys.exit(f"could not read {base}/api/products: {error}")

    ocr = not args.no_ocr and has_tesseract()
    why_no_ocr = (
        "" if ocr
        else "   (watermark check off: --no-ocr)" if args.no_ocr
        else "   (watermark check SKIPPED: tesseract not installed)"
    )

    # Keyed by id, not by name: this catalogue has two products both called
    # "Red Sauce Pasta", and keying by name merged their findings into one row
    # that reported the same fault twice.
    faults_by_id = defaultdict(list)
    label = {}
    hashes = defaultdict(list)

    for product in products:
        key = product.get("id") or product.get("name", "?")
        label[key] = (product.get("store", "?"), product.get("name", "?"))
        url = (product.get("imageUrl") or "").strip()
        if not url:
            faults_by_id[key].append(("broken", "no image uploaded"))
            continue
        faults, digest = inspect(url, ocr)
        if digest is not None:
            hashes[digest].append(key)
        faults_by_id[key].extend(faults)

    # Duplication is a property of the set, not of any one image, so it is
    # decided after every image has been hashed. The first name in sorted
    # order keeps the picture; the rest are told whose it is.
    groups = []
    buckets = sorted(hashes.items(), key=lambda kv: kv[0])
    claimed = set()
    for digest, keys in buckets:
        if digest in claimed:
            continue
        group = list(keys)
        for other_digest, other_keys in buckets:
            if other_digest == digest or other_digest in claimed:
                continue
            if bin(digest ^ other_digest).count("1") <= DUPLICATE_DISTANCE:
                group.extend(other_keys)
                claimed.add(other_digest)
        claimed.add(digest)
        if len(group) > 1:
            groups.append(sorted(group, key=lambda k: label[k][1]))

    for group in groups:
        keeper = label[group[0]][1]
        for key in group[1:]:
            faults_by_id[key].append(
                ("duplicate", f'same picture as "{keeper}"')
            )

    findings = [
        (label[key][0], label[key][1], faults)
        for key, faults in faults_by_id.items() if faults
    ]
    counts = Counter(kind for _, _, faults in findings for kind, _ in faults)
    clean = len(products) - len(findings)

    if args.as_json:
        print(json.dumps({
            "total": len(products),
            "clean": clean,
            "ocr": ocr,
            "counts": dict(counts),
            "products": [
                {
                    "store": store,
                    "name": name,
                    "faults": [{"kind": k, "detail": d} for k, d in faults],
                    "needsAPerson": any(
                        k not in FIXABLE_BY_FRAMING for k, _ in faults
                    ),
                }
                for store, name, faults in findings
            ],
        }, indent=2))
    else:
        print(f"\n{len(products)} product images{why_no_ocr}\n")
        print(f"  pass every rule        {clean:3d}   "
              f"{clean / max(len(products), 1):.0%}")
        for kind, _ in sorted(SEVERITY.items(), key=lambda kv: kv[1]):
            if counts[kind]:
                mark = " " if kind in FIXABLE_BY_FRAMING else "*"
                print(f" {mark}{kind:21} {counts[kind]:3d}")
        print("\n  * needs a person: a camera, a licence, or a different file."
              "\n    the rest is framing, which catalogueImage() already handles.\n")

        findings.sort(
            key=lambda f: (min(SEVERITY.get(k, 9) for k, _ in f[2]), f[0], f[1])
        )
        current = None
        for store, name, faults in findings:
            worst = min(faults, key=lambda f: SEVERITY.get(f[0], 9))[0]
            if worst != current:
                print(f"  {worst.upper()}")
                current = worst
            detail = "; ".join(d for _, d in faults)
            print(f"    {store[:16]:18} {name[:40]:42} {detail[:58]}")

    if args.sheet:
        print(f"\ncontact sheet: {contact_sheet(products, args.sheet, 'c_fill,ar_1:1,g_auto,e_improve:30,w_300,f_auto,q_auto')}")

    # Non-zero when anything fails, so this can gate a deploy.
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
