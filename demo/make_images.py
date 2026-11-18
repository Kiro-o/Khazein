"""Draws a simple flat illustration for every demo product (no brands, no
text) into demo/hosting/products/<id>.png, served by the demo project's
Firebase Hosting.

    python demo/make_images.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).parent
OUT = HERE / "hosting" / "products"
SIZE = 400
S = 4  # supersampling for smooth edges


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def mix(color, other, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(color, other))


WHITE = (255, 255, 255)


def draw(shape, color):
    img = Image.new("RGB", (SIZE * S, SIZE * S), mix(color, WHITE, 0.9))
    d = ImageDraw.Draw(img)
    c = color
    dark = mix(color, (0, 0, 0), 0.25)
    light = mix(color, WHITE, 0.55)

    def r(x0, y0, x1, y1, radius=0, fill=c):
        d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius * S, fill=fill)

    def e(x0, y0, x1, y1, fill=c):
        d.ellipse([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill)

    def p(points, fill=c):
        d.polygon([(x * S, y * S) for x, y in points], fill=fill)

    # Soft floor shadow.
    e(110, 330, 290, 356, fill=mix(color, WHITE, 0.78))

    if shape == "bottle":
        r(178, 60, 222, 100, 8, dark)
        p([(170, 100), (230, 100), (262, 150), (138, 150)])
        r(138, 140, 262, 340, 26)
        r(150, 200, 250, 270, 10, WHITE)
        r(162, 222, 238, 248, 6, light)
    elif shape == "jug":
        r(150, 70, 200, 104, 8, dark)
        r(120, 96, 280, 340, 30)
        r(232, 120, 272, 200, 16, mix(color, WHITE, 0.9))
        r(136, 200, 264, 280, 12, WHITE)
    elif shape == "pump":
        r(186, 62, 250, 80, 6, dark)
        r(190, 76, 210, 120, 4, dark)
        r(150, 118, 250, 140, 8, dark)
        r(140, 136, 260, 340, 34)
        r(156, 210, 244, 276, 12, WHITE)
    elif shape == "spray":
        p([(180, 60), (260, 60), (260, 86), (210, 100), (180, 100)], dark)
        r(176, 96, 226, 130, 8, dark)
        r(146, 126, 254, 340, 30)
        r(160, 200, 240, 272, 12, WHITE)
    elif shape == "can":
        r(140, 80, 260, 340, 26)
        e(140, 70, 260, 104, dark)
        r(140, 170, 260, 250, 0, WHITE)
        r(140, 186, 260, 234, 0, light)
    elif shape == "tin":
        r(110, 150, 290, 330, 20)
        e(110, 134, 290, 174, dark)
        r(110, 200, 290, 280, 0, WHITE)
        e(160, 216, 240, 264, light)
    elif shape == "carton":
        p([(140, 110), (200, 60), (260, 110)], dark)
        r(140, 106, 260, 340, 10)
        r(150, 170, 250, 270, 10, WHITE)
        e(176, 192, 224, 246, light)
    elif shape == "jar":
        r(146, 80, 254, 118, 10, dark)
        r(128, 112, 272, 340, 36)
        r(144, 180, 256, 276, 14, WHITE)
    elif shape == "tub":
        r(110, 150, 290, 186, 14, dark)
        p([(116, 180), (284, 180), (268, 330), (132, 330)])
        r(142, 214, 258, 290, 12, WHITE)
    elif shape == "box":
        r(110, 100, 290, 340, 14)
        r(110, 100, 290, 140, 14, dark)
        r(132, 180, 268, 300, 14, WHITE)
        e(170, 200, 230, 280, light)
    elif shape == "bag":
        p([(130, 90), (270, 90), (292, 340), (108, 340)])
        r(130, 80, 270, 108, 6, dark)
        r(140, 190, 260, 300, 18, WHITE)
        e(168, 206, 232, 282, light)
    elif shape == "chips":
        p([(120, 70), (280, 70), (296, 340), (104, 340)])
        r(120, 70, 280, 92, 0, dark)
        r(104, 318, 296, 340, 0, dark)
        e(140, 160, 260, 280, WHITE)
        e(170, 190, 230, 250, light)
    elif shape == "bar":
        r(80, 170, 320, 270, 18)
        r(80, 170, 120, 270, 0, dark)
        r(280, 170, 320, 270, 0, dark)
        r(140, 192, 260, 248, 10, WHITE)
    elif shape == "roll":
        r(150, 90, 250, 330, 18, WHITE)
        r(150, 90, 250, 330, 18, light)
        r(162, 90, 238, 330, 0, WHITE)
        e(150, 76, 250, 108, c)
        e(186, 84, 214, 100, dark)
    else:
        raise ValueError(f"unknown shape {shape}")

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    catalog = json.loads((HERE / "catalog.json").read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    # The video's "new product" is not seeded, only its image is hosted.
    for product in catalog["products"] + [catalog["video_product"]]:
        img = draw(product["shape"], hex_rgb(product["color"]))
        path = OUT / f"{product['id']}.png"
        img.quantize(colors=64).save(path, optimize=True)
        total += path.stat().st_size
    print(f"{len(catalog['products']) + 1} images, {total // 1024} KB in {OUT}")


if __name__ == "__main__":
    main()
