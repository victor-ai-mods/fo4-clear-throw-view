"""
Обложка для Nexus из двух скриншотов с одной точки (images/vanila.png и images/mod.png):
слева ванилла (траекторию закрывает оружие), справа — с модом.

    images/cover.png   1920x1080 — картинка галереи / миниатюра
    images/banner.png  1300x372  — шапка страницы

    python tools/gen_cover.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, 'images')
FONT = r'C:\Windows\Fonts\bahnschrift.ttf'

GREEN = (26, 255, 110)
RED = (255, 90, 70)
WHITE = (235, 240, 235)
DARK = (8, 14, 22)


def font(size, weight='Bold'):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except (OSError, ValueError):
        pass
    return f


def panel(src, box, size):
    return Image.open(os.path.join(IMG, src)).convert('RGB').crop(box).resize(size, Image.LANCZOS)


def text_center(draw, cx, y, text, f, fill, shadow=True):
    w = draw.textlength(text, font=f)
    if shadow:
        draw.text((cx - w / 2 + 3, y + 3), text, font=f, fill=(0, 0, 0))
    draw.text((cx - w / 2, y), text, font=f, fill=fill)


def label(img, cx, y, text, color, size):
    """Подпись в полупрозрачной плашке."""
    f = font(size)
    d = ImageDraw.Draw(img, 'RGBA')
    w = d.textlength(text, font=f)
    pad_x, pad_y = size * 0.6, size * 0.28
    d.rounded_rectangle((cx - w / 2 - pad_x, y - pad_y, cx + w / 2 + pad_x, y + size + pad_y * 1.4),
                        radius=int(size * 0.35), fill=(0, 0, 0, 170), outline=color + (255,), width=3)
    d.text((cx - w / 2, y), text, font=f, fill=color)


def divider(img, x, top=0, color=WHITE):
    d = ImageDraw.Draw(img)
    d.line((x, top, x, img.height), fill=color, width=4)


def cover():
    W, H, TOP = 1920, 1080, 230
    img = Image.new('RGB', (W, H), DARK)
    # Одна и та же область обоих кадров: траектория и оружие, без строки HUD внизу слева.
    box = (250, 100, 1425, 1140)
    pw, ph = W // 2, H - TOP
    img.paste(panel('vanila.png', box, (pw, ph)), (0, TOP))
    img.paste(panel('mod.png', box, (pw, ph)), (pw, TOP))
    divider(img, pw, TOP)
    d = ImageDraw.Draw(img)
    d.line((0, TOP, W, TOP), fill=GREEN, width=4)
    text_center(d, W / 2, 28, 'CLEAR THROW VIEW', font(120), GREEN)
    text_center(d, W / 2, 160, 'The weapon is lowered while you aim a grenade - see exactly where it lands',
                font(40, 'SemiBold'), WHITE)
    label(img, pw / 2, TOP + 40, 'VANILLA', RED, 54)
    label(img, pw + pw / 2, TOP + 40, 'WITH CLEAR THROW VIEW', GREEN, 54)
    img.save(os.path.join(IMG, 'cover.png'))


def banner():
    # Слева — название на тёмной полосе, справа — два кадра, траектория целиком
    # (вершина ~y 650, точка падения ~y 1060 исходника).
    W, H, LEFT = 1300, 372, 420
    img = Image.new('RGB', (W, H), DARK)
    pw = (W - LEFT) // 2
    ph = H
    box_h = 640
    box_w = int(box_h * pw / ph)
    box = (1000 - box_w // 2 - 60, 470, 1000 + box_w // 2 - 60, 470 + box_h)
    img.paste(panel('vanila.png', box, (pw, ph)), (LEFT, 0))
    img.paste(panel('mod.png', box, (pw, ph)), (LEFT + pw, 0))
    divider(img, LEFT + pw)
    d = ImageDraw.Draw(img)
    d.line((LEFT, 0, LEFT, H), fill=GREEN, width=4)
    cx = LEFT / 2
    for i, word in enumerate(('CLEAR', 'THROW', 'VIEW')):
        text_center(d, cx, 38 + i * 92, word, font(96), GREEN)
    label(img, LEFT + pw / 2, 22, 'VANILLA', RED, 30)
    label(img, LEFT + pw + pw / 2, 22, 'WITH THE MOD', GREEN, 30)
    img.save(os.path.join(IMG, 'banner.png'))


if __name__ == '__main__':
    cover()
    banner()
    print('images/cover.png, images/banner.png')
