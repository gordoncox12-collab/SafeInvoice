#!/usr/bin/env python3
"""Generate Play Console icon and feature graphic with real TTF metrics."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "play" / "store"
TEAL = (15, 118, 110, 255)
TEAL_DEEP = (13, 84, 80, 255)
TEAL_INK = (19, 78, 74, 255)
CREAM = (255, 251, 245, 255)
GOLD = (214, 158, 46, 255)
CRIMSON = (220, 20, 60, 255)
WHITE = (255, 255, 255, 255)
LINE = (15, 118, 110, 255)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)


def rounded_rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_invoice_card(img: Image.Image, x: int, y: int, w: int, h: int) -> None:
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, (x, y, x + w, y + h), 28, CREAM)
    draw.rectangle((x, y, x + w, y + 52), fill=GOLD)
    fold = [(x + w - 46, y), (x + w, y), (x + w, y + 46)]
    draw.polygon(fold, fill=(196, 140, 32, 255))
    for i, width in enumerate((0.88, 0.72, 0.80, 0.58)):
        top = y + 88 + i * 36
        draw.rounded_rectangle((x + 28, top, x + 28 + int((w - 56) * width), top + 14), 7, fill=LINE)
    draw.rounded_rectangle((x + 28, y + h - 56, x + w - 28, y + h - 32), 8, fill=CRIMSON)


def make_icon() -> None:
    size = 512
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), 108, fill=TEAL)
    card_w, card_h = 292, 360
    cx = (size - card_w) // 2
    cy = (size - card_h) // 2 + 8
    draw_invoice_card(img, cx, cy, card_w, card_h)
    label = ImageDraw.Draw(img)
    f = font("DejaVuSans-Bold.ttf", 42)
    label.text((cx + 28, cy + 8), "SI", font=f, fill=TEAL_INK)
    STORE.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(STORE / "icon-512.png", "PNG")


def make_feature() -> None:
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), TEAL_DEEP[:3])
    draw = ImageDraw.Draw(img)
    draw.rectangle((520, 0, w, h), fill=TEAL[:3])
    title = font("DejaVuSans-Bold.ttf", 64)
    body = font("DejaVuSans.ttf", 28)
    chips = font("DejaVuSans.ttf", 20)
    draw.text((56, 118), "SafeInvoice", font=title, fill=WHITE)
    draw.text((56, 210), "Offline invoicing for", font=body, fill=WHITE)
    draw.text((56, 248), "South African businesses", font=body, fill=WHITE)
    draw.text((56, 340), "VAT  ·  PDF  ·  WhatsApp  ·  On-device books", font=chips, fill=GOLD)
    draw_invoice_card(img, 640, 70, 300, 360)
    caption = font("DejaVuSans-Bold.ttf", 16)
    ImageDraw.Draw(img).text((668, 82), "TAX INVOICE", font=caption, fill=TEAL_INK)
    STORE.mkdir(parents=True, exist_ok=True)
    img.save(STORE / "feature-graphic-1024x500.png", "PNG")


if __name__ == "__main__":
    make_icon()
    make_feature()
    print(f"wrote {STORE / 'icon-512.png'}")
    print(f"wrote {STORE / 'feature-graphic-1024x500.png'}")
