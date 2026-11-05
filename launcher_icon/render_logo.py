"""Merender logo NUSAVERSE (SVG di logo_concepts.py) menjadi PNG.

Rasterisasi memakai Chrome/Edge headless supaya hasilnya identik dengan
peramban — gradien, filter bayangan, dan antialias SVG tidak perlu ditiru ulang
di Pillow.

    python -I launcher_icon/render_logo.py            # konsep bawaan: orbit
    python -I launcher_icon/render_logo.py compass    # konsep lain
    dart run flutter_launcher_icons

Berkas yang ditulis:

| Berkas                               | Isi                                              |
| ------------------------------------ | ------------------------------------------------ |
| launcher_icon/app_icon.png           | ikon penuh berlatar navy (iOS, Android < 26)     |
| launcher_icon/app_icon_background.png| lapisan latar adaptive icon                      |
| launcher_icon/app_icon_foreground.png| marka transparan, skala 0,74 (zona aman 66 dp)   |
| assets/images/nusaverse_logo.png     | marka transparan untuk splash & login            |
"""
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from logo_concepts import CONCEPTS, background_svg, svg  # noqa: E402

BROWSERS = [
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    '/usr/bin/google-chrome', '/usr/bin/chromium',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
]


def browser():
    for path in BROWSERS:
        if os.path.exists(path):
            return path
    found = shutil.which('chrome') or shutil.which('chromium') or shutil.which('msedge')
    if not found:
        sys.exit('Chrome/Edge tidak ditemukan — dibutuhkan untuk merender SVG.')
    return found


def render(svg_text, out_path, size=1024, opaque=False):
    work = tempfile.mkdtemp()
    try:
        html = os.path.join(work, 'logo.html')
        with open(html, 'w', encoding='utf-8') as f:
            f.write('<!doctype html><html><head><style>html,body{margin:0;background:transparent}'
                    'svg{display:block}</style></head><body>' + svg_text.replace('width="1024" height="1024"', f'width="{size}" height="{size}"', 1) +
                    '</body></html>')
        shot = os.path.join(work, 'shot.png')
        subprocess.run([browser(), '--headless=new', '--disable-gpu', '--hide-scrollbars',
                        '--force-device-scale-factor=1', '--default-background-color=00000000',
                        f'--window-size={size},{size}', f'--screenshot={shot}', 'file:///' + html.replace('\\', '/')],
                       check=True, capture_output=True)
        img = Image.open(shot).convert('RGBA').crop((0, 0, size, size))
        if opaque:
            img = img.convert('RGB')
        img.save(out_path)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    concept = sys.argv[1] if len(sys.argv) > 1 else 'orbit'
    if concept not in CONCEPTS:
        sys.exit(f'Konsep tidak dikenal: {concept}. Pilihan: {", ".join(CONCEPTS)}')
    assets = os.path.join(HERE, '..', 'assets', 'images')
    render(svg(concept, 0.86, background=True), os.path.join(HERE, 'app_icon.png'), opaque=True)
    render(background_svg(), os.path.join(HERE, 'app_icon_background.png'), opaque=True)
    render(svg(concept, 0.74), os.path.join(HERE, 'app_icon_foreground.png'))
    render(svg(concept, 0.95), os.path.join(assets, 'nusaverse_logo.png'), size=768)
    print(f'logo NUSAVERSE ({concept}) dirender')


if __name__ == '__main__':
    main()
