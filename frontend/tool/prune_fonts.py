#!/usr/bin/env python3
"""Drop icon-font weights the app never uses from a built web bundle.

lucide_icons_flutter declares seven font families. `LucideIcons.house` and the
95 other icons this app names all resolve to family `Lucide` (lucide.ttf); the
six `Lucide100`-`Lucide600` variable weights only back the numbered constants
(`LucideIcons.house100`), which nothing here calls. Flutter fetches every
family in FontManifest.json eagerly on first paint, so all six shipped anyway
— about 2.5 MB of a 7 MB cold load, on a mobile-first product built for Indian
campus data.

Tree-shaking cannot remove them: it prunes glyphs inside a font that no
IconData references, and these fonts are referenced by IconData constants that
merely happen to be unreachable. The alternative is vendoring the package to
edit its pubspec, which means committing a 12 MB generated Dart file to save
2.5 MB of download. This is the cheaper trade.

Run after `flutter build web`. Refuses rather than guesses if the app turns out
to use a pruned weight, so adding `LucideIcons.house300` one day fails the
build instead of silently shipping blank squares.
"""

import json
import pathlib
import re
import sys

# Families that stay no matter what. Everything else matched by PRUNE goes.
PRUNE = re.compile(r"/Lucide(100|200|300|400|500|600)$")


def used_weights(lib: pathlib.Path) -> set[str]:
    """Weighted icon constants the app actually names, e.g. {'300'}."""
    found = set()
    for dart in lib.rglob("*.dart"):
        for name in re.findall(r"LucideIcons\.[A-Za-z0-9]+", dart.read_text()):
            match = re.search(r"(100|200|300|400|500|600)$", name)
            if match:
                found.add(match.group(1))
    return found


def main() -> int:
    build = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    lib = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "lib")
    manifest = build / "assets" / "FontManifest.json"
    if not manifest.exists():
        print(f"prune_fonts: no {manifest}; run flutter build web first")
        return 1

    still_used = used_weights(lib)
    if still_used:
        print(
            "prune_fonts: refusing to prune — the app now uses Lucide weight(s) "
            f"{', '.join(sorted(still_used))}. Narrow PRUNE, or delete this step."
        )
        return 1

    families = json.loads(manifest.read_text())
    keep = [f for f in families if not PRUNE.search(f["family"])]
    dropped = [f for f in families if PRUNE.search(f["family"])]
    if not dropped:
        print("prune_fonts: nothing to prune")
        return 0

    freed = 0
    for family in dropped:
        for font in family["fonts"]:
            path = build / "assets" / font["asset"]
            if path.exists():
                freed += path.stat().st_size
                path.unlink()

    manifest.write_text(json.dumps(keep, indent=2) + "\n")
    print(
        f"prune_fonts: dropped {len(dropped)} unused icon-font weights, "
        f"{freed / 1024 / 1024:.2f} MB off the cold load"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
