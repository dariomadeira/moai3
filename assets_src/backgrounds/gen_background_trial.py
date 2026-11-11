"""PRUEBA (2026-11-03): fondo de la app a partir de una imagen ya difusa
(`assets/images/2.jpg`, `assets/images/2.png`).

Uso: py -3 gen_background_trial.py <fuente> <fondo.webp> <vidrio.webp>

El fondo es la fuente recortada al centro a 16:9 y llevada a 2912 de ancho
(como `background_color.webp`), sin desenfoque extra: ya es un degradado
suave. El del vidrio esmerilado sale de ese fondo a la mitad de resolución
y con desenfoque gaussiano de radio 30, como `background_color_blur.webp`.
"""
import sys

from PIL import Image, ImageFilter

src_path, out_path, blur_path = sys.argv[1:4]
W, H = 2912, 1638

src = Image.open(src_path).convert("RGB")
sw, sh = src.size
# Recorte central a 16:9.
if sw / sh > W / H:
    cw = round(sh * W / H)
    box = ((sw - cw) // 2, 0, (sw - cw) // 2 + cw, sh)
else:
    ch = round(sw * H / W)
    box = (0, (sh - ch) // 2, sw, (sh - ch) // 2 + ch)
out = src.crop(box).resize((W, H), Image.LANCZOS)
out.save(out_path, quality=90)
b = out.resize((W // 2, H // 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(30))
b.save(blur_path, quality=85)
print(out_path, out.size, "|", blur_path, b.size)
