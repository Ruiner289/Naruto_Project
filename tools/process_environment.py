"""Extract reviewed source rectangles and assemble pixel-art hex terrain. Requires Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance
import hashlib, json, math

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/environment_source'
OUT = ROOT / 'assets/environment'
OUT.mkdir(parents=True, exist_ok=True)
audit = {'repository': 'https://github.com/Ruiner289/Naruto_Project_Sprite',
         'commit': '7066534', 'sources': [], 'assets': []}
for file in sorted(SOURCE.glob('*.png')):
    audit['sources'].append({'file': file.name, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest()})

def crop(file, rect):
    return Image.open(SOURCE / file).convert('RGBA').crop(rect)

def save(name, im, file, rect, **details):
    im.save(OUT / (name + '.png'))
    audit['assets'].append({'id': name, 'source': file, 'rect': list(rect),
                            'size': list(im.size), 'sha256': hashlib.sha256((OUT / (name + '.png')).read_bytes()).hexdigest(), **details})

# Exact sheet backdrop keys, including enclosed spaces. No green tolerance.
props = {
    'tree_oak': ('Tilesets.png', (121, 281, 194, 409), (0, 255, 0)),
    'tree_pine': ('Tilesets.png', (195, 281, 266, 410), (0, 255, 0)),
    'bush': ('Tilesets.png', (202, 414, 266, 447), (0, 255, 0)),
    'rock': ('Tilesets.png', (78, 419, 202, 473), (0, 255, 0)),
    'dead_tree': ('Tilesets.png', (10, 427, 80, 535), (0, 255, 0)),
    'fallen_log': ('Tilesets.png', (57, 688, 265, 740), (0, 255, 0)),
    'village_house': ('Konoha Objects.png', (9, 418, 345, 552), (0, 128, 0)),
    'village_shop': ('Konoha Objects.png', (368, 418, 778, 552), (0, 128, 0)),
    'outpost': ('Konoha Objects.png', (627, 572, 858, 705), (0, 128, 0)),
    'stall': ('Konoha Objects.png', (412, 180, 500, 258), (0, 128, 0)),
}
for name, (file, rect, key) in props.items():
    im = crop(file, rect)
    before = list(im.getdata())
    im.putdata([(r, g, b, 0 if (r, g, b) == key else a) for r, g, b, a in before])
    assert all(out == original for out, original in zip(im.getdata(), before) if original[:3] != key)
    excluded_rects = []
    if name == 'tree_oak':
        # Neighbouring platform occupies only this reviewed lower-left rectangle.
        excluded_rects = [[0, 74, 18, 128]]
        ImageDraw.Draw(im).rectangle((0, 74, 17, 127), fill=(0, 0, 0, 0))
    assert im.getbbox() is not None
    save(name, im, file, rect, key=list(key), excluded_rects=excluded_rects, transform='exact-key transparency; preserve non-key pixels outside reviewed neighbour exclusion')

materials = {
    'plain': ('Forest.png', (16, 218, 144, 250), (1.0, 1.0, 1.0)),
    'road': ('Boss Stage.png', (20, 154, 148, 188), (0.87, 0.86, 0.79)),
    'forest': ('Forest.png', (144, 218, 272, 250), (0.66, 0.78, 0.64)),
    'swamp': ('Forest.png', (300, 223, 428, 249), (0.69, 0.70, 0.61)),
    'mountain': ('Tilesets.png', (298, 1083, 362, 1102), (0.94, 0.93, 0.89)),
    'water': ('Forest of Death 1.png', (2, 1270, 130, 1312), (0.91, 0.97, 1.0)),
    'blocked': ('Tilesets.png', (15, 365, 85, 405), (0.83, 0.87, 0.86)),
}
mask = Image.new('L', (64, 74))
vertices = [(32 + math.cos(math.radians(60*i-30))*36,
             37 + math.sin(math.radians(60*i-30))*36) for i in range(6)]
ImageDraw.Draw(mask).polygon(vertices, fill=255)
for name, (file, rect, tint) in materials.items():
    patch = crop(file, rect).convert('RGB')
    assert all(px != (0, 255, 0) for px in patch.getdata()), (name, rect)
    for variant in range(3):
        # Sample an unlabelled ground region. Mirror/offset source pixels for variation.
        im = Image.new('RGBA', (64, 74))
        px = patch.load()
        data = []
        for y in range(74):
            for x in range(64):
                sx = (x + variant * 23) % patch.width
                if variant == 1:
                    sx = patch.width-1-sx
                sy = (y + variant*7) % (2*patch.height-2)
                sy = sy if sy < patch.height else 2*patch.height-2-sy
                color = px[sx, sy]
                data.append(tuple(int(color[i]*tint[i]) for i in range(3)) + (255,))
        im.putdata(data)
        im.putalpha(mask)
        save(f'hex_{name}_{variant}', im, file, rect, transform='sample offset/mirror, palette tint, pointy hex mask', tint=list(tint))

# Separate scenery/ground layers; exclude sheet labels and credit blocks from gameplay.
for name, file, rect in [
    ('forest_scenery', 'Forest.png', (12, 16, 516, 212)),
    ('village_scenery', 'Boss Stage.png', (0, 0, 505, 148)),
    ('village_skyline', 'Konoha Background.png', (0, 0, 551, 180)),
    ('bridge_scenery', 'Bridge.png', (15, 18, 519, 258)),
    ('bamboo_layer', 'Forest of Death 1.png', (260, 468, 772, 981)),
]:
    save(name, crop(file, rect), file, rect, transform='reviewed scenery crop; no sheet labels')

for name, source, ground_name in [('forest', 'forest_scenery', 'plain'), ('village', 'village_scenery', 'road'), ('bridge', 'bridge_scenery', 'road')]:
    backdrop = Image.new('RGBA', (1100, 450))
    scenery = Image.open(OUT / (source+'.png')).convert('RGBA').resize((1100, 300), Image.Resampling.NEAREST)
    backdrop.paste(scenery, (0, 0))
    file, rect, tint = materials[ground_name]
    ground = crop(file, rect).resize((1100, 150), Image.Resampling.NEAREST)
    backdrop.paste(ground, (0, 300))
    save('battle_'+name, backdrop, source+'.png', (0, 0, 1100, 450), transform='recompose scenery and ground; nearest scaling', ground_source={'file':file,'rect':list(rect)})

(ROOT / 'data/environment_audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding='utf8')
print('PASS environment:', len(audit['sources']), 'sources;', len(audit['assets']), 'processed assets')
