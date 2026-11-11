import sys, math
from PIL import Image, ImageDraw, ImageFilter
src_path, out_path, blur_path, thumb_path = sys.argv[1:5]
base = Image.open(src_path).convert('RGB')
W, H = base.size
s = W / 1920

def curve(y0, amp, freq, phase, width, blur, strength, tilt=0.0):
    m = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(m)
    pts = [(x, H * y0 + tilt * (x / W - 0.5) * H
            + amp * s * math.sin(x / W * 2 * math.pi * freq + phase)
            + 0.25 * amp * s * math.sin(x / W * 2 * math.pi * freq * 2.2 + phase * 1.7))
           for x in range(int(-60 * s), int(W + 60 * s), int(6 * s))]
    d.line(pts, fill=255, width=int(width * s), joint='curve')
    return m.filter(ImageFilter.GaussianBlur(blur * s)).point(lambda v: int(v * strength))

# Curvas de color tenues, siguiendo la onda gris (que baja a la izquierda,
# sube al centro y vuelve a bajar a la derecha).
curves = [
    ((140, 175, 235), curve(0.58, 120, 1.0, 2.4, 150, 70, 0.75)),            # celeste
    ((255, 185, 150), curve(0.40, 90, 0.9, 3.1, 110, 65, 0.60, tilt=-0.1)),  # durazno
    ((190, 160, 240), curve(0.76, 100, 1.1, 2.0, 130, 75, 0.65, tilt=0.08)), # lila
    ((150, 215, 220), curve(0.24, 70, 0.8, 1.2, 90, 70, 0.45)),              # agua
]
from PIL import ImageChops
out = base
for color, mask in curves:
    # Teñido (multiplicar y devolver la luz): respeta luces y sombras.
    tint = ImageChops.multiply(base, Image.new('RGB', (W, H), color))
    # Devuelve la luz que quita el color (su luminancia): el gris queda
    # igual de claro, sólo cambia el tono.
    luma = 0.299 * color[0] + 0.587 * color[1] + 0.114 * color[2]
    k = 255 / luma
    tint = tint.point(lambda v: min(255, int(v * k)))
    out = Image.composite(tint, out, mask)
out.save(out_path, quality=90)
b = out.resize((W // 2, H // 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(30))
b.save(blur_path, quality=85)
out.resize((960, 538), Image.LANCZOS).save(thumb_path)
