"""Prepare combat atlases from the approved arsenal and enemy sheets."""
from collections import Counter
from math import degrees, pi
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps

ART = Path(__file__).resolve().parents[1] / "art"
OUTPUT = ART / "combat"
OUTPUT.mkdir(exist_ok=True)
ARSENAL = Image.open(ART / "source_sheets/arsenal.png").convert("RGBA")
NEAREST = Image.Resampling.NEAREST
LANCZOS = Image.Resampling.LANCZOS

# Rectangles are measured on a 750 × 500 reference preview of the approved sheet.
ARSENAL_CROPS = {
    "rail": (17, 71, 105, 126), "rail_evo": (137, 53, 244, 127),
    "pendulum": (278, 64, 347, 129), "pendulum_evo": (379, 53, 489, 128),
    "sprayer": (522, 69, 596, 127), "sprayer_evo": (632, 56, 741, 128),
    "capacitor": (12, 372, 82, 450), "chronometer": (263, 369, 341, 443),
    "alchemist_heart": (509, 371, 588, 442),
    "rail_0": (38, 196, 64, 216), "rail_1": (78, 192, 132, 218),
    "rail_2": (150, 191, 232, 218), "rail_3": (159, 238, 249, 292),
    "swing_0": (282, 190, 327, 226), "swing_1": (348, 181, 406, 222),
    "swing_2": (420, 177, 491, 224), "swing_3": (421, 237, 495, 294),
    "acid_0": (516, 193, 546, 220), "acid_1": (549, 186, 598, 220),
    "acid_2": (596, 183, 657, 224), "acid_3": (668, 178, 739, 224),
    "acid_4": (571, 243, 648, 288), "acid_5": (650, 235, 739, 293),
    "electric": (165, 365, 239, 442), "clock": (429, 368, 489, 438),
}


def contain(sprite, size):
    sprite.thumbnail(size, LANCZOS)
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(sprite, ((size[0] - sprite.width) // 2, (size[1] - sprite.height) // 2))
    return canvas


def crop_arsenal(box):
    rect = tuple(round(v * ARSENAL.size[i % 2] / (750, 500)[i % 2]) for i, v in enumerate(box))
    source = ARSENAL.crop(rect)
    source.putalpha(source.getchannel("A").point(lambda value: 0 if value < 18 else value))
    return source.crop(source.getbbox())


def save(image, name):
    if "_foe_" in name and "_death_" not in name:
        alpha = image.getchannel("A").filter(ImageFilter.MaxFilter(3))
        edge = Image.new("RGBA", image.size, (20, 26, 34, 0))
        edge.putalpha(alpha.point(lambda opacity: round(opacity * .85)))
        edge.alpha_composite(image)
        image = edge
    image.save(OUTPUT / f"{name}.png", optimize=True)
    return f"/art/combat/{name}.png"


def atlas(name, entries):
    (ART / f"{name}.atlas").write_text(
        "\n".join(entries + ["margin: 2", "extrude_borders: 2", "inner_padding: 2", ""]), encoding="utf-8")


arsenal_entries = []
for name, box in ARSENAL_CROPS.items():
    size = (96, 96) if name.startswith(("swing_", "acid_")) or name in ("electric", "clock") else (96, 64)
    sprite = crop_arsenal(box)
    if name in ("rail", "rail_evo", "sprayer", "sprayer_evo"):
        sprite = ImageOps.mirror(sprite)
    arsenal_entries.append(f'images {{ image: "{save(contain(sprite, size), name)}" }}')
def outline(name, segments, width):
    image = Image.new("RGBA", (128, 128))
    draw = ImageDraw.Draw(image)
    for segment in range(segments):
        start = degrees(segment * 2 * pi / segments)
        end = start + 360 / segments * .83
        draw.arc((2, 2, 125, 125), start, end, fill="white", width=width)
    arsenal_entries.append(f'images {{ image: "{save(image, name)}" }}')


outline("threat_ring", 14, 2)
outline("impact_ring", 14, 4)


def transform_pose(base, shift, stride, squash=0):
    size = base.width
    cut = round(size * .64)
    chassis = base.crop((0, 0, size, cut)).transform(
        (size, cut), Image.Transform.AFFINE, (1, stride / (cut * 2), -shift, 0, 1, 0), NEAREST)
    gear = base.crop((0, cut, size, size)).transform(
        (size, size - cut), Image.Transform.AFFINE, (1, 0, -stride, 0, 1, 0), NEAREST)
    frame = Image.new("RGBA", base.size)
    frame.alpha_composite(gear, (0, cut))
    frame.alpha_composite(chassis, (0, 0))
    if squash:
        frame = frame.resize((size, size - squash), NEAREST)
        result = Image.new("RGBA", base.size)
        result.alpha_composite(frame, (0, squash))
        return result
    return frame


def tint(frame, color, strength):
    layer = ImageOps.colorize(ImageOps.grayscale(frame), "#170c11", color)
    blended = Image.blend(frame.convert("RGB"), layer, strength).convert("RGBA")
    blended.putalpha(frame.getchannel("A"))
    return blended


def variant(base, enemy):
    colors = ("#8affff", "#ffd182", "#d4b0ef")
    color = colors[enemy % len(colors)]
    frame = tint(base, color, .48)
    # Alternative armour and signal lamp distinguish reused source silhouettes.
    bounds = frame.getbbox()
    x = bounds[0] + (bounds[2] - bounds[0]) // 3
    y = bounds[1] + (bounds[3] - bounds[1]) // 4
    size = max(3, frame.width // 12)
    for side in (-1, 1):
        pad_x = x + side * (bounds[2] - bounds[0]) // 4
        ImageDraw.Draw(frame).polygon(
            [(pad_x-size, y), (pad_x, y-size*2), (pad_x+size, y), (pad_x, y+size)],
            fill="#a66a44", outline="#f8c47a")
    ImageDraw.Draw(frame).rectangle((x-2, y-1, x+1, y+2), fill=color)
    return frame


for name, source, color in (("enemy_bolt", "rail_2", "#ffb653"),
                             ("enemy_arc", "swing_1", "#ff9850")):
    image = Image.open(OUTPUT / f"{source}.png").convert("RGBA")
    arsenal_entries.append(f'images {{ image: "{save(tint(image, color, .92), name)}" }}')
atlas("arsenal", arsenal_entries)

def fragments(base, phase):
    size = base.width
    cut = size // 2
    frame = Image.new("RGBA", base.size)
    for index, tile in enumerate(((0, 0, cut, cut), (cut, 0, size, cut),
                                  (0, cut, cut, size), (cut, cut, size, size))):
        part = base.crop(tile)
        part.putalpha(part.getchannel("A").point(lambda v: v * max(0, 8 - phase) // 8))
        frame.paste(part, (tile[0] + (-phase if index % 2 == 0 else phase),
                           tile[1] + (-phase if index < 2 else phase)))
    return frame


seen = Counter()
for arena in range(1, 5):
    entries = []
    for enemy in range(1, 11):
        filename = f"enemy_{arena}_{enemy}.png"
        original = (ART / filename).read_bytes()
        seen[original] += 1
        base = Image.open(ART / filename).convert("RGBA")
        if seen[original] > 1:
            base = variant(base, enemy)
        step = max(2, base.width // 22)
        animations = {
            "idle": [base, transform_pose(base, 0, 0, 1)],
            "move": [transform_pose(base, 1, step), base, transform_pose(base, -1, -step),
                     transform_pose(base, 0, 0, 1)],
            "charge": [tint(transform_pose(base, -step, 1, 2), "#fd9956", .23),
                       tint(transform_pose(base, -step, 0, 3), "#ffcf88", .57)],
            "attack": [transform_pose(base, step * 2, 0), transform_pose(base, step, -1)],
            "hit": [tint(transform_pose(base, -step, 0, 2), "#ffb587", .75)],
            "death": [fragments(base, phase) for phase in (1, 3, 6)],
        }
        for state, frames in animations.items():
            for index, frame in enumerate(frames):
                path = save(frame, f"a{arena}_foe_{enemy}_{state}_{index}")
                entries.append(f'images {{ image: "{path}" }}')
    atlas(f"foes_{arena}", entries)
