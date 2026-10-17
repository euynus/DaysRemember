"""Draws the app icon, 晴空日月: a yellow sun held by a white crescent moon on a pale sky.

The shapes follow the flat covers (scripts/flat-covers.py): no outlines, rounded tips, and a
translucent ink tone where the moon meets the sun. Writes the light, dark and tinted 1024 px
icons into the app's AppIcon set and the site's icon-180 / icon-512, rendered with headless
Chrome as scripts/og-images.sh does. Run after changing the drawing, then scripts/og-images.sh:

    python3 scripts/app-icon.py
"""
import json
import math
import os
import shutil
import subprocess
import tempfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
ICONSET = os.path.join(ROOT, "DaysRemember", "Resources", "Assets.xcassets", "AppIcon.appiconset")
SITE = os.path.join(ROOT, "docs", "assets")
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

SKY = "#D2E4F7"
SUN = "#F6BE3B"
INK = "#24222B"

# The moon is circle M less circle K around the sun; ROUND is the stroke that rounds its tips.
M, MR = (556, 556), 330
K, SUN_R, GAP, ROUND = (414, 414), 228, 34, 28
KR = SUN_R + GAP + ROUND / 2
SHADOW = KR + 40


def meet(c1, r1, c2, r2):
    """The two points where circles c1 and c2 cross, the first clockwise-before the second on c1."""
    (x1, y1), (x2, y2) = c1, c2
    d = math.hypot(x2 - x1, y2 - y1)
    a = (r1**2 - r2**2 + d**2) / (2 * d)
    h = math.sqrt(r1**2 - a**2)
    ux, uy = (x2 - x1) / d, (y2 - y1) / d
    px, py = x1 + a * ux, y1 + a * uy
    return (px - h * uy, py + h * ux), (px + h * uy, py - h * ux)


def pt(p):
    return f"{p[0]:.1f} {p[1]:.1f}"


TIP1, TIP2 = meet(M, MR, K, KR)
EDGE1, EDGE2 = meet(M, MR, K, SHADOW)
MOON = f"M{pt(TIP1)} A{MR} {MR} 0 1 1 {pt(TIP2)} A{KR} {KR} 0 0 0 {pt(TIP1)}Z"
# The part of the moon within SHADOW of the sun's centre.
TONE = (f"M{pt(TIP1)} A{MR} {MR} 0 0 1 {pt(EDGE1)} A{SHADOW} {SHADOW} 0 0 1 {pt(EDGE2)}"
        f" A{MR} {MR} 0 0 1 {pt(TIP2)} A{KR} {KR} 0 0 0 {pt(TIP1)}Z")


def icon(ground, moon, tone, tone_opacity, sun):
    """ground None leaves the background transparent, for the system's dark and tinted icons."""
    rect = f'<rect width="1024" height="1024" fill="{ground}"/>' if ground else ""
    shape = f'stroke-width="{ROUND}" stroke-linejoin="round"'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{rect}'
            f'<path d="{MOON}" fill="{moon}" stroke="{moon}" {shape}/>'
            f'<g opacity="{tone_opacity}"><path d="{TONE}" fill="{tone}" stroke="{tone}" {shape}/></g>'
            f'<circle cx="{K[0]}" cy="{K[1]}" r="{SUN_R}" fill="{sun}"/></svg>')


VARIANTS = {
    "AppIcon.png": (icon(SKY, "#FFFFFF", INK, 0.09, SUN), None),
    "AppIcon-Dark.png": (icon(None, "#FFFFFF", INK, 0.14, SUN), "dark"),
    # Grayscale: the system tints by lightness, so the moon stays brightest and the sun reads apart.
    "AppIcon-Tinted.png": (icon(None, "#FFFFFF", "#000000", 0.18, "#A8A8A8"), "tinted"),
}


def render(svg, out, profile, transparent):
    page = os.path.join(profile, "icon.html")
    with open(page, "w") as fh:
        fh.write(f'<!doctype html><style>html,body{{margin:0;background:transparent}}svg{{display:block}}</style>{svg}')
    args = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
            f"--user-data-dir={profile}", "--hide-scrollbars", "--force-device-scale-factor=1",
            "--window-size=1024,1024", f"--screenshot={out}", f"file://{page}"]
    if transparent:
        args.insert(1, "--default-background-color=00000000")
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def sips(*args):
    return subprocess.run(["sips", *args], check=True, capture_output=True, text=True).stdout


def main():
    if not os.access(CHROME, os.X_OK):
        raise SystemExit("Google Chrome not found; set CHROME to its binary")
    profile = tempfile.mkdtemp()
    try:
        images = []
        for name, (svg, appearance) in VARIANTS.items():
            out = os.path.join(ICONSET, name)
            render(svg, out, profile, transparent=appearance is not None)
            entry = {"filename": name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
            if appearance:
                entry["appearances"] = [{"appearance": "luminosity", "value": appearance}]
            images.append(entry)
            print(os.path.relpath(out, ROOT))
        with open(os.path.join(ICONSET, "Contents.json"), "w") as fh:
            json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, fh, indent=2)
            fh.write("\n")
        light = os.path.join(ICONSET, "AppIcon.png")
        for size in (180, 512):
            out = os.path.join(SITE, f"icon-{size}.png")
            sips("-z", str(size), str(size), light, "--out", out)
            print(os.path.relpath(out, ROOT))
    finally:
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == "__main__":
    main()
