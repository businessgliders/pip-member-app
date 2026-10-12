#!/usr/bin/env python3
"""Compose Pilates in Pink app icons (light/dark/tinted) + in-app logo."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps
import os

LOGO = "/tmp/iconwork/logo.png"
OUT = "/tmp/iconwork/out"
os.makedirs(OUT, exist_ok=True)

CREAM = (246, 238, 231)
BLUSH = (251, 224, 226)
PINK = (241, 136, 155)
CARAMEL = (182, 118, 81)
INK = (26, 20, 24)
SOFT_PINK = (247, 177, 189)
S = 1024
SERIF = "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def diagonal_gradient(size, c1, c2):
    """Diagonal gradient c1 (top-left) -> c2 (bottom-right)."""
    mask = Image.linear_gradient("L").resize((size * 2, size * 2)).rotate(45, expand=False)
    mask = mask.crop((size // 2, size // 2, size // 2 + size, size // 2 + size))
    solid1 = Image.new("RGB", (size, size), c1)
    solid2 = Image.new("RGB", (size, size), c2)
    return Image.composite(solid2, solid1, mask)


def radial_glow(size, center, radius, color, peak_alpha, blur):
    """Return RGBA layer with a soft radial glow."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    cx, cy = center
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    mask = mask.point(lambda v: int(v * peak_alpha))
    layer = Image.new("RGBA", (size, size), color + (0,))
    layer.putalpha(mask)
    return layer


def load_logo(width):
    im = Image.open(LOGO).convert("RGBA")
    ratio = width / im.width
    return im.resize((width, int(im.height * ratio)), Image.LANCZOS)


def draw_tracked(canvas, text, font, tracking, center_x, center_y, color):
    """Draw letterspaced text centered at (center_x, center_y)."""
    widths = []
    for ch in text:
        bbox = font.getbbox(ch)
        widths.append(font.getlength(ch))
    total = sum(widths) + tracking * (len(text) - 1)
    asc, desc = font.getmetrics()
    x = center_x - total / 2
    y = center_y - (asc + desc) / 2
    d = ImageDraw.Draw(canvas)
    for ch, w in zip(text, widths):
        d.text((x, y), ch, font=font, fill=color)
        x += w + tracking
    return total


def make_icon(dark=False):
    canvas = Image.new("RGBA", (S, S))
    if dark:
        bg = diagonal_gradient(S, (36, 28, 33), INK)
        canvas.paste(bg, (0, 0))
        canvas = Image.alpha_composite(canvas, radial_glow(S, (170, 140), 430, PINK, 0.22, 220))
        canvas = Image.alpha_composite(canvas, radial_glow(S, (890, 900), 400, CARAMEL, 0.20, 220))
        text_color = SOFT_PINK
        shadow = (0, 0, 0, 150)
    else:
        bg = diagonal_gradient(S, CREAM, BLUSH)
        canvas.paste(bg, (0, 0))
        canvas = Image.alpha_composite(canvas, radial_glow(S, (930, 60), 460, CARAMEL, 0.30, 240))
        canvas = Image.alpha_composite(canvas, radial_glow(S, (60, 980), 430, PINK, 0.22, 240))
        text_color = CARAMEL
        shadow = (120, 60, 60, 70)

    logo = load_logo(620)
    lx = (S - logo.width) // 2
    ly = 150

    # soft drop shadow behind the mark
    alpha = logo.getchannel("A").point(lambda v: int(v / 255 * shadow[3]))
    sh = Image.new("RGBA", logo.size, shadow[:3] + (0,))
    sh.putalpha(alpha)
    sh = sh.filter(ImageFilter.GaussianBlur(26))
    canvas.alpha_composite(sh, (lx + 10, ly + 18))

    canvas.alpha_composite(logo, (lx, ly))

    font = ImageFont.truetype(SERIF, 64)
    draw_tracked(canvas, "STUDIO", font, 26, S // 2, 902, text_color + (255,))
    return canvas.convert("RGB")


light = make_icon(dark=False)
light.save(f"{OUT}/icon-light.png")
dark = make_icon(dark=True)
dark.save(f"{OUT}/icon-dark.png")

# Tinted: grayscale of the light design; the system applies the tint.
ImageOps.grayscale(light).convert("RGB").save(f"{OUT}/icon-tinted.png")

# In-app logo (transparent, brand mark only)
logo = load_logo(1024)
logo.save(f"{OUT}/app-logo.png")
print("done")
