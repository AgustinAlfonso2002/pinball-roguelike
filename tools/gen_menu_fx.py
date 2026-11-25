"""Genera la máscara de animación del fondo del menú.

Lee assets/art/menu/arcade_bg.png (480x270, hecho con Retro Diffusion) y escribe
assets/art/menu/arcade_fx.png, del mismo tamaño. El shader del menú
(assets/shaders/arcade_bg.gdshader) la usa para animar los píxeles del fondo:

  R  pantallas de las máquinas: 0 = nada, 1..255 = fase de cada pantalla
  G  tubos de neón: 60 = rosa, 120 = celeste, 180 = azul del fondo
  B  luces: 1..127 = titilan (tableros, marquesinas, backglass),
            128..255 = lámparas del techo (pulso suave)

Si se cambia la imagen de fondo, ajustar las zonas de abajo y volver a correr:
    python tools/gen_menu_fx.py   (requiere numpy, scipy y Pillow)
"""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/art/menu/arcade_bg.png"
OUT = ROOT / "assets/art/menu/arcade_fx.png"

# Zonas (x, y, ancho, alto) en píxeles del fondo.
CABINETS = (110, 95, 330, 55)       # pantallas y marquesinas
PLAYFIELDS = (130, 140, 300, 60)    # tableros de los flippers
BACKGLASS = (400, 100, 40, 48)      # cartel iluminado del flipper de adelante
NEON_PINK = [(75, 40, 9, 92), (75, 40, 48, 11), (214, 82, 64, 6)]
NEON_CYAN = [(354, 15, 40, 30), (288, 72, 20, 16), (0, 130, 30, 10)]
NEON_BLUE = [(186, 86, 24, 18)]
BULBS = [(225, 36, 26, 14), (150, 64, 18, 10), (310, 64, 18, 10)]


def box_mask(shape, boxes):
    m = np.zeros(shape, bool)
    for x, y, w, h in boxes:
        m[y:y + h, x:x + w] = True
    return m


def main():
    im = np.asarray(Image.open(SRC).convert("RGB")).astype(int)
    h, w, _ = im.shape
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mx, mn = im.max(2), im.min(2)
    sat = mx - mn
    rng = np.random.default_rng(7)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., 3] = 255

    # Pantallas: píxeles brillantes y saturados azules/celestes/rosas.
    screen = box_mask((h, w), [CABINETS]) & (mx > 120) & (sat > 50) & (b > 110) & ~((r > 200) & (b < 150))
    lab, n = ndimage.label(ndimage.binary_dilation(screen, iterations=1))
    phases = rng.integers(1, 256, n + 1)
    out[..., 0] = np.where(screen, phases[lab], 0)

    # Neón.
    pink = box_mask((h, w), NEON_PINK) & (r > 170) & (b > 120) & (g < 130)
    cyan = box_mask((h, w), NEON_CYAN) & (b > 170) & (g > 120) & (r < 150)
    blue = box_mask((h, w), NEON_BLUE) & (b > 150) & (sat > 60)
    out[..., 1] = np.where(pink, 60, np.where(cyan, 120, np.where(blue, 180, 0)))

    # Luces que titilan: amarillas/naranjas de marquesinas y backglass, tableros.
    warm = (r > 190) & (g > 120) & (b < 160)
    play = (sat > 70) & (mx > 150)
    twinkle = (box_mask((h, w), [CABINETS, BACKGLASS]) & warm) | (box_mask((h, w), [PLAYFIELDS]) & play)
    twinkle &= out[..., 0] == 0
    bulbs = box_mask((h, w), BULBS) & (r > 180) & (g > 110)
    lights = np.zeros((h, w), np.uint8)
    lights[twinkle] = rng.integers(1, 128, twinkle.sum())
    lights[bulbs] = rng.integers(128, 256, bulbs.sum())
    out[..., 2] = lights

    Image.fromarray(out, "RGBA").save(OUT)
    print(f"{OUT.name}: pantallas={screen.sum()} neón={(out[...,1]>0).sum()} luces={twinkle.sum()} lámparas={bulbs.sum()}")


if __name__ == "__main__":
    main()
