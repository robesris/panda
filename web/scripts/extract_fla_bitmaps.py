#!/usr/bin/env python3
"""Extract embedded bitmaps from a CS5+ Adobe Animate .fla (XFL ZIP) archive.

CS5+ FLAs are ZIP files containing XFL XML + LIBRARY/*.png plus a bin/ directory
with M*.dat files holding Animate's compiled bitmap cache. This tool walks both:

  * For LIBRARY/*.{png,jpg,gif}, extract them verbatim using a hand-rolled
    local-file-header walker (the bundled `unzip` and Python `zipfile` choke
    on the 54-byte trailing garbage in these archives).

  * For bin/M*.dat, the format is:
      32-byte header  (magic 03 05, stride uint16, width uint16, height uint16,
                       reserved zeros, frameRight uint32 twips, frameBottom uint32 twips,
                       4 trailing flag bytes)
      raw DEFLATE stream  (no zlib wrapper) of BGRA premultiplied pixels
      6-byte trailer  (looks like Adler32 + 2 zero bytes)

    Some bitmaps decode to exactly W*H*4 bytes; larger backgrounds
    (bg-mountains.png, bg-sky.png) include extra structure we haven't fully
    reverse-engineered. We dump them as best-effort (truncate-to-W*H*4) so
    they're usable as parallax even with rendering artifacts.

Usage:
    python3 extract_fla_bitmaps.py path/to/file.fla output_dir/
"""

import argparse, os, re, struct, sys, zlib

LFH = b"PK\x03\x04"


def walk_lfh(data):
    """Yield (name, payload, method) for every Local File Header in the ZIP."""
    pos = 0
    while True:
        i = data.find(LFH, pos)
        if i < 0:
            return
        pos = i + 4
        if i + 30 > len(data):
            continue
        ver, flags, method, _t, _d, crc, csize, usize, nlen, elen = struct.unpack_from("<HHHHHIIIHH", data, i + 4)
        name_off = i + 30
        if name_off + nlen + elen > len(data):
            continue
        name = data[name_off:name_off + nlen].decode("utf-8", "replace")
        po = name_off + nlen + elen
        try:
            if method == 0:
                payload = data[po:po + (csize or usize)]
            elif method == 8 and csize:
                payload = zlib.decompress(data[po:po + csize], -15)
            else:
                continue
        except zlib.error:
            continue
        yield name, payload, method


def extract_library_images(data, out_dir):
    """Copy LIBRARY/*.{png,jpg,gif} verbatim to out_dir."""
    found = []
    for name, payload, _ in walk_lfh(data):
        low = name.lower()
        if not low.startswith("library/"):
            continue
        if not low.endswith((".png", ".jpg", ".jpeg", ".gif", ".bmp")):
            continue
        # Validate magic.
        m = payload[:4]
        ok = (
            (low.endswith(".png") and m.startswith(b"\x89PNG"))
            or (low.endswith((".jpg", ".jpeg")) and payload[:3] == b"\xff\xd8\xff")
            or (low.endswith(".gif") and m[:3] == b"GIF")
            or (low.endswith(".bmp") and m[:2] == b"BM")
        )
        if not ok:
            continue
        base = os.path.basename(name)
        dst = os.path.join(out_dir, base)
        with open(dst, "wb") as f:
            f.write(payload)
        found.append((base, len(payload)))
    return found


def write_png(path, w, h, rgba):
    def chunk(typ, payload):
        c = typ + payload
        return struct.pack(">I", len(payload)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        raw = bytearray()
        for y in range(h):
            raw.append(0)
            raw += rgba[y * w * 4:(y + 1) * w * 4]
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 6)))
        f.write(chunk(b"IEND", b""))


def bgra_premul_to_rgba(buf):
    """Adobe Animate stores BGRA with premultiplied alpha; un-premultiply to straight RGBA."""
    rgba = bytearray(len(buf))
    for i in range(0, len(buf), 4):
        b, g, r, a = buf[i], buf[i + 1], buf[i + 2], buf[i + 3]
        if a == 0:
            rgba[i] = rgba[i + 1] = rgba[i + 2] = 0
            rgba[i + 3] = 0
        elif a == 255:
            rgba[i] = r; rgba[i + 1] = g; rgba[i + 2] = b; rgba[i + 3] = 255
        else:
            rgba[i]     = min(255, round(r * 255 / a))
            rgba[i + 1] = min(255, round(g * 255 / a))
            rgba[i + 2] = min(255, round(b * 255 / a))
            rgba[i + 3] = a
    return bytes(rgba)


def decode_dat(payload, w, h):
    """Best-effort: decompress raw DEFLATE from offset 32, take first W*H*4 bytes as BGRA."""
    body = zlib.decompress(payload[32:], -15)
    expected = w * h * 4
    if len(body) >= expected:
        return bgra_premul_to_rgba(body[:expected])
    pad = bytearray(body) + b"\x00" * (expected - len(body))
    return bgra_premul_to_rgba(bytes(pad))


def extract_bitmap_cache(data, out_dir, dom_xml=None):
    """Decode bin/M*.dat entries listed in DOMDocument.xml's DOMBitmapItem records."""
    if dom_xml is None:
        for name, payload, _ in walk_lfh(data):
            if name.lower() == "domdocument.xml":
                dom_xml = payload.decode("utf-8", "replace")
                break
    if not dom_xml:
        return []

    # Map dat-filename -> payload from the archive.
    dat_payloads = {}
    for name, payload, method in walk_lfh(data):
        if name.startswith("bin/") and name.endswith(".dat"):
            dat_payloads[name] = payload

    found = []
    for m in re.finditer(
        r'name="([^"]+\.png)"[^>]*bitmapDataHRef="([^"]+)"[^>]*frameRight="(\d+)"[^>]*frameBottom="(\d+)"',
        dom_xml,
    ):
        png_name, dat_name, fr, fb = m.group(1), m.group(2), int(m.group(3)), int(m.group(4))
        full = "bin/" + dat_name
        if full not in dat_payloads:
            continue
        w, h = fr // 20, fb // 20
        try:
            rgba = decode_dat(dat_payloads[full], w, h)
        except zlib.error as e:
            found.append((png_name, w, h, f"decode failed: {e}"))
            continue
        out = os.path.join(out_dir, png_name)
        write_png(out, w, h, rgba)
        found.append((png_name, w, h, f"-> {out}"))
    return found


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("fla")
    ap.add_argument("out_dir")
    ap.add_argument("--cache", action="store_true",
                    help="Decode bin/*.dat bitmap cache too (lossy; LIBRARY/ extracts are higher-fidelity).")
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    with open(args.fla, "rb") as f:
        data = f.read()

    print(f"Walking {args.fla} ({len(data)} bytes)")
    lib = extract_library_images(data, args.out_dir)
    print(f"  LIBRARY/: {len(lib)} images")
    for name, sz in sorted(lib):
        print(f"    {sz:>9}  {name}")

    if args.cache:
        cache = extract_bitmap_cache(data, args.out_dir)
        print(f"  bin/ cache: {len(cache)} entries")
        for name, w, h, status in sorted(cache):
            print(f"    {w:>5}x{h:<5}  {name}  {status}")


if __name__ == "__main__":
    main()
