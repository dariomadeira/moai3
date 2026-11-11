"""PRUEBA (2026-11-02): fondo desenfocado a partir de `assets/images/new font.jpg`.

Uso: python gen_background_new.py <fuente.jpg> <fondo.webp> <vidrio.webp>

El fondo es la foto (misma resolución) con desenfoque gaussiano; el del
vidrio esmerilado sale de ese mismo fondo, a la mitad de resolución y con
radio 30, como `background_color_blur.webp`.
"""
import sys

from PIL import Image, ImageFilter

src_path, out_path, blur_path = sys.argv[1:4]

src = Image.open(src_path).convert("RGB")
W, H = src.size
out = src.filter(ImageFilter.GaussianBlur(40))
out.save(out_path, quality=90)
b = out.resize((W // 2, H // 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(30))
b.save(blur_path, quality=85)
