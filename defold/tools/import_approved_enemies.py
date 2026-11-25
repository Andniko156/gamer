"""Package approved concept-derived transparent character sheets as GUI atlas sprites.

The four source sheets use four columns and two rows with ample transparent
padding. Output keeps a common foot pivot and leaves the approved sheets intact.
"""
from PIL import Image
from pathlib import Path

ART = Path(__file__).resolve().parents[1] / 'art'
SHEETS = {name: Image.open(ART / 'source_sheets' / f'{name}.png').convert('RGBA')
          for name in ('dock', 'quarter', 'express', 'bastion')}
# Map game roles 1..10 to a (sheet, cell) in the approved enemy designs.
ROLES = {
    1: [('dock',0),('dock',1),('dock',2),('dock',3),('dock',5),('quarter',5),
        ('dock',4),('dock',6),('dock',7),('express',6)],
    2: [('quarter',0),('quarter',1),('quarter',2),('quarter',3),('quarter',4),('quarter',6),
        ('quarter',6),('quarter',7),('quarter',5),('quarter',3)],
    3: [('express',1),('express',0),('express',2),('express',3),('express',4),('express',7),
        ('express',5),('express',6),('express',2),('express',6)],
    4: [('bastion',0),('bastion',1),('bastion',2),('bastion',3),('bastion',4),('bastion',7),
        ('bastion',5),('bastion',6),('bastion',6),('bastion',5)],
}
for arena, roles in ROLES.items():
    for kind, (sheet_name, cell) in enumerate(roles, 1):
        source = SHEETS[sheet_name]
        cw, ch = source.width // 4, source.height // 2
        x, y = (cell % 4) * cw, (cell // 4) * ch
        cut = source.crop((x, y, x + cw, y + ch))
        alpha = cut.getchannel('A').point(lambda value: value if value >= 24 else 0)
        cut.putalpha(alpha)
        bounds = alpha.getbbox()
        if not bounds:
            raise ValueError(f'empty sprite: arena={arena} kind={kind}')
        cut = cut.crop(bounds)
        size = 96 if kind == 6 else 64
        span = 92 if kind == 6 else 58
        scale = min(span / cut.width, span / cut.height)
        dimensions = max(1, round(cut.width * scale)), max(1, round(cut.height * scale))
        cut = cut.resize(dimensions, Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (size, size))
        canvas.alpha_composite(cut, ((size - cut.width) // 2, size - cut.height - 2))
        canvas.save(ART / f'enemy_{arena}_{kind}.png', optimize=True)
