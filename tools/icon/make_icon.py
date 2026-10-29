#!/usr/bin/env python3
"""Icono del juego (FEAT-037) a partir del menú principal: un recorte cuadrado de la calle
mojada (assets/ui/menu_background_84.jpg) con el logo del menú encima, «Velvet» en neón
manuscrito rosa (Mr Dafoe, girado -6°) sobre «HEIST '84» (Bebas Neue). Para 16-32 px, donde el
logo no se lee, solo la «V» manuscrita sobre la misma calle. Las letras van como trazados.

Genera:
- assets/ui/icon/velvet_icon.png (1024 px): icono del proyecto, ventana y AppImage;
- assets/ui/icon/velvet_icon.ico (16-256 px): ejecutable, instalador y accesos de Windows;
- site/favicon.png (64 px, la «V»): la web.

Requiere fontTools (pip), rsvg-convert (librsvg) y magick (ImageMagick).
Uso: python3 tools/icon/make_icon.py
"""

import base64
import subprocess
import tempfile
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "assets/fonts"
SCRIPT_FONT = FONTS / "mrdafoe/MrDafoe-Regular.ttf"
DISPLAY_FONT = FONTS / "bebasneue/BebasNeue-Regular.ttf"
BACKGROUND = ROOT / "assets/ui/menu_background_84.jpg"
OUT = ROOT / "assets/ui/icon"
PINK = "#ff3d9a"
TEXT = "#ece4d6"
# Recorte cuadrado del fondo (1376 × 768): las farolas encendidas y el coche
CROP = "768x768+300+0"
LARGE_SIZES = [48, 64, 128, 256]
SMALL_SIZES = [16, 24, 32]


def text_path(font_file: Path, text: str, size: float, track: float = 0.0):
    """Trazado SVG de un texto en una línea y su caja (xmin, ymin, xmax, ymax)."""
    font = TTFont(font_file)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = size / font["head"].unitsPerEm
    bounds = BoundsPen(glyphs)
    x = 0.0
    commands = ""
    for char in text:
        name = cmap[ord(char)]
        pen = SVGPathPen(glyphs)
        transform = (scale, 0, 0, -scale, x, 0)
        glyphs[name].draw(TransformPen(pen, transform))
        glyphs[name].draw(TransformPen(bounds, transform))
        commands += pen.getCommands()
        x += font["hmtx"][name][0] * scale + track
    return commands, bounds.bounds


def card(background_jpg: Path, content: str) -> str:
    """La calle oscurecida en un cuadrado de esquinas redondeadas, con content encima."""
    image = base64.b64encode(background_jpg.read_bytes()).decode()
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
<clipPath id="card"><rect width="1024" height="1024" rx="180"/></clipPath>
<radialGradient id="vignette" cx="50%" cy="45%" r="70%">
<stop offset=".45" stop-color="#07080d" stop-opacity="0"/>
<stop offset="1" stop-color="#07080d" stop-opacity=".85"/></radialGradient>
<linearGradient id="shade" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#07080d" stop-opacity=".55"/>
<stop offset=".65" stop-color="#07080d" stop-opacity=".25"/>
<stop offset="1" stop-color="#07080d" stop-opacity=".1"/></linearGradient>
<filter id="glow" x="-20%" y="-40%" width="140%" height="180%">
<feGaussianBlur stdDeviation="16" result="b"/>
<feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<filter id="shadow" x="-10%" y="-10%" width="120%" height="140%">
<feDropShadow dx="0" dy="12" stdDeviation="6" flood-color="#000" flood-opacity=".7"/></filter>
</defs>
<g clip-path="url(#card)">
<image href="data:image/jpeg;base64,{image}" width="1024" height="1024"/>
<rect width="1024" height="1024" fill="url(#shade)"/>
<rect width="1024" height="1024" fill="url(#vignette)"/>
{content}
</g>
</svg>"""


def logo() -> str:
    heist, hb = text_path(DISPLAY_FONT, "HEIST '84", 300, 4)
    velvet, vb = text_path(SCRIPT_FONT, "Velvet", 330)
    hx = 512 - (hb[2] - hb[0]) / 2 - hb[0]
    hy = 600
    return (
        f'<path d="{heist}" fill="{TEXT}" filter="url(#shadow)" '
        f'transform="translate({hx:.1f} {hy})"/>\n'
        f'<path d="{velvet}" fill="{PINK}" filter="url(#glow)" '
        f'transform="translate({hx + 10 - vb[0]:.1f} {hy - 235}) rotate(-6)"/>'
    )


def monogram() -> str:
    v, (x0, y0, x1, y1) = text_path(SCRIPT_FONT, "V", 900)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return (
        f'<path d="{v}" fill="{PINK}" filter="url(#glow)" '
        f'transform="translate({512 - cx:.1f} {500 - cy:.1f})"/>'
    )


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        street = work / "street.jpg"
        run("magick", str(BACKGROUND), "-crop", CROP, "+repage", "-resize", "1024x1024", str(street))
        large = work / "large.svg"
        small = work / "small.svg"
        large.write_text(card(street, logo()))
        small.write_text(card(street, monogram()))
        run("rsvg-convert", "-w", "1024", "-h", "1024", str(large), "-o", str(OUT / "velvet_icon.png"))
        layers = []
        for size in SMALL_SIZES + LARGE_SIZES:
            source = small if size in SMALL_SIZES else large
            layer = work / f"{size}.png"
            run("rsvg-convert", "-w", str(size), "-h", str(size), str(source), "-o", str(layer))
            layers.append(str(layer))
        run("magick", *layers, str(OUT / "velvet_icon.ico"))
        run("rsvg-convert", "-w", "64", "-h", "64", str(small), "-o", str(ROOT / "site/favicon.png"))
    print(f"==> {OUT / 'velvet_icon.png'}, {OUT / 'velvet_icon.ico'} y site/favicon.png")


if __name__ == "__main__":
    main()
