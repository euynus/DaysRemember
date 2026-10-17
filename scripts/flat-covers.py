"""Generates the flat cover illustrations in the app's and the widget's asset catalogs,
and the copies the product site (docs/) shows.

Each cover is white shapes, one or two accents, and translucent ink tones that
pick up whatever pastel card they sit on. Run after changing a drawing:

    python3 scripts/flat-covers.py
"""
import math
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
CATALOGS = [os.path.join(ROOT, "DaysRemember", "Resources", "Assets.xcassets"),
            os.path.join(ROOT, "DaysRememberWidget", "Assets.xcassets")]
SITE = os.path.join(ROOT, "docs", "assets", "covers")
ONLY = set(sys.argv[1:])

W = "#FFFFFF"
CORAL, CORAL_D = "#F2785C", "#D95C42"
SUN, SUN_D = "#F6BE3B", "#E3A21F"
SKY, SKY_D = "#6AA6E6", "#4C88CC"
LEAF, LEAF_D = "#4FAE7C", "#3C9466"
COCOA = "#C98652"
INK = "#3A3542"


def tone(o=0.12):
    return f'fill="#24222B" fill-opacity="{o}"'


def stroke_tone(w, o=0.22):
    return f'fill="none" stroke="#24222B" stroke-opacity="{o}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"'


def stroke(c, w):
    return f'fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"'


def flower(cx, cy, d, r, petal, center, cr):
    out = []
    for k in range(5):
        a = math.radians(-90 + 72 * k)
        out.append(f'<circle cx="{cx + d * math.cos(a):.1f}" cy="{cy + d * math.sin(a):.1f}" r="{r}" fill="{petal}"/>')
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{cr}" fill="{center}"/>')
    return "".join(out)


def leaf(cx, cy, rx, ry, rot, c):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="{c}"/>'


COVERS = {}

COVERS["flowers"] = "".join([
    f'<ellipse cx="100" cy="182" rx="44" ry="7" {tone()}/>',
    f'<path d="M100 118 L74 64" {stroke(LEAF_D, 5)}/>',
    f'<path d="M100 118 L100 46" {stroke(LEAF_D, 5)}/>',
    f'<path d="M100 118 L128 70" {stroke(LEAF_D, 5)}/>',
    leaf(84, 94, 15, 6.5, -50, LEAF),
    leaf(116, 98, 15, 6.5, 48, LEAF),
    f'<path d="M84 112 h32 v8 c14 8 20 20 20 34 c0 16 -12 26 -36 26 c-24 0 -36 -10 -36 -26 c0 -14 6 -26 20 -34 z" fill="{W}"/>',
    f'<rect x="80" y="106" width="40" height="10" rx="5" fill="{W}"/>',
    f'<rect x="67" y="146" width="66" height="8" {tone(0.14)}/>',
    flower(73, 60, 11, 11, CORAL, SUN, 7),
    flower(128, 66, 9, 9, CORAL, SUN, 6),
    flower(100, 42, 10, 10, SUN, CORAL, 7),
])

COVERS["celebration"] = "".join([
    f'<ellipse cx="100" cy="180" rx="66" ry="7" {tone()}/>',
    f'<ellipse cx="100" cy="166" rx="70" ry="12" fill="{SKY}"/>',
    f'<rect x="54" y="104" width="92" height="62" rx="16" fill="{W}"/>',
    f'<path d="M58 118 q7 9 14 0 q7 11 14 0 q7 9 14 0 q7 11 14 0 q7 9 14 0 q7 9 12 0" {stroke_tone(3, 0.16)}/>',
    f'<rect x="54" y="134" width="92" height="10" fill="{CORAL}"/>',
    f'<circle cx="78" cy="100" r="9" fill="{CORAL}"/><circle cx="100" cy="96" r="9" fill="{CORAL}"/><circle cx="122" cy="100" r="9" fill="{CORAL}"/>',
    leaf(78, 91, 5, 2.5, 0, LEAF), leaf(122, 91, 5, 2.5, 0, LEAF),
    f'<rect x="96" y="60" width="8" height="30" rx="3" fill="{SKY}"/>',
    f'<path d="M100 40 c7 9 8 14 0 19 c-8 -5 -7 -10 0 -19 z" fill="{SUN}"/>',
    f'<rect x="34" y="70" width="8" height="4" rx="2" transform="rotate(-30 38 72)" fill="{CORAL}"/>',
    f'<rect x="158" y="62" width="8" height="4" rx="2" transform="rotate(30 162 64)" fill="{SUN}"/>',
    f'<rect x="150" y="36" width="8" height="4" rx="2" transform="rotate(-20 154 38)" fill="{SKY}"/>',
    f'<rect x="44" y="40" width="8" height="4" rx="2" transform="rotate(25 48 42)" fill="{SUN}"/>',
])

COVERS["garden"] = "".join([
    f'<ellipse cx="104" cy="182" rx="70" ry="7" {tone()}/>',
    f'<path d="M42 128 L18 104" {stroke(SKY, 8)}/>',
    f'<rect x="10" y="96" width="16" height="10" rx="4" transform="rotate(-45 18 101)" fill="{SKY_D}"/>',
    f'<path d="M54 112 C54 88 82 88 82 112" {stroke(SKY_D, 6)}/>',
    f'<rect x="36" y="110" width="56" height="64" rx="14" fill="{SKY}"/>',
    f'<rect x="36" y="128" width="56" height="8" fill="{W}" fill-opacity="0.55"/>',
    leaf(128, 96, 9, 22, -40, LEAF),
    leaf(162, 94, 9, 22, 40, LEAF),
    leaf(145, 84, 9, 24, 0, LEAF_D),
    flower(145, 56, 9, 8, W, SUN, 7),
    f'<path d="M114 132 h62 l-8 46 h-46 z" fill="{CORAL}"/>',
    f'<rect x="108" y="120" width="74" height="16" rx="7" fill="{CORAL_D}"/>',
])

COVERS["homecoming"] = "".join([
    f'<ellipse cx="100" cy="180" rx="74" ry="8" {tone()}/>',
    f'<rect x="122" y="52" width="16" height="34" rx="3" fill="{CORAL_D}"/>',
    f'<circle cx="38" cy="160" r="17" fill="{LEAF}"/><circle cx="56" cy="168" r="12" fill="{LEAF_D}"/>',
    f'<circle cx="162" cy="160" r="17" fill="{LEAF}"/><circle cx="144" cy="168" r="12" fill="{LEAF_D}"/>',
    f'<rect x="56" y="94" width="88" height="80" rx="6" fill="{W}"/>',
    f'<path d="M50 98 L100 54 L150 98 Z" fill="{CORAL}" stroke="{CORAL}" stroke-width="10" stroke-linejoin="round"/>',
    f'<rect x="56" y="98" width="88" height="8" {tone(0.12)}/>',
    f'<rect x="88" y="130" width="24" height="44" rx="11" fill="{SKY}"/>',
    f'<circle cx="106" cy="154" r="2.5" fill="{W}"/>',
    f'<rect x="64" y="116" width="18" height="18" rx="4" fill="{SUN}"/>',
    f'<rect x="118" y="116" width="18" height="18" rx="4" fill="{SUN}"/>',
])

COVERS["journal"] = "".join([
    f'<ellipse cx="100" cy="176" rx="76" ry="8" {tone()}/>',
    f'<path d="M20 80 Q62 66 100 82 Q138 66 180 80 V166 Q138 154 100 168 Q62 154 20 166 Z" fill="{SKY}"/>',
    f'<path d="M28 72 Q64 60 100 76 V160 Q64 146 28 156 Z" fill="{W}"/>',
    f'<path d="M172 72 Q136 60 100 76 V160 Q136 146 172 156 Z" fill="{W}"/>',
    f'<path d="M100 76 V160" {stroke_tone(2, 0.18)}/>',
    f'<path d="M42 92 L84 96 M42 106 L84 110 M42 120 L74 123" {stroke_tone(3, 0.16)}/>',
    f'<path d="M116 96 L158 92 M116 110 L158 106" {stroke_tone(3, 0.16)}/>',
    f'<path d="M140 152 v26 l7 -6 l7 6 v-28" fill="{CORAL}"/>',
    f'<g transform="rotate(-32 126 120)"><rect x="80" y="114" width="80" height="13" rx="6.5" fill="{CORAL}"/>'
    f'<rect x="86" y="114" width="10" height="13" fill="{CORAL_D}"/>'
    f'<path d="M160 114 L178 120.5 L160 127 Z" fill="{SUN}"/></g>',
])

COVERS["voyage"] = "".join([
    f'<ellipse cx="100" cy="182" rx="66" ry="8" {tone()}/>',
    f'<path d="M80 66 v-12 a8 8 0 0 1 8 -8 h24 a8 8 0 0 1 8 8 v12" {stroke_tone(8, 0.26)}/>',
    f'<circle cx="62" cy="172" r="7" {tone(0.26)}/><circle cx="138" cy="172" r="7" {tone(0.26)}/>',
    f'<rect x="40" y="64" width="120" height="104" rx="18" fill="{CORAL}"/>',
    f'<rect x="60" y="64" width="10" height="104" fill="{CORAL_D}"/>',
    f'<rect x="130" y="64" width="10" height="104" fill="{CORAL_D}"/>',
    f'<circle cx="100" cy="100" r="15" fill="{SUN}"/>',
    f'<rect x="85" y="126" width="30" height="20" rx="5" transform="rotate(-8 100 136)" fill="{W}"/>',
    f'<path d="M146 30 L184 16 L170 52 L161 39 Z" fill="{W}"/>',
    f'<path d="M161 39 L184 16" {stroke_tone(2, 0.2)}/>',
])

COVERS["companionship"] = "".join([
    f'<ellipse cx="100" cy="168" rx="80" ry="18" fill="{SKY}"/>',
    f'<ellipse cx="76" cy="150" rx="34" ry="20" fill="{W}"/>',
    f'<ellipse cx="134" cy="152" rx="30" ry="18" fill="{SUN}"/>',
    leaf(46, 102, 11, 22, 14, COCOA),
    leaf(108, 102, 11, 22, -14, COCOA),
    f'<circle cx="77" cy="106" r="32" fill="{W}"/>',
    f'<path d="M108 98 L112 70 L128 88 Z" fill="{SUN}"/><path d="M156 98 L152 70 L136 88 Z" fill="{SUN}"/>',
    f'<path d="M112 92 L114 78 L122 88 Z" fill="{CORAL}"/><path d="M152 92 L150 78 L142 88 Z" fill="{CORAL}"/>',
    f'<circle cx="132" cy="112" r="27" fill="{SUN}"/>',
    f'<circle cx="67" cy="102" r="3.6" fill="{INK}"/><circle cx="87" cy="102" r="3.6" fill="{INK}"/>',
    f'<ellipse cx="77" cy="116" rx="6" ry="4.5" fill="{INK}"/>',
    f'<circle cx="122" cy="112" r="3.2" fill="{INK}"/><circle cx="142" cy="112" r="3.2" fill="{INK}"/>',
    f'<path d="M128 120 h8 l-4 4 z" fill="{CORAL}"/>',
    f'<path d="M104 62 C92 54 86 48 86 42 a8 8 0 0 1 18 -3 a8 8 0 0 1 18 3 c0 6 -6 12 -18 20 z" fill="{CORAL}"/>',
])

COVERS["everyday"] = "".join([
    f'<ellipse cx="100" cy="178" rx="78" ry="8" {tone()}/>',
    leaf(24, 92, 8, 20, -30, LEAF), leaf(48, 90, 8, 20, 30, LEAF), leaf(36, 82, 8, 22, 0, LEAF_D),
    f'<rect x="16" y="114" width="40" height="42" rx="7" fill="{SUN}"/>',
    f'<path d="M74 112 Q54 132 76 154" {stroke(SKY_D, 8)}/>',
    f'<path d="M144 128 Q166 118 170 98" {stroke(SKY, 10)}/>',
    f'<ellipse cx="110" cy="134" rx="38" ry="34" fill="{SKY}"/>',
    f'<ellipse cx="110" cy="100" rx="19" ry="6" fill="{SKY_D}"/>',
    f'<circle cx="110" cy="91" r="5" fill="{SKY_D}"/>',
    f'<path d="M168 154 a10 10 0 0 1 0 16" {stroke(W, 6)}/>',
    f'<path d="M134 148 h40 v8 a18 18 0 0 1 -18 18 h-4 a18 18 0 0 1 -18 -18 z" fill="{W}"/>',
    f'<rect x="134" y="156" width="40" height="5" fill="{CORAL}"/>',
    f'<path d="M150 138 q-6 -8 0 -16 q6 -8 0 -16" {stroke_tone(3, 0.22)}/>',
])

COVERS["coast"] = "".join([
    f'<circle cx="54" cy="54" r="18" fill="{SUN}"/>',
    f'<path d="M78 134 Q114 82 158 134 Z" fill="{LEAF}"/>',
    f'<rect x="104" y="106" width="20" height="16" fill="{W}"/>',
    f'<path d="M100 108 L114 96 L128 108 Z" fill="{CORAL}"/>',
    f'<circle cx="140" cy="108" r="9" fill="{LEAF_D}"/>',
    f'<path d="M20 134 Q40 126 60 134 T100 134 T140 134 T180 134 V166 Q100 184 20 166 Z" fill="{SKY}"/>',
    f'<path d="M48 152 q10 -6 20 0 M112 160 q10 -6 20 0" {stroke(W, 4)}/>',
    f'<path d="M58 126 V90" {stroke_tone(2.5, 0.3)}/>',
    f'<path d="M60 124 V92 L84 122 Z" fill="{W}"/>',
    f'<path d="M38 128 h40 l-7 11 h-26 z" fill="{CORAL}"/>',
])

COVERS["mountains"] = "".join([
    f'<circle cx="152" cy="50" r="16" fill="{SUN}"/>',
    f'<ellipse cx="100" cy="172" rx="82" ry="9" {tone()}/>',
    f'<path d="M72 160 L120 72 L172 160 Z" {tone(0.2)}/>',
    f'<path d="M22 164 L82 60 L142 164 Z" fill="{SKY}"/>',
    f'<path d="M82 60 L97 86 L89 82 L81 90 L73 82 L67 86 Z" fill="{W}"/>',
    f'<path d="M120 72 L132 94 L125 90 L118 96 L111 90 L108 94 Z" fill="{W}"/>',
    f'<path d="M30 170 L44 130 L58 170 Z" fill="{LEAF}"/>',
    f'<path d="M144 172 L160 124 L176 172 Z" fill="{LEAF_D}"/>',
])

COVERS["cafe"] = "".join([
    f'<ellipse cx="100" cy="174" rx="80" ry="8" {tone()}/>',
    f'<ellipse cx="72" cy="162" rx="44" ry="10" fill="{W}"/>',
    f'<ellipse cx="72" cy="162" rx="44" ry="10" {tone(0.08)}/>',
    f'<path d="M100 126 a12 12 0 0 1 0 24" {stroke(W, 8)}/>',
    f'<path d="M44 116 h56 v18 a26 26 0 0 1 -26 26 h-4 a26 26 0 0 1 -26 -26 z" fill="{W}"/>',
    f'<rect x="44" y="128" width="56" height="6" fill="{CORAL}"/>',
    f'<ellipse cx="72" cy="116" rx="28" ry="6" fill="{COCOA}"/>',
    f'<path d="M64 104 q-6 -8 0 -16 q6 -8 0 -16 M80 104 q-6 -8 0 -16 q6 -8 0 -16" {stroke_tone(3, 0.22)}/>',
    f'<ellipse cx="150" cy="166" rx="40" ry="7" fill="{W}"/>',
    f'<path d="M108 164 C110 124 190 124 192 164 C178 152 122 152 108 164 Z" fill="{SUN}"/>',
    f'<path d="M128 142 L134 156 M150 134 L150 152 M172 142 L166 156" {stroke(SUN_D, 4)}/>',
    f'<circle cx="109" cy="163" r="5" fill="{SUN_D}"/><circle cx="191" cy="163" r="5" fill="{SUN_D}"/>',
])

COVERS["camping"] = "".join([
    f'<path d="M158 28 A18 18 0 1 0 168 60 A14 14 0 1 1 158 28 Z" fill="{SUN}"/>',
    f'<circle cx="60" cy="40" r="3" fill="{W}"/><circle cx="96" cy="28" r="2.5" fill="{W}"/><circle cx="120" cy="56" r="2.5" fill="{W}"/>',
    f'<ellipse cx="100" cy="172" rx="84" ry="9" {tone()}/>',
    f'<path d="M18 170 L38 112 L58 170 Z" fill="{LEAF}"/>',
    f'<path d="M26 142 L38 100 L50 142 Z" fill="{LEAF}"/>',
    f'<path d="M146 170 L166 106 L186 170 Z" fill="{LEAF_D}"/>',
    f'<path d="M50 170 L100 82 L150 170 Z" fill="{CORAL}" stroke="{CORAL}" stroke-width="6" stroke-linejoin="round"/>',
    f'<path d="M100 108 L80 170 H120 Z" fill="{CORAL_D}"/>',
    f'<path d="M100 126 L89 170 H111 Z" fill="{INK}" fill-opacity="0.35"/>',
    f'<circle cx="132" cy="162" r="6" fill="{SUN}"/>',
])

CONTENTS = """{
  "images" : [
    {
      "filename" : "%s.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
"""

for name, body in COVERS.items():
    if ONLY and name not in ONLY:
        continue
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200">{body}</svg>\n'
    for catalog in CATALOGS:
        folder = os.path.join(catalog, f"Flat{name[0].upper()}{name[1:]}.imageset")
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, f"{name}.svg"), "w") as fh:
            fh.write(svg)
        with open(os.path.join(folder, "Contents.json"), "w") as fh:
            fh.write(CONTENTS % name)
        print(os.path.relpath(folder))
    os.makedirs(SITE, exist_ok=True)
    with open(os.path.join(SITE, f"{name}.svg"), "w") as fh:
        fh.write(svg)
