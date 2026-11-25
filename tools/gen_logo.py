"""Genera el logo de neón de FICHINLIKE (assets/art/menu/logo_*.png).

Uso:  python tools/gen_logo.py      (requiere numpy y Pillow)
Escribe cuatro capas del mismo tamaño para animar el parpadeo en Godot:
logo_fichin, logo_like (letras) y logo_glow_pink, logo_glow_cyan (halos).
El fondo del menú no se genera acá: es arcade_bg.png, hecho con Retro
Diffusion (ver tools/gen_menu_fx.py).
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "art", "menu")
FONT_BIG = os.path.join(ROOT, "assets", "fonts", "Jersey10-Regular.ttf")
W, H = 640, 360

# --- Paleta "arcade de barrio" -------------------------------------------------
P = {
    "night0": (11, 7, 22), "night1": (22, 13, 38), "night2": (35, 20, 54),
    "night3": (50, 27, 74), "night4": (71, 37, 95),
    "wall0": (31, 19, 48), "wall1": (42, 26, 64), "wall2": (56, 35, 82),
    "pink": (255, 63, 164), "pink_l": (255, 138, 208), "pink_d": (150, 30, 100),
    "cyan": (53, 227, 255), "cyan_l": (168, 246, 255), "cyan_d": (20, 110, 150),
    "yellow": (255, 216, 74), "yellow_l": (255, 243, 168), "orange": (255, 138, 61),
    "red": (232, 59, 79), "red_d": (130, 28, 48), "green": (76, 224, 138), "green_d": (28, 110, 70),
    "blue": (59, 108, 255), "blue_d": (30, 50, 140), "purple": (155, 92, 255), "purple_d": (80, 45, 150),
    "white": (255, 246, 240), "wood": (107, 59, 42), "wood_l": (142, 82, 54), "wood_d": (66, 34, 26),
    "floor_a": (29, 16, 48), "floor_b": (90, 32, 80), "metal": (120, 120, 150), "metal_d": (60, 60, 85),
    "black": (6, 4, 12),
}


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def new(w=W, h=H, fill=None):
    return Image.new("RGBA", (w, h), rgba(fill) if fill else (0, 0, 0, 0))


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


# --- Logo de neón ----------------------------------------------------------------------

def text_mask(text, size, scale):
    font = ImageFont.truetype(FONT_BIG, size)
    l, t, r, b = font.getbbox(text)
    m = Image.new("L", (r - l + 2, b - t + 2), 0)
    dm = ImageDraw.Draw(m)
    dm.fontmode = "1"  # sin suavizado: píxeles exactos
    dm.text((1 - l, 1 - t), text, font=font, fill=255)
    m = m.point(lambda v: 255 if v > 127 else 0)
    if scale > 1:
        m = m.resize((m.width * scale, m.height * scale), Image.NEAREST)
    return np.array(m) > 0


def erode(a, n):
    out = a.copy()
    for _ in range(n):
        o = out.copy()
        o[1:, :] &= out[:-1, :]
        o[:-1, :] &= out[1:, :]
        o[:, 1:] &= out[:, :-1]
        o[:, :-1] &= out[:, 1:]
        out = o
    return out


def dilate(a, n):
    out = a.copy()
    for _ in range(n):
        o = out.copy()
        o[1:, :] |= out[:-1, :]
        o[:-1, :] |= out[1:, :]
        o[:, 1:] |= out[:, :-1]
        o[:, :-1] |= out[:, 1:]
        out = o
    return out


def neon_word(text, size, scale, c_tube, c_core, c_back):
    """Letras de neón: placa oscura + tubo de color con núcleo claro."""
    m = text_mask(text, size, scale)
    pad = 6
    m = np.pad(m, pad)
    plate = dilate(m, 3)
    inner = erode(m, 2)
    tube = m & ~inner
    core = tube & ~dilate(~m, 1) if False else (m & ~erode(m, 1)) & False
    # Tubo: borde de la letra de 2 px; núcleo: 1 px dentro del borde.
    edge2 = m & ~erode(m, 2)
    edge1 = m & ~erode(m, 1)
    core = edge2 & ~edge1
    h, w = m.shape
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    arr[plate] = rgba(c_back, 255)
    arr[m & ~edge2] = rgba(c_back, 255)
    arr[edge1] = rgba(c_tube)
    arr[core] = rgba(c_core)
    return Image.fromarray(arr, "RGBA"), (m | plate)


def glow_of(img, color, radius):
    a = np.array(img)[:, :, 3]
    mask = Image.fromarray(a).filter(ImageFilter.GaussianBlur(radius))
    g = Image.new("RGBA", img.size, rgba(color, 0))
    g.putalpha(mask.point(lambda v: min(255, int(v * 1.2))))
    return g


def make_logo(layout):
    # La fuente se ve bien desde 20 px (trazos de 2 px); se agranda sin suavizar.
    fichin, _ = neon_word("FICHIN", 20, 6, P["pink"], P["white"], P["night0"])
    like, _ = neon_word("LIKE", 20, 4, P["cyan"], P["white"], P["night0"])
    like = like.rotate(8, resample=Image.NEAREST, expand=True)
    w = fichin.width + 30
    h = fichin.height + like.height - 18
    logo = new(w, h)
    logo.alpha_composite(fichin, (0, 0))
    lx, ly = w - like.width, fichin.height - 26
    logo.alpha_composite(like, (lx, ly))
    # Sub-capas separadas para animar el parpadeo en Godot.
    fichin_only = new(w, h)
    fichin_only.alpha_composite(fichin, (0, 0))
    like_only = new(w, h)
    like_only.alpha_composite(like, (lx, ly))
    pad = 24
    def padded(im):
        p = new(im.width + pad * 2, im.height + pad * 2)
        p.alpha_composite(im, (pad, pad))
        return p
    fichin_only, like_only = padded(fichin_only), padded(like_only)
    glow_pink = glow_of(fichin_only, P["pink"], 8)
    glow_cyan = glow_of(like_only, P["cyan"], 8)
    layout["logo_size"] = [fichin_only.width, fichin_only.height]
    return fichin_only, like_only, glow_pink, glow_cyan


def main():
    os.makedirs(OUT, exist_ok=True)
    fichin, like, glow_p, glow_c = make_logo({})
    for name, im in [("logo_fichin", fichin), ("logo_like", like),
                     ("logo_glow_pink", glow_p), ("logo_glow_cyan", glow_c)]:
        im.save(os.path.join(OUT, name + ".png"))
    print("Logo generado en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
