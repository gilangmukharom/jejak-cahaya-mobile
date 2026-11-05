"""Konsep logo NUSAVERSE dalam SVG (vektor, tepi tajam di ukuran berapa pun).

Tiga arah desain:

- ``orbit``   — pin lokasi emas berbintang dikelilingi cincin orbit, dengan
                "bulan" merah-putih yang mengitarinya: menemukan pahlawan
                (bintang) di tempat nyata (pin) dalam semesta Nusantara (orbit).
- ``compass`` — mawar kompas delapan arah; arah utara merah-putih.
- ``trail``   — monogram N dari jejak perjalanan yang berujung bintang.

Dipakai oleh ``render_logo.py`` untuk membuat PNG ikon peluncur & logo aplikasi.
"""

NAVY_TOP = '#2A5490'
NAVY = '#17345E'
NAVY_DARK = '#0B1A32'
GOLD_HI = '#FFE7A3'
GOLD_L = '#F8CD6A'
GOLD = '#F4B52B'
GOLD_D = '#C98A12'
GOLD_DD = '#9A6608'
RED = '#D92332'
WHITE = '#F8F8F4'

DEFS = f'''
<linearGradient id="gold" x1="0.15" y1="0" x2="0.85" y2="1">
  <stop offset="0" stop-color="{GOLD_HI}"/><stop offset="0.35" stop-color="{GOLD_L}"/>
  <stop offset="0.65" stop-color="{GOLD}"/><stop offset="1" stop-color="{GOLD_D}"/>
</linearGradient>
<linearGradient id="goldDark" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="{GOLD}"/><stop offset="1" stop-color="{GOLD_DD}"/>
</linearGradient>
<linearGradient id="ring" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="{GOLD_D}"/><stop offset="0.5" stop-color="{GOLD_HI}"/><stop offset="1" stop-color="{GOLD_D}"/>
</linearGradient>
<radialGradient id="navyDisc" cx="0.42" cy="0.35" r="0.8">
  <stop offset="0" stop-color="{NAVY_TOP}"/><stop offset="0.6" stop-color="{NAVY}"/><stop offset="1" stop-color="{NAVY_DARK}"/>
</radialGradient>
<radialGradient id="bg" cx="0.5" cy="0.38" r="0.75">
  <stop offset="0" stop-color="#2F5C9C"/><stop offset="0.5" stop-color="{NAVY}"/><stop offset="1" stop-color="{NAVY_DARK}"/>
</radialGradient>
<filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
  <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#000" flood-opacity="0.35"/>
</filter>
'''


def star_points(cx, cy, r_out, r_in, rotation=-90):
    import math
    pts = []
    for i in range(10):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rotation + i * 36)
        pts.append(f'{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}')
    return ' '.join(pts)


def faceted_star(cx, cy, r_out, r_in, light='url(#gold)', dark='url(#goldDark)'):
    """Bintang dua nada: tiap ujung dibelah dua sisi terang/gelap, kesan pahatan."""
    import math
    parts = []
    for i in range(5):
        a = math.radians(-90 + i * 72)
        a_l = math.radians(-90 + i * 72 - 36)
        a_r = math.radians(-90 + i * 72 + 36)
        tip = (cx + r_out * math.cos(a), cy + r_out * math.sin(a))
        left = (cx + r_in * math.cos(a_l), cy + r_in * math.sin(a_l))
        right = (cx + r_in * math.cos(a_r), cy + r_in * math.sin(a_r))
        parts.append(f'<path d="M{cx:.1f} {cy:.1f}L{left[0]:.1f} {left[1]:.1f}L{tip[0]:.1f} {tip[1]:.1f}Z" fill="{light}"/>')
        parts.append(f'<path d="M{cx:.1f} {cy:.1f}L{tip[0]:.1f} {tip[1]:.1f}L{right[0]:.1f} {right[1]:.1f}Z" fill="{dark}"/>')
    return ''.join(parts)


# ───────────────────────────── konsep A: orbit ─────────────────────────────

def mark_orbit():
    """Pusat visual ~ (512, 540). Lebar orbit 800, tinggi pin 680."""
    cx, cy = 512, 560          # pusat orbit
    tilt = -16
    orbit = f'<ellipse cx="{cx}" cy="{cy}" rx="392" ry="112" fill="none" stroke="url(#ring)" stroke-width="24"/>'
    back = (f'<clipPath id="back"><rect x="0" y="0" width="1024" height="{cy}"/></clipPath>'
            f'<clipPath id="front"><rect x="0" y="{cy}" width="1024" height="1024"/></clipPath>')
    # bulan merah-putih di orbit depan (parameter sudut 38°)
    import math
    t = math.radians(38)
    mx, my = cx + 392 * math.cos(t), cy + 112 * math.sin(t)
    moon = (f'<g transform="translate({mx:.1f} {my:.1f})"><circle r="50" fill="{WHITE}"/>'
            f'<path d="M-50 0A50 50 0 0 1 50 0Z" fill="{RED}"/>'
            f'<circle r="50" fill="none" stroke="#0B1A32" stroke-opacity=".25" stroke-width="3"/></g>')
    pin = ('<path d="M512 880C452 798 284 642 284 432A228 228 0 1 1 740 432C740 642 572 798 512 880Z" '
           'fill="url(#gold)"/>')
    # sorot lembut di sisi kiri pin
    shine = ('<path d="M330 360A190 190 0 0 1 470 226" fill="none" stroke="#FFF6D6" stroke-opacity=".55" '
             'stroke-width="16" stroke-linecap="round"/>')
    disc = '<circle cx="512" cy="432" r="160" fill="url(#navyDisc)"/>'
    star = faceted_star(512, 442, 118, 47)
    return (f'<defs>{back}</defs>'
            f'<g transform="rotate({tilt} {cx} {cy})" clip-path="url(#back)">{orbit}</g>'
            f'<g filter="url(#soft)">{pin}</g>{shine}{disc}{star}'
            f'<g transform="rotate({tilt} {cx} {cy})"><g clip-path="url(#front)">{orbit}</g>{moon}</g>')


# ──────────────────────────── konsep B: kompas ─────────────────────────────

def mark_compass():
    import math
    c = 512
    out = [f'<circle cx="{c}" cy="{c}" r="350" fill="none" stroke="url(#ring)" stroke-width="18"/>',
           f'<circle cx="{c}" cy="{c}" r="300" fill="none" stroke="{GOLD}" stroke-opacity=".35" stroke-width="4"/>']
    # mata angin minor (diagonal)
    for i in range(4):
        a = math.radians(45 + i * 90)
        tip = (c + 230 * math.cos(a), c + 230 * math.sin(a))
        l = (c + 48 * math.cos(a - math.pi / 2), c + 48 * math.sin(a - math.pi / 2))
        r = (c + 48 * math.cos(a + math.pi / 2), c + 48 * math.sin(a + math.pi / 2))
        out.append(f'<path d="M{l[0]:.1f} {l[1]:.1f}L{tip[0]:.1f} {tip[1]:.1f}L{r[0]:.1f} {r[1]:.1f}Z" fill="{NAVY_TOP}" stroke="{GOLD_L}" stroke-width="5"/>')
    # mata angin utama
    for i in range(4):
        a = math.radians(-90 + i * 90)
        length = 400 if i == 0 else 330
        tip = (c + length * math.cos(a), c + length * math.sin(a))
        l = (c + 70 * math.cos(a - math.pi / 2), c + 70 * math.sin(a - math.pi / 2))
        r = (c + 70 * math.cos(a + math.pi / 2), c + 70 * math.sin(a + math.pi / 2))
        lf, rf = (RED, WHITE) if i == 0 else ('url(#gold)', 'url(#goldDark)')
        out.append(f'<path d="M{c} {c}L{l[0]:.1f} {l[1]:.1f}L{tip[0]:.1f} {tip[1]:.1f}Z" fill="{lf}"/>')
        out.append(f'<path d="M{c} {c}L{tip[0]:.1f} {tip[1]:.1f}L{r[0]:.1f} {r[1]:.1f}Z" fill="{rf}"/>')
    out.append(f'<circle cx="{c}" cy="{c}" r="62" fill="url(#navyDisc)" stroke="{GOLD}" stroke-width="10"/>')
    out.append(f'<polygon points="{star_points(c, c + 3, 34, 14)}" fill="{GOLD_L}"/>')
    return f'<g filter="url(#soft)">{"".join(out)}</g>'


# ───────────────────────────── konsep C: jejak ─────────────────────────────

def mark_trail():
    # Batang huruf N sebagai bentuk isi, bukan garis bergradien: gradien
    # objectBoundingBox pada garis lurus (lebar kotak 0) tidak tergambar.
    bars = ('<rect x="254" y="254" width="92" height="552" rx="46" fill="url(#gold)"/>'
            '<rect x="678" y="374" width="92" height="432" rx="46" fill="url(#gold)"/>')
    dots = ''.join(f'<circle cx="{330 + i * 72.8:.1f}" cy="{300 + i * 84:.1f}" r="22" fill="{GOLD_L}"/>' for i in range(6))
    return (f'<g filter="url(#soft)">{bars}{dots}'
            f'{faceted_star(724, 250, 150, 60)}'
            f'<path d="M300 830h424" stroke="{RED}" stroke-width="22" stroke-linecap="round"/>'
            f'<path d="M512 830h212" stroke="{WHITE}" stroke-width="22" stroke-linecap="round"/></g>')


CONCEPTS = {'orbit': (mark_orbit, (512, 548)), 'compass': (mark_compass, (512, 512)), 'trail': (mark_trail, (512, 530))}


def svg(concept, scale=1.0, background=False, size=1024):
    """SVG lengkap. [scale] = skala marka relatif kanvas 1024; [background] = latar navy."""
    mark_fn, (mx, my) = CONCEPTS[concept]
    bg = f'<rect width="1024" height="1024" fill="url(#bg)"/>' if background else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">'
            f'<defs>{DEFS}</defs>{bg}'
            f'<g transform="translate(512 512) scale({scale}) translate({-mx} {-my})">{mark_fn()}</g></svg>')


def background_svg(size=1024):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">'
            f'<defs>{DEFS}</defs><rect width="1024" height="1024" fill="url(#bg)"/></svg>')
