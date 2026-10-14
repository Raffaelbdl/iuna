#!/usr/bin/env python3
"""Render Iuna's Android launcher icons from the black Kuma mascot.

The drawing here mirrors `lib/widgets/kuma_mascot.dart` (KumaVariant.black)
so the launcher art stays visually identical to the in-app seal. Outputs:

  * Legacy `mipmap-{mdpi..xxxhdpi}/ic_launcher.png` — Kuma + cream
    background, used by Android < 8.0.
  * Adaptive foreground `mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png`
    — Kuma on transparent, used together with the cream background
    color (declared in values/ic_launcher_background.xml) by Android 8+.

Re-run from the repo root after touching the Kuma painter or palette:

    python3 tools/build_launcher_icons.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"

# --- Black Kuma palette (kept in sync with lib/widgets/kuma_mascot.dart) ---
BODY = (42, 37, 48, 255)            # #2A2530
EAR_IN = (174, 224, 216, 255)       # #AEE0D8
MUZZLE = (58, 51, 64, 255)          # #3A3340
EYE = (10, 5, 0, 255)               # #0A0500
RIBBON = (174, 224, 216, 255)       # #AEE0D8
RIBBON_SHADE = (127, 196, 186, 255) # #7FC4BA
CHARM = (212, 168, 94, 255)         # #D4A85E

# Icon background — diagonal gold→pink matching HomeScreen's HeroPack
# (Alignment(-0.4,-1) → Alignment(0.4,1) with the same color stops). The
# legacy launcher PNG bakes this in; the adaptive icon references the
# same colors via drawable/ic_launcher_background.xml.
BG_GRAD_START = (255, 217, 148, 255)  # #FFD994
BG_GRAD_END = (243, 167, 181, 255)    # #F3A7B5

# Source coordinate system is 100×100 (matches the painter).
SRC = 100

# Bezier helpers — PIL has no quadratic primitive, so we sample the
# curve into polygon vertices.
def _bezier_q(p0, p1, p2, n=24):
    return [
        (
            (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1],
        )
        for t in (i / n for i in range(n + 1))
    ]


def _draw_kuma(img: Image.Image, scale: float, off_x: float, off_y: float) -> None:
    """Draw the black Kuma onto `img`. Mirrors the Flutter painter."""
    draw = ImageDraw.Draw(img)

    def p(x, y):
        return (off_x + x * scale, off_y + y * scale)

    def ellipse(cx, cy, rx, ry, fill, outline=None, width=0):
        bb = [*p(cx - rx, cy - ry), *p(cx + rx, cy + ry)]
        draw.ellipse(bb, fill=fill, outline=outline, width=max(1, int(width)))

    def circle(cx, cy, r, fill, outline=None, width=0):
        ellipse(cx, cy, r, r, fill, outline=outline, width=width)

    def polygon(pts, fill):
        draw.polygon([p(*pt) for pt in pts], fill=fill)

    def line(a, b, fill, w):
        draw.line([p(*a), p(*b)], fill=fill, width=max(1, int(w * scale)))

    # Ears
    circle(26, 26, 11, BODY)
    circle(74, 26, 11, BODY)
    circle(26, 26, 5.5, EAR_IN)
    circle(74, 26, 5.5, EAR_IN)

    # Head
    circle(50, 54, 32, BODY)

    # Muzzle patch + eyes + nose
    ellipse(50, 62, 11, 8, MUZZLE)
    circle(40, 50, 2.6, EYE)
    circle(60, 50, 2.6, EYE)
    ellipse(50, 58, 1.6, 1.2, EYE)

    # Ribbon (main + two loops)
    polygon(
        _bezier_q((30, 86), (50, 80), (70, 86))
        + [(70, 92)]
        + _bezier_q((70, 92), (50, 86), (30, 92))
        + [(30, 86)],
        RIBBON,
    )
    polygon(
        _bezier_q((22, 88), (30, 84), (36, 88))
        + _bezier_q((36, 88), (30, 92), (22, 92)),
        RIBBON,
    )
    polygon(
        _bezier_q((78, 88), (70, 84), (64, 88))
        + _bezier_q((64, 88), (70, 92), (78, 92)),
        RIBBON,
    )

    # Charm disc + X
    circle(50, 88, 3.2, CHARM, outline=RIBBON_SHADE, width=max(1, scale * 0.5))
    line((48, 86), (52, 90), RIBBON_SHADE, 0.8)
    line((52, 86), (48, 90), RIBBON_SHADE, 0.8)


def _diagonal_gradient(size: int, c1, c2, low_res: int = 256) -> Image.Image:
    """Top-left → bottom-right linear gradient. Rendered at `low_res`
    in pure Python then upsampled to `size` so the per-pixel lerp loop
    stays small (no numpy required)."""
    n = max(2, low_res)
    img = Image.new("RGBA", (n, n))
    pixels = img.load()
    denom = 2 * (n - 1)
    for y in range(n):
        for x in range(n):
            t = (x + y) / denom
            pixels[x, y] = (
                int(c1[0] * (1 - t) + c2[0] * t),
                int(c1[1] * (1 - t) + c2[1] * t),
                int(c1[2] * (1 - t) + c2[2] * t),
                int(c1[3] * (1 - t) + c2[3] * t),
            )
    return img.resize((size, size), Image.LANCZOS)


def render(out_path: Path, size: int, *, with_background: bool, kuma_fraction: float) -> None:
    """Render an icon at `size` px square.

    `kuma_fraction` is the fraction of the canvas occupied by Kuma's
    bounding box. Adaptive foreground wants ~0.56 so Kuma stays inside
    the 72dp safe zone of a 108dp canvas; legacy launcher icons can go
    a bit larger (~0.78) since the whole tile is visible.

    Renders at 4× resolution then downsamples with LANCZOS for crisp
    anti-aliasing — PIL's primitive draws are non-AA.
    """
    SS = 4
    canvas = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))

    if with_background:
        bg = _diagonal_gradient(size * SS, BG_GRAD_START, BG_GRAD_END)
        canvas.paste(bg, (0, 0))

    # Kuma's bounding box in source coords is roughly 70×77 (ears at
    # x∈[15,85], top of ears at y≈15, ribbon bottom at y≈92).
    src_w, src_h = 70.0, 77.0
    target = size * SS * kuma_fraction
    scale = target / max(src_w, src_h)
    src_cx, src_cy = 50.0, 53.5
    off_x = size * SS / 2 - src_cx * scale
    off_y = size * SS / 2 - src_cy * scale
    _draw_kuma(canvas, scale, off_x, off_y)

    final = canvas.resize((size, size), Image.LANCZOS)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    final.save(out_path)
    print(f"  {out_path.relative_to(ROOT)}  {size}×{size}")


def main() -> None:
    # Adaptive foreground sizes: 108dp canvas at each density. Kept in
    # mipmap-* alongside the legacy icons so the lookup is consistent.
    foregrounds = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }
    for density, px in foregrounds.items():
        render(
            RES / f"mipmap-{density}/ic_launcher_foreground.png",
            px,
            with_background=False,
            kuma_fraction=0.48,
        )

    # Legacy launcher icons (Kuma + cream background baked in) for
    # pre-Oreo. Sizes are 48 · 72 · 96 · 144 · 192 dp respectively.
    legacy = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, px in legacy.items():
        render(
            RES / f"mipmap-{density}/ic_launcher.png",
            px,
            with_background=True,
            kuma_fraction=0.68,
        )


if __name__ == "__main__":
    main()
