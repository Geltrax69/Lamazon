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

It then subsets the one icon font that is left.

Flutter tree-shakes MaterialIcons from 1.6 MB to 8 KB, and lucide.ttf from
842 KB to 736 KB — 12.7%, for an app that names 130 of its 1,746 icons. The
difference is `test_icons.dart` in that package: a `const List<IconData>` of
every icon it ships, which keeps every glyph reachable. The glyphs cannot be
dropped by the tree-shaker while that list exists, but they can be emptied
here, which is the same 660 KB by a different route.

Glyph ids, cmap and metrics are left exactly as they are; only the outlines of
glyphs the app never draws are removed, and `loca` is rewritten to point at
nothing for them. That keeps the change to two tables and means a mistake
shows up as one blank icon rather than a font that will not parse.

Run after `flutter build web`. Refuses rather than guesses if the app turns out
to use a pruned weight, so adding `LucideIcons.house300` one day fails the
build instead of silently shipping blank squares.
"""

import json
import pathlib
import re
import struct
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


def used_codepoints(lib: pathlib.Path, project: pathlib.Path) -> set[int] | None:
    """Codepoints for every `LucideIcons.name` the app names.

    Read from the package's own source through package_config.json, so the
    answer comes from the same version of the package the build compiled
    against rather than from a table here that would rot.
    """
    config = project / ".dart_tool" / "package_config.json"
    if not config.exists():
        return None
    root = None
    for package in json.loads(config.read_text())["packages"]:
        if package["name"] == "lucide_icons_flutter":
            root = (config.parent / package["rootUri"].replace("../", "", 1)).resolve()
            if not root.exists():                       # absolute rootUri
                root = pathlib.Path(package["rootUri"].replace("file://", ""))
    if root is None:
        return None
    source = root / "lib" / "lucide_icons.dart"
    if not source.exists():
        return None

    declared = dict(
        re.findall(
            r"static const IconData ([A-Za-z0-9_]+)\s*=\s*(?:const\s+)?IconData\(\s*(\d+)",
            source.read_text(),
        )
    )
    names = set()
    for dart in lib.rglob("*.dart"):
        # Comments mention icons that do not exist — the note in admin_screen
        # about `cond ? LucideIcons.a : LucideIcons.b` is prose, not a call.
        code = re.sub(r"//[^\n]*|/\*.*?\*/", "", dart.read_text(), flags=re.S)
        names.update(re.findall(r"LucideIcons\.([A-Za-z0-9_]+)", code))

    missing = sorted(n for n in names if n not in declared)
    if missing:
        print(f"prune_fonts: cannot place {', '.join(missing[:5])} — leaving the font alone")
        return None
    return {int(declared[n]) for n in names}


def _tables(data: bytes) -> dict[str, tuple[int, int]]:
    """Table tag -> (offset, length), from the sfnt directory."""
    count = struct.unpack(">H", data[4:6])[0]
    out = {}
    for i in range(count):
        tag, _sum, off, length = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
        out[tag.decode("latin1")] = (off, length)
    return out


def _cmap(data: bytes, off: int) -> dict[int, int]:
    """Codepoint -> glyph id. Formats 4 and 12, which is what icon fonts use."""
    best, n = None, struct.unpack(">H", data[off + 2:off + 4])[0]
    for i in range(n):
        _pid, _eid, sub = struct.unpack(">HHI", data[off + 4 + 8 * i:off + 12 + 8 * i])
        fmt = struct.unpack(">H", data[off + sub:off + sub + 2])[0]
        if fmt in (4, 12) and (best is None or fmt == 12):
            best = (fmt, off + sub)
    if best is None:
        return {}
    fmt, base = best
    out: dict[int, int] = {}
    if fmt == 12:
        groups = struct.unpack(">I", data[base + 12:base + 16])[0]
        for g in range(groups):
            start, end, gid = struct.unpack(">III", data[base + 16 + 12 * g:base + 28 + 12 * g])
            for cp in range(start, end + 1):
                out[cp] = gid + (cp - start)
        return out
    seg2 = struct.unpack(">H", data[base + 6:base + 8])[0]
    seg = seg2 // 2
    ends = struct.unpack(f">{seg}H", data[base + 14:base + 14 + seg2])
    starts_at = base + 16 + seg2
    starts = struct.unpack(f">{seg}H", data[starts_at:starts_at + seg2])
    deltas = struct.unpack(f">{seg}h", data[starts_at + seg2:starts_at + 2 * seg2])
    range_at = starts_at + 2 * seg2
    offsets = struct.unpack(f">{seg}H", data[range_at:range_at + seg2])
    for i in range(seg):
        for cp in range(starts[i], min(ends[i], 0xFFFF) + 1):
            if cp == 0xFFFF:
                continue
            if offsets[i] == 0:
                gid = (cp + deltas[i]) & 0xFFFF
            else:
                at = range_at + 2 * i + offsets[i] + 2 * (cp - starts[i])
                if at + 2 > len(data):
                    continue
                gid = struct.unpack(">H", data[at:at + 2])[0]
                if gid:
                    gid = (gid + deltas[i]) & 0xFFFF
            if gid:
                out[cp] = gid
    return out


def _loca(data: bytes, tables, num_glyphs: int, long_format: bool) -> list[int]:
    off, _ = tables["loca"]
    if long_format:
        return list(struct.unpack(f">{num_glyphs + 1}I", data[off:off + 4 * (num_glyphs + 1)]))
    short = struct.unpack(f">{num_glyphs + 1}H", data[off:off + 2 * (num_glyphs + 1)])
    return [v * 2 for v in short]


def subset_icon_font(font: pathlib.Path, codepoints: set[int]) -> tuple[int, int, int]:
    """Empty every glyph the app never draws. Returns (before, after, kept)."""
    data = bytearray(font.read_bytes())
    tables = _tables(data)
    head, _ = tables["head"]
    long_loca = struct.unpack(">h", data[head + 50:head + 52])[0] == 1
    maxp, _ = tables["maxp"]
    num_glyphs = struct.unpack(">H", data[maxp + 4:maxp + 6])[0]
    loca = _loca(data, tables, num_glyphs, long_loca)
    glyf_off, glyf_len = tables["glyf"]

    wanted = {0}  # .notdef always stays
    mapping = _cmap(data, tables["cmap"][0])
    for cp in codepoints:
        if cp in mapping:
            wanted.add(mapping[cp])

    # A composite glyph draws other glyphs; keep what it points at.
    pending, seen = list(wanted), set()
    while pending:
        gid = pending.pop()
        if gid in seen or gid >= num_glyphs:
            continue
        seen.add(gid)
        start, end = loca[gid], loca[gid + 1]
        if end - start < 10:
            continue
        contours = struct.unpack(">h", data[glyf_off + start:glyf_off + start + 2])[0]
        if contours >= 0:
            continue
        at = glyf_off + start + 10
        while True:
            flags, index = struct.unpack(">HH", data[at:at + 2 + 2])
            wanted.add(index)
            pending.append(index)
            at += 4 + (4 if flags & 1 else 2)
            if flags & 8:
                at += 2
            elif flags & 0x40:
                at += 4
            elif flags & 0x80:
                at += 8
            if not flags & 0x20:
                break

    glyf = bytearray()
    new_loca = [0]
    for gid in range(num_glyphs):
        if gid in wanted:
            chunk = data[glyf_off + loca[gid]:glyf_off + loca[gid + 1]]
            glyf += chunk
            while len(glyf) % 4:           # glyphs stay 4-byte aligned
                glyf += b"\x00"
        new_loca.append(len(glyf))

    if len(glyf) >= glyf_len:
        return glyf_len, glyf_len, len(wanted)

    # loca keeps its length, so every other table's offsets stay valid; the
    # glyf table is rewritten in place and the tail left as padding.
    if long_loca:
        packed = struct.pack(f">{num_glyphs + 1}I", *new_loca)
    else:
        if new_loca[-1] > 0x1FFFE or any(v % 2 for v in new_loca):
            return glyf_len, glyf_len, len(wanted)
        packed = struct.pack(f">{num_glyphs + 1}H", *[v // 2 for v in new_loca])
    loca_off, loca_len = tables["loca"]
    if len(packed) != loca_len:
        return glyf_len, glyf_len, len(wanted)
    data[loca_off:loca_off + loca_len] = packed
    data[glyf_off:glyf_off + len(glyf)] = glyf

    # What every kept glyph looked like before, so the result can be checked
    # against it rather than assumed. A font that rewrites wrong should fail
    # the build, not ship a screen of blank squares.
    before_outline = {
        gid: loca[gid + 1] > loca[gid] for gid in wanted if gid < num_glyphs
    }

    if glyf_off + glyf_len >= len(data) - 3:  # trailing padding is fine
        # glyf is the last table, so the file can simply end earlier. Shrinking
        # it for real saves the parse and the memory as well as the download.
        for i in range(struct.unpack(">H", data[4:6])[0]):
            entry = 12 + 16 * i
            if data[entry:entry + 4] == b"glyf":
                data[entry + 12:entry + 16] = struct.pack(">I", len(glyf))
        del data[glyf_off + len(glyf):]
    else:
        data[glyf_off + len(glyf):glyf_off + glyf_len] = b"\x00" * (glyf_len - len(glyf))
    original = font.read_bytes()
    font.write_bytes(bytes(data))

    check = font.read_bytes()
    try:
        rebuilt = _tables(check)
        again = _loca(check, rebuilt, num_glyphs, long_loca)
        drawn = _cmap(check, rebuilt["cmap"][0])
        ok = all(
            (again[gid + 1] > again[gid]) == had
            for gid, had in before_outline.items()
        ) and all(drawn.get(cp) == mapping.get(cp) for cp in codepoints if cp in mapping)
    except Exception:
        ok = False
    if not ok:
        font.write_bytes(original)
        raise SystemExit(
            f"prune_fonts: subsetting {font.name} lost a glyph the app draws. "
            "The font has been left as it was; fix the subsetter before shipping."
        )
    return glyf_len, len(glyf), len(wanted)


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

    freed = 0
    for family in dropped:
        for font in family["fonts"]:
            path = build / "assets" / font["asset"]
            if path.exists():
                freed += path.stat().st_size
                path.unlink()

    if dropped:
        manifest.write_text(json.dumps(keep, indent=2) + "\n")
        print(
            f"prune_fonts: dropped {len(dropped)} unused icon-font weights, "
            f"{freed / 1024 / 1024:.2f} MB off the cold load"
        )

    codepoints = used_codepoints(lib, lib.parent)
    if codepoints:
        for family in keep:
            if not family["family"].endswith("/Lucide"):
                continue
            for font in family["fonts"]:
                path = build / "assets" / font["asset"]
                if not path.exists():
                    continue
                before, after, kept = subset_icon_font(path, codepoints)
                print(
                    f"prune_fonts: {path.name} keeps {kept} of the glyphs it "
                    f"shipped, {(before - after) / 1024:.0f} KB off the cold load"
                )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
