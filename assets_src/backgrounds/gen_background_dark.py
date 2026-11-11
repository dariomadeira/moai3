"""Modo oscuro (2026-11-10): el fondo actual, de noche.

Uso: python gen_background_dark.py <fondo.webp> <oscuro.webp> <vidrio.webp>

Del fondo claro se queda con un décimo de su luz, con el color (cuánto se
aparta cada punto de su gris: las curvas celeste, durazno y lila) y con las
variaciones de luz (la curva), sobre un azul casi negro. Con más color
quedaba en rojo y azul puros; éste es el punto elegido entre cuatro pruebas. El del
vidrio esmerilado sale del oscuro igual que los otros: mitad de resolución y
desenfoque gaussiano de radio 30.

Por punto: base + MUL * canal + CHROMA * (canal - gris) + LIGHT * (gris -
gris medio), que es lineal: va en una matriz de color de PIL (sin numpy).
"""
import sys

from PIL import Image, ImageFilter, ImageStat

src_path, out_path, blur_path = sys.argv[1:4]

# Base: casi negro azulado (con MUL queda cerca del `surfaceContainer`
# del tema oscuro, #101217, un poco más azul).
BASE = (8, 10, 20)
# Cuánto de la luz del claro.
MUL = 0.10
# Cuánto color se trae.
CHROMA = 0.9
# Cuánto de las variaciones de luz del claro (alrededor de su promedio).
LIGHT = 0.4

src = Image.open(src_path).convert("RGB")
mean_gray = sum(ImageStat.Stat(src).mean) / 3

other = (LIGHT - CHROMA) / 3
own = MUL + CHROMA + other
matrix = []
for c in range(3):
    row = [own if i == c else other for i in range(3)]
    matrix += row + [BASE[c] - LIGHT * mean_gray]
img = src.convert("RGB", tuple(matrix))

W, H = img.size
img.save(out_path, quality=90)
b = img.resize((W // 2, H // 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(30))
b.save(blur_path, quality=85)
