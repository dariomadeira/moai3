"""El fondo claro de la app, desenfocado a partir de `new_font.jpg`.

Uso: py -3 gen_background_new.py new_font.jpg \
    ../../assets/images/background_light.webp \
    ../../assets/images/background_light_blur.webp

El fondo es la foto (misma resolución) con desenfoque gaussiano; el del
vidrio esmerilado sale de ese mismo fondo, a la mitad de resolución y con
radio 30.
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
