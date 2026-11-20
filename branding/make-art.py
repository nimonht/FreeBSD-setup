#!/usr/bin/env python3
"""branding/make-art.py - draws all of LunaBSD's artwork from code.

    python3 branding/make-art.py

Writes into branding/: the mark and wordmark (SVG, outlined: no font
needed to show them), the wallpapers (SVG and 4K JPEG), the boot menu
pictures for framebuffer consoles (loader/*.png), and the text-mode logos
(boot menu, fastfetch). Run it after changing anything here and commit the
results; nothing runs at build time.

Needs: python3 with Pillow and fontTools, rsvg-convert, and IBM Plex Sans /
Mono (Debian/Ubuntu: fonts-ibm-plex; FreeBSD: plex-ttf).

The design: a crescent inside an instrument ring, with one small square on
the ring. Two colours: parchment and ink, like printed matter; one muted
red is kept for warnings. Original artwork for LunaBSD.
"""
import glob
import math
import os
import subprocess

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

# Palette (also in installer/qml/Theme.qml and docs/BRANDING.md)
PARCHMENT = "#D1CDB7"   # background
PAPER = "#DCD8C0"       # raised surfaces, light text on ink
GRID = "#C9C4AD"        # grid lines on parchment
WEAK = "#BAB5A1"        # rules, borders, shadows
SOFT = "#7D7865"        # secondary text
INK = "#454138"         # text, marks
NIGHT = "#211F1A"       # dark background
NIGHT_GRID = "#2A2822"
SIGNAL = "#B4503C"      # warnings only


def font(name):
    for d in ("/usr/share/fonts", "/usr/local/share/fonts", os.path.expanduser("~/.fonts")):
        hits = glob.glob(os.path.join(d, "**", name), recursive=True)
        if hits:
            return hits[0]
    raise SystemExit("font %s not found (install IBM Plex: fonts-ibm-plex / plex-ttf)" % name)


def outline(text, fontfile, size, tracking=0.0):
    """Text as one SVG path (y down, baseline at 0) and its width."""
    f = TTFont(fontfile)
    gs = f.getGlyphSet()
    cmap = f.getBestCmap()
    upm = f["head"].unitsPerEm
    s = size / upm
    pen = SVGPathPen(gs)
    x = 0.0
    for i, ch in enumerate(text):
        g = cmap[ord(ch)]
        gs[g].draw(TransformPen(pen, (s, 0, 0, -s, x, 0)))
        x += gs[g].width * s
        if i < len(text) - 1:
            x += tracking * size
    return pen.getCommands(), x


# ------------------------------------------------------------------ mark ---

def mark(cx, cy, r, ink, cut, ring=True, ticks=True, ring_w=None, sat=True, moon_on=True,
         sat_size=0.17, gap=14):
    """The LunaBSD mark: crescent, instrument ring, square satellite.
    r is the ring radius; everything scales from it. `cut` is the colour
    the crescent is cut with (the background)."""
    rw = ring_w or r * 0.046
    moon = r * 0.70
    out = []
    # crescent: a disc with a disc taken out of its upper right
    cutx, cuty, cutr = cx + moon * 0.40, cy - moon * 0.32, moon * 0.87
    mid = "m%d_%d" % (cx, cy)
    if moon_on:
        out.append('<mask id="%s"><rect x="%g" y="%g" width="%g" height="%g" fill="#fff"/>'
               '<circle cx="%g" cy="%g" r="%g" fill="#000"/></mask>'
               % (mid, cx - 2 * r, cy - 2 * r, 4 * r, 4 * r, cutx, cuty, cutr))
        out.append('<circle cx="%g" cy="%g" r="%g" fill="%s" mask="url(#%s)"/>' % (cx, cy, moon, ink, mid))
    if ring:
        # ring with a gap where the satellite sits (upper right, -40 deg)
        a0, a1 = math.radians(-40 + gap), math.radians(-40 - gap + 360)
        x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
        x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
        out.append('<path d="M%g %g A%g %g 0 1 1 %g %g" fill="none" stroke="%s" stroke-width="%g"/>'
                   % (x0, y0, r, r, x1, y1, ink, rw))
    if sat:
        a = math.radians(-40)
        sx, sy, ss = cx + r * math.cos(a), cy + r * math.sin(a), r * sat_size
        out.append('<rect x="%g" y="%g" width="%g" height="%g" fill="%s"/>' % (sx - ss / 2, sy - ss / 2, ss, ss, ink))
    if ticks:
        for ang in (180, 90):           # west and south: an instrument, not a target
            a = math.radians(ang)
            t0, t1 = r * 1.07, r * 1.19
            out.append('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="%g"/>'
                       % (cx + t0 * math.cos(a), cy + t0 * math.sin(a), cx + t1 * math.cos(a),
                          cy + t1 * math.sin(a), ink, rw))
    return "\n".join(out)


def svg(w, h, body, bg=None, vw=None, vh=None):
    vw, vh = vw or w, vh or h
    b = '<rect width="%g" height="%g" fill="%s"/>' % (vw, vh, bg) if bg else ""
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!-- LunaBSD artwork, drawn by branding/make-art.py. -->\n'
            '<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" viewBox="0 0 %g %g">\n%s\n%s\n</svg>\n'
            % (w, h, vw, vh, b, body))


def write(path, text):
    with open(os.path.join(HERE, path), "w", encoding="utf-8") as f:
        f.write(text)


def render(svgpath, png, w, h=None):
    args = ["rsvg-convert", "-w", str(w)] + (["-h", str(h)] if h else []) + [os.path.join(HERE, svgpath),
                                                                            "-o", png]
    subprocess.run(args, check=True)


# ------------------------------------------------------------- wordmark ---

def wordmark(color_a, color_b, size=100):
    """LUNABSD: LUNA in regular weight, BSD in light, wide tracking."""
    reg = font("IBMPlexSans-Medium.ttf")
    light = font("IBMPlexSans-Light.ttf")
    pa, wa = outline("LUNA", reg, size, tracking=0.32)
    pb, wb = outline("BSD", light, size, tracking=0.32)
    gap = size * 0.32
    cap = size * 0.70                  # cap height of Plex Sans, about
    body = ('<path d="%s" fill="%s"/>' % (pa, color_a)
            + '<path transform="translate(%g 0)" d="%s" fill="%s"/>' % (wa + gap, pb, color_b))
    return body, wa + gap + wb, cap


# ------------------------------------------------------------------ main ---

def main():
    os.makedirs(os.path.join(HERE, "loader"), exist_ok=True)

    # 1. the mark, ink on transparent, and reversed (for dark grounds)
    write("lunabsd-logo.svg", svg(256, 256, mark(128, 128, 104, INK, None)))
    write("lunabsd-logo-reverse.svg", svg(256, 256, mark(128, 128, 104, PAPER, None)))
    # small sizes (16-32 px): the ring would blur, so crescent and satellite
    write("lunabsd-logo-small.svg", svg(256, 256, mark(118, 138, 150, INK, None, ring=False,
                                                       ticks=False, sat_size=0.13)))

    # 2. wordmark and lockups
    wm, ww, cap = wordmark(INK, SOFT)
    pad = 8
    write("lunabsd-wordmark.svg", svg(ww + 2 * pad, cap + 2 * pad,
                                      '<g transform="translate(%g %g)">%s</g>' % (pad, cap + pad, wm)))
    # horizontal lockup: mark, rule, wordmark
    h = 256
    body = mark(128, 128, 104, INK, None)
    body += '<line x1="292" y1="70" x2="292" y2="186" stroke="%s" stroke-width="3"/>' % WEAK
    body += '<g transform="translate(330 %g)">%s</g>' % (128 + cap / 2, wm)
    write("lunabsd-lockup.svg", svg(330 + ww + 24, h, body))
    wmr, _, _ = wordmark(PAPER, WEAK)
    bodyr = mark(128, 128, 104, PAPER, None)
    bodyr += '<line x1="292" y1="70" x2="292" y2="186" stroke="%s" stroke-width="3"/>' % SOFT
    bodyr += '<g transform="translate(330 %g)">%s</g>' % (128 + cap / 2, wmr)
    write("lunabsd-lockup-reverse.svg", svg(330 + ww + 24, h, bodyr))

    # 3. wallpapers (1920x1080 design, rendered at 3840x2160)
    for name, bg, grid, moonfill, ink, txt in (
            ("lunabsd-wallpaper", PARCHMENT, GRID, "#C4BFA7", INK, SOFT),
            ("lunabsd-wallpaper-night", NIGHT, NIGHT_GRID, "#36332B", "#BAB5A1", "#8A8573")):
        W, H = 1920, 1080
        b = ['<defs><pattern id="g" width="12" height="12" patternUnits="userSpaceOnUse">'
             '<path d="M12 0H0V12" fill="none" stroke="%s" stroke-width="1"/></pattern></defs>' % grid,
             '<rect width="%d" height="%d" fill="url(#g)"/>' % (W, H)]
        cx, cy, r = 1330, 540, 330
        # guide circles, dashed, quiet
        for rr, op in ((r * 1.42, 0.16), (r * 1.62, 0.10)):
            b.append('<circle cx="%d" cy="%d" r="%g" fill="none" stroke="%s" stroke-opacity="%g" '
                     'stroke-width="1.2" stroke-dasharray="2 9"/>' % (cx, cy, rr, ink, op))
        b.append('<g opacity="0.92">%s</g>' % mark(cx, cy, r, moonfill, None, ring=False, ticks=False, sat=False))
        b.append('<g opacity="0.55">%s</g>' % mark(cx, cy, r, ink, None, ring_w=2.2, moon_on=False,
                                                     sat_size=0.06, gap=5))
        # a measuring rule along the bottom
        y = 930
        b.append('<line x1="96" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-opacity="0.35" stroke-width="1.2"/>'
                 % (y, W - 96, y, ink))
        for i, x in enumerate(range(96, W - 95, 24)):
            t = 10 if i % 5 == 0 else 5
            b.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-opacity="0.35" stroke-width="1.2"/>'
                     % (x, y, x, y - t, ink))
        # corner brackets
        for (x, y, dx, dy) in ((48, 48, 1, 1), (W - 48, 48, -1, 1), (48, H - 48, 1, -1), (W - 48, H - 48, -1, -1)):
            b.append('<path d="M%d %dV%dH%d" fill="none" stroke="%s" stroke-opacity="0.45" stroke-width="2"/>'
                     % (x, y + 26 * dy, y, x + 26 * dx, ink))
        # signature, bottom left
        wm2, w2, c2 = wordmark(ink, txt, size=26)
        b.append('<g transform="translate(96 %g)" opacity="0.8">%s</g>' % (900, wm2))
        write(name + ".svg", svg(3840, 2160, "\n".join(b), bg=bg, vw=W, vh=H))
        png = os.path.join(HERE, name + ".png")
        render(name + ".svg", png, 3840, 2160)
        im = Image.open(png).convert("RGB")
        im.save(os.path.join(HERE, name + ".jpg"), quality=92, optimize=True, progressive=True)
        im.resize((400, 225), Image.LANCZOS).save(os.path.join(HERE, name + "-preview.jpg"), quality=88)
        os.unlink(png)

    # 4. boot menu pictures for framebuffer consoles (as FreeBSD's own:
    #    brand 375x100, logo 240x200, RGBA, non-interlaced)
    wmb, wwb, capb = wordmark(PAPER, WEAK, size=60)
    write("loader/brand.svg", svg(375, 100, '<g transform="translate(12 %g)">%s</g>' % (50 + capb / 2, wmb)))
    render("loader/brand.svg", os.path.join(HERE, "loader", "lunabsd-brand.png"), 375, 100)
    write("loader/logo.svg", svg(240, 200, mark(120, 100, 80, PAPER, None)))
    render("loader/logo.svg", os.path.join(HERE, "loader", "lunabsd-logo.png"), 240, 200)
    for p in ("loader/brand.svg", "loader/logo.svg"):
        os.unlink(os.path.join(HERE, p))
    for p in ("lunabsd-brand.png", "lunabsd-logo.png"):
        f = os.path.join(HERE, "loader", p)
        Image.open(f).convert("RGBA").save(f, optimize=True)

    # 5. text-mode logos, rasterised from the mark
    text_logos()
    print("artwork written to", HERE)


def sample(cols, rows, sub_x, sub_y, moon_scale=1.0, ring_px=1.0):
    """Sample the mark on cols x rows character cells, sub_x x sub_y dots
    per cell (cells are twice as tall as wide). Returns grid[y][x] of
    (moon, ring) for every dot."""
    W, H = cols * sub_x, rows * sub_y
    py_scale = (2.0 * sub_x) / sub_y        # dot height in dot widths
    cx, cy = W / 2.0, H * py_scale / 2.0
    r = min(W, H * py_scale) / 2.0 - ring_px - 0.5
    moon = r * 0.70 * moon_scale
    cutx, cuty, cutr = cx + moon * 0.40, cy - moon * 0.32, moon * 0.87
    sa = math.radians(-40)
    sx, sy, ss = cx + r * math.cos(sa), cy + r * math.sin(sa), max(r * 0.09, 1.2)
    grid = []
    for y in range(H):
        row = []
        for x in range(W):
            X, Y = x + 0.5, (y + 0.5) * py_scale
            d = math.hypot(X - cx, Y - cy)
            m = d <= moon and math.hypot(X - cutx, Y - cuty) > cutr
            ang = math.degrees(math.atan2(Y - cy, X - cx))
            ring = abs(d - r) <= ring_px * 0.62 and not (-52 <= ang <= -28)
            sat = abs(X - sx) <= ss and abs(Y - sy) <= ss
            row.append((m, ring or sat))
        grid.append(row)
    return grid


BRAILLE = ((0, 0, 0x01), (0, 1, 0x02), (0, 2, 0x04), (1, 0, 0x08), (1, 1, 0x10),
           (1, 2, 0x20), (0, 3, 0x40), (1, 3, 0x80))


def text_logos():
    # fastfetch: the moon in solid blocks ($1), the ring as braille dots ($2)
    cols, rows = 34, 16
    g = sample(cols, rows, 2, 4, moon_scale=1.12, ring_px=1.0)
    lines = []
    for cy in range(rows):
        line, last = "", None
        for cx in range(cols):
            dots = [(dx, dy, bit) for dx, dy, bit in BRAILLE]
            moon = sum(g[cy * 4 + dy][cx * 2 + dx][0] for dx, dy, _ in dots)
            top = sum(g[cy * 4 + dy][cx * 2 + dx][0] for dx, dy, _ in dots if dy < 2)
            bot = moon - top
            ringbits = sum(bit for dx, dy, bit in dots if g[cy * 4 + dy][cx * 2 + dx][1])
            ch, col = " ", None
            if moon >= 6:
                ch, col = "█", 1
            elif top >= 3 and bot <= 1:
                ch, col = "▀", 1
            elif bot >= 3 and top <= 1:
                ch, col = "▄", 1
            elif moon:
                ch, col = chr(0x2800 + sum(bit for dx, dy, bit in dots if g[cy * 4 + dy][cx * 2 + dx][0])), 1
            elif ringbits:
                ch, col = chr(0x2800 + ringbits), 2
            if col and col != last:
                line += "$%d" % col
                last = col
            line += ch
        lines.append(line.rstrip())
    while lines and not lines[-1].replace("$1", "").replace("$2", "").strip():
        lines.pop()
    write("fastfetch-logo.txt", "\n".join(lines) + "\n")

    # boot menu: ASCII only (the console font may have nothing else)
    cols, rows = 30, 14
    g = sample(cols, rows, 1, 2, moon_scale=1.12, ring_px=0.95)
    out = []
    for cy in range(rows):
        line = ""
        for cx in range(cols):
            (tm, tr), (bm, br) = g[cy * 2][cx], g[cy * 2 + 1][cx]
            if tm and bm:
                line += "#"
            elif tm:
                line += '"'
            elif bm:
                line += ","
            elif tr and br:
                line += ":"
            elif tr:
                line += "'"
            elif br:
                line += "."
            else:
                line += " "
        out.append(line.rstrip())
    while out and not out[-1].strip():
        out.pop()
    write("loader/logo-ascii.txt", "\n".join(out) + "\n")


if __name__ == "__main__":
    main()
