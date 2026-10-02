"""Render the addon frame tree and its shipped artwork, not a game screenshot.

Fonts are approximated with installed Windows fonts. Native Blizzard textures
can be supplied under tests/native-textures/Interface/; unresolved native icons
remain placeholders. Missing addon art is an error. This boots the TOC directly
and does not rerun the full regression suite each time a preview is rendered.
"""
from functools import lru_cache
from pathlib import Path
import math
import os
import re
import tempfile
from PIL import Image, ImageChops, ImageDraw, ImageFont
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
STRATA = {name: i for i, name in enumerate(['BACKGROUND', 'LOW', 'MEDIUM', 'HIGH', 'DIALOG', 'FULLSCREEN', 'FULLSCREEN_DIALOG', 'TOOLTIP'])}
LAYERS = {'BACKGROUND': 0, 'BORDER': 1, 'ARTWORK': 2, 'OVERLAY': 3, 'HIGHLIGHT': 4}
CUSTOM_PREFIX = 'interface/addons/hardcorebuddy/'
native_placeholders, custom_assets = set(), set()


@lru_cache(maxsize=64)
def font(size, path=None):
    source = str(path or '').lower()
    filename = 'georgiab.ttf' if 'morpheus' in source else 'segoeui.ttf'
    local = ROOT / str(path or '').replace('\\', '/')
    filename = str(local) if local.suffix.lower() in ('.ttf', '.otf') and local.is_file() else str(Path('C:/Windows/Fonts') / filename)
    try:
        return ImageFont.truetype(filename, max(1, int(size)))
    except OSError:
        # CI has no Windows fonts; these remain approximate layout checks.
        return ImageFont.load_default(size=max(1, int(size)))


def plain(text):
    return re.sub(r'\|c[0-9a-fA-F]{8}|\|r', '', str(text or ''))


def wrapped(text, width, size, path=None, word_wrap=True):
    if word_wrap is False:
        return plain(text).split('\n')
    face, lines = font(size, path), []
    for paragraph in plain(text).split('\n'):
        line = ''
        for word in paragraph.split(' '):
            trial = line + ' ' + word if line else word
            if face.getlength(trial) > width and line:
                lines.append(line)
                line = word
            else:
                line = trial
        lines.append(line)
    return lines


def height(text, width, size, path=None, word_wrap=True):
    return len(wrapped(text, max(1, width), size, path, word_wrap)) * (size + 3)


def text_width(text, size, path=None):
    return max((font(size, path).getlength(line) for line in plain(text).split('\n')), default=0)


def rgba(color, default=(255, 255, 255, 255)):
    if color is None:
        return default
    return tuple(round(max(0, min(1, color[i] if color[i] is not None else 1)) * 255) for i in range(1, 5))


def rect(frame):
    return frame['GetRect'](frame)


def effective_alpha(frame):
    result = 1
    while frame is not None:
        result *= frame['alpha'] if frame['alpha'] is not None else 1
        frame = frame['parent']
    return max(0, min(1, result))


@lru_cache(maxsize=256)
def resolve_texture(asset):
    if not isinstance(asset, str):
        return None
    name = asset.replace('\\', '/')
    custom = name.lower().startswith(CUSTOM_PREFIX)
    roots = [ROOT] if custom else [ROOT / 'tests/native-textures', Path(tempfile.gettempdir()) / 'hardcorebuddy-tools/native-textures']
    for directory in roots:
        candidate = directory / (name[len(CUSTOM_PREFIX):] if custom else name)
        choices = [candidate] if candidate.suffix else [candidate.with_suffix(ext) for ext in ('.tga', '.png', '.blp')]
        for choice in choices:
            if choice.is_file():
                if custom:
                    custom_assets.add(str(choice.relative_to(ROOT)))
                return Image.open(choice).convert('RGBA')
    if custom:
        raise FileNotFoundError('Missing shipped artwork: ' + asset)
    return None


def texture_image(region, width, height_px):
    width, height_px = max(1, round(width)), max(1, round(height_px))
    asset = region['texture']
    if region['colorTexture'] is not None:
        source = Image.new('RGBA', (1, 1), rgba(region['colorTexture']))
    elif isinstance(asset, str) and asset.replace('\\', '/').lower().endswith('/white8x8'):
        source = Image.new('RGBA', (1, 1), 'white')
    else:
        source = resolve_texture(asset)
        if source is None:
            if not asset:
                return None
            native_placeholders.add(str(asset))
            source = Image.new('RGBA', (width, height_px), (44, 41, 33, 255))
            ImageDraw.Draw(source).rectangle((0, 0, width - 1, height_px - 1), outline=(113, 94, 56, 230))
    coordinates = region['texCoord']
    if coordinates is not None and len(coordinates) == 4:
        left, right, top, bottom = (coordinates[i] for i in range(1, 5))
        sw, sh = source.size
        source = source.crop((round(min(left, right) * sw), round(min(top, bottom) * sh), round(max(left, right) * sw), round(max(top, bottom) * sh)))
        if left > right:
            source = source.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if top > bottom:
            source = source.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    elif coordinates is not None and len(coordinates) == 8:
        sw, sh = source.size
        quad = tuple(coordinates[i] * (sw if i % 2 else sh) for i in (1, 2, 3, 4, 7, 8, 5, 6))
        source = source.transform((width, height_px), Image.Transform.QUAD, quad, Image.Resampling.BICUBIC)
    if region['horizTile'] or region['vertTile']:
        tw = source.width if region['horizTile'] else width
        th = source.height if region['vertTile'] else height_px
        tile = source.resize((max(1, tw), max(1, th)), Image.Resampling.LANCZOS)
        rendered = Image.new('RGBA', (width, height_px))
        for x in range(0, width, tile.width):
            for y in range(0, height_px, tile.height):
                rendered.paste(tile, (x, y))
    else:
        rendered = source.resize((width, height_px), Image.Resampling.LANCZOS)
    if region['rotation']:
        origin = region['rotationOrigin']
        center = (width * origin[1], height_px * origin[2]) if origin is not None else None
        rendered = rendered.rotate(math.degrees(region['rotation']), Image.Resampling.BICUBIC, center=center)
    gradient = region['gradient']
    if gradient is not None:
        horizontal = gradient['orientation'] == 'HORIZONTAL'
        extent = width if horizontal else height_px
        first, last = rgba(gradient['first']), rgba(gradient['last'])
        pixels = [tuple(round(a + (b - a) * index / max(1, extent - 1)) for a, b in zip(first, last))
                  for index in range(extent)]
        if not horizontal:
            pixels.reverse()  # Native vertical gradients run bottom to top.
        strip = Image.new('RGBA', (extent, 1) if horizontal else (1, extent))
        strip.putdata(pixels)
        rendered = ImageChops.multiply(rendered, strip.resize(rendered.size))
    if region['vertexColor'] is not None:
        rendered = ImageChops.multiply(rendered, Image.new('RGBA', rendered.size, rgba(region['vertexColor'])))
    return rendered


def intersect(a, b):
    return max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])


def tiled(source, size, tile_size):
    patch = Image.new('RGBA', size)
    tile = source.resize(tile_size, Image.Resampling.LANCZOS)
    for x in range(0, size[0], tile.width):
        for y in range(0, size[1], tile.height):
            patch.paste(tile, (x, y))
    return patch


def backdrop_image(frame, operation, width, height_px):
    width, height_px = max(1, round(width)), max(1, round(height_px))
    info, patch = frame['backdrop'], Image.new('RGBA', (width, height_px))
    source = resolve_texture(info['bgFile' if operation == 'background' else 'edgeFile'])
    color = rgba(frame['background' if operation == 'background' else 'border'])
    if operation == 'background':
        insets = info['insets']
        left, right, top, bottom = (round(insets[key] or 0) if insets else 0 for key in ('left', 'right', 'top', 'bottom'))
        size = max(1, width - left - right), max(1, height_px - top - bottom)
        if source:
            tile_size = max(1, round(info['tileSize'] or source.width))
            fill = tiled(source, size, (tile_size, tile_size)) if info['tile'] else source.resize(size, Image.Resampling.LANCZOS)
            fill = ImageChops.multiply(fill, Image.new('RGBA', size, color))
        else:
            fill = Image.new('RGBA', size, color)
        patch.paste(fill, (left, top))
        return patch
    edge = max(1, round(min(info['edgeSize'] or 1, width / 2, height_px / 2)))
    if source is None or source.width != source.height * 8:
        ImageDraw.Draw(patch).rectangle((0, 0, width - 1, height_px - 1), outline=color, width=edge)
        return patch
    # Blizzard_SharedXML/Backdrop.lua: L,R,T,B,TL,TR,BL,BR in an eight-tile
    # horizontal strip. Horizontal edges rotate 90 degrees clockwise.
    segments = []
    for index in range(8):
        u0, u1 = index / 8 + .0078125, (index + 1) / 8 - .0078125
        segment = source.crop((round(u0 * source.width), round(.0625 * source.height),
                               round(u1 * source.width), round(.9375 * source.height)))
        if index in (2, 3):
            segment = segment.transpose(Image.Transpose.ROTATE_270)
        segment = segment.resize((edge, edge), Image.Resampling.LANCZOS)
        segments.append(ImageChops.multiply(segment, Image.new('RGBA', segment.size, color)))
    positions = [(0, edge, edge, height_px - 2 * edge), (width - edge, edge, edge, height_px - 2 * edge),
                 (edge, 0, width - 2 * edge, edge), (edge, height_px - edge, width - 2 * edge, edge),
                 (0, 0, edge, edge), (width - edge, 0, edge, edge),
                 (0, height_px - edge, edge, edge), (width - edge, height_px - edge, edge, edge)]
    for segment, (x, y, w, h) in zip(segments, positions):
        if w > 0 and h > 0:
            patch.paste(tiled(segment, (w, h), (edge, edge)), (x, y))
    return patch


def clip_rect(frame, canvas_size, offset):
    clip = (0, 0, canvas_size[0], canvas_size[1])
    child = frame
    while child['parent'] is not None:
        parent = child['parent']
        if parent['kind'] == 'ScrollFrame' and parent['child'] is not None and parent['child']['creationOrder'] == child['creationOrder']:
            x, y, w, h = rect(parent)
            clip = intersect(clip, (round(x + offset[0]), round(y + offset[1]), round(x + w + offset[0]), round(y + h + offset[1])))
        child = parent
    return clip


def paint_operations(frames,window):
    operations = []
    for _, frame in frames.items():
        ancestor=frame
        while ancestor is not None and ancestor['creationOrder']!=window['creationOrder']:
            ancestor=ancestor['parent']
        if ancestor is None:
            continue
        if frame['kind'] == 'Tooltip' or not frame['IsVisible'](frame):
            continue
        kind, entries = frame['kind'], []
        if kind == 'Texture' and (frame['texture'] or frame['colorTexture']):
            entries.append(('texture', LAYERS.get(frame['drawLayer'], 2), frame['drawSubLevel'] or 0))
        elif kind == 'FontString':
            entries.append(('text', LAYERS.get(frame['drawLayer'], 3), frame['drawSubLevel'] or 0))
        else:
            if frame['backdrop'] and frame['background']:
                entries.append(('background', -1, 0))
            if frame['backdrop'] and frame['border']:
                entries.append(('border', 1, 0))
            if kind == 'EditBox':
                entries.append(('text', 3, 0))
        for operation, layer, sublevel in entries:
            order = (STRATA[frame['GetFrameStrata'](frame)], frame['GetFrameLevel'](frame), layer, sublevel, frame['creationOrder'])
            operations.append((order, operation, frame))
    return sorted(operations, key=lambda entry: entry[0])


def composite(frame_tree, window):
    left, top, width, height_px = rect(window)
    size, offset = (round(width) + 24, round(height_px) + 52), (12 - left, 12 - top)
    canvas = Image.new('RGBA', size, (19, 19, 22, 255))
    for _, operation, frame in paint_operations(frame_tree,window):
        x, y, w, h = rect(frame)
        x, y = x + offset[0], y + offset[1]
        if w <= 0 or h <= 0 or x + w <= 0 or y + h <= 0 or x >= size[0] or y >= size[1]:
            continue
        layer = Image.new('RGBA', size)
        draw = ImageDraw.Draw(layer)
        box = (round(x), round(y), round(x + w) - 1, round(y + h) - 1)
        if operation == 'texture':
            patch = texture_image(frame, w, h)
            if patch is not None:
                layer.paste(patch, (round(x), round(y)))
        elif operation in ('background', 'border'):
            layer.paste(backdrop_image(frame, operation, w, h), (round(x), round(y)))
        elif operation == 'text' and frame['text']:
            insets = frame['textInsets']
            if insets:
                x, y, w, h = x + insets[1], y + insets[3], w - insets[1] - insets[2], h - insets[3] - insets[4]
            fs, path = frame['fontSize'] or 12, frame['fontPath']
            face = font(fs, path)
            lines = wrapped(frame['text'], max(1, w), fs, path, frame['wordWrap'])
            advance = fs + 3
            if frame['justifyV'] == 'MIDDLE':
                y += (h - advance * len(lines)) / 2
            elif frame['justifyV'] == 'BOTTOM':
                y += h - advance * len(lines)
            for line in lines:
                tx = x
                if frame['justifyH'] == 'CENTER':
                    tx += (w - face.getlength(line)) / 2
                elif frame['justifyH'] == 'RIGHT':
                    tx += w - face.getlength(line)
                if frame['shadowColor'] is not None:
                    shadow = frame['shadowOffset']
                    draw.text((tx + (shadow[1] if shadow else 0), y - (shadow[2] if shadow else 0)), line, font=face, fill=rgba(frame['shadowColor']))
                draw.text((tx, y), line, font=face, fill=rgba(frame['color'], (232, 232, 232, 255)))
                y += advance
        alpha = effective_alpha(frame)
        if alpha < 1:
            layer.putalpha(layer.getchannel('A').point(lambda value: round(value * alpha)))
        clip = clip_rect(frame, size, offset)
        if operation == 'text':
            clip = intersect(clip, box[:2] + (box[2] + 1, box[3] + 1))
        cropped = Image.new('RGBA', size)
        if clip[2] > clip[0] and clip[3] > clip[1]:
            cropped.paste(layer.crop(clip), clip[:2])
        if frame['blendMode'] == 'ADD' and operation == 'texture':
            rgb = Image.composite(cropped.convert('RGB'), Image.new('RGB', size), cropped.getchannel('A'))
            canvas = ImageChops.add(canvas.convert('RGB'), rgb).convert('RGBA')
        else:
            canvas = Image.alpha_composite(canvas, cropped)
    ImageDraw.Draw(canvas).text((12, size[1] - 25), 'LAYOUT SIMULATION | custom art rendered | game fonts approximated', font=font(11), fill=(197, 166, 112))
    return canvas


def boot():
    lua = LuaRuntime(unpack_returned_tuples=True)
    addon = lua.table()
    lua.globals().TestAddon = addon
    lua.globals().TEST_MEASURE, lua.globals().TEST_TEXT_WIDTH = height, text_width
    lua.execute((ROOT / 'tests/wow_mock.lua').read_text(encoding='utf-8'), 'HardcoreBuddy', addon)
    lua.execute((ROOT / 'tests/deaths_mock.lua').read_text(encoding='utf-8'))
    for line in (ROOT / 'HardcoreBuddy.toc').read_text(encoding='utf-8').splitlines():
        if line and not line.startswith('#') and line.lower().endswith('.lua'):
            lua.execute((ROOT / line.replace('\\', '/')).read_text(encoding='utf-8'), 'HardcoreBuddy', addon)
    lua.execute('''
        MOCK.bags={[0]={{itemID=3771,stackCount=20},{itemID=1708,stackCount=12},
            {itemID=4592,stackCount=5},{itemID=6451,stackCount=8},{itemID=6453,stackCount=3},
            {itemID=4392,stackCount=2},{itemID=1710,stackCount=2}}}
        NUM_BAG_SLOTS=4
        C_Container={GetContainerNumSlots=function(bag) return bag==0 and 16 or 0 end,
            GetContainerItemInfo=function(bag,slot) return MOCK.bags[bag] and MOCK.bags[bag][slot] end}
        local recipeIcons={[16112]="inv_misc_book_03",[16113]="inv_misc_book_03",[6454]="inv_misc_book_03",
            [16084]="inv_misc_book_08",[16072]="inv_misc_book_08",[16046]="inv_scroll_03",[19442]="inv_scroll_03"}
        C_Item={GetItemIconByID=function(id)
            return recipeIcons[id] and ("Interface"..string.char(92).."Icons"..string.char(92)..recipeIcons[id])
        end}
        local P=TestAddon.Professions
        P.Read=function()
            local result={available=true,skills={bandage=180,dummy=185,cooking=125},baseSkills={bandage=180,dummy=185,cooking=125},maxSkills={bandage=225,dummy=225,cooking=150},known={}}
            for family,recipes in pairs(P.recipes) do
                local skill=family=="dummy" and 185 or 180
                for _,recipe in ipairs(recipes) do result.known[recipe.spellId]=recipe.craftSkill<=skill end
            end
            return result
        end
        MOCK.FireAll("ADDON_LOADED","HardcoreBuddy")
        TestAddon:ToggleWindow()
    ''')
    return lua, addon


def render(lua, addon, name, width=1040, view='supplies', filter=None, query='', action=None, class_name='Hunter', level=32, preview=False, height_px=660, faction='Alliance', screen=(1920,1080)):
    lua.globals().MOCK['class'], lua.globals().MOCK['level'] = class_name.upper(), level
    lua.globals().MOCK['faction'] = faction
    lua.globals().UIParent['width'], lua.globals().UIParent['height'] = screen
    addon['SetProfile'](addon, 'characterClass', class_name)
    addon['SetProfile'](addon, 'mode', 'preview' if preview else 'live')
    addon['SetLevel'](addon, level)
    window = addon['window']
    assert (width, height_px) == (1040, 660), 'The addon now uses fixed wide geometry'
    addon['RestoreWindow'](addon)
    addon['Navigate'](addon, view)
    if filter is not None:
        addon['state']['filter'] = filter
    addon['state']['query'] = query
    addon['Refresh'](addon, True)
    if action:
        addon['Activate'](addon, lua.table_from(action))
    canvas = composite(lua.globals().MOCK['frames'], window)
    scale = window['GetScale'](window)
    if scale < 1:
        canvas = canvas.resize((round(canvas.width * scale), round(canvas.height * scale)), Image.Resampling.LANCZOS)
    target = ROOT / 'docs/layout-previews'
    target.mkdir(exist_ok=True)
    canvas.convert('RGB').save(target / (name + '.png'))
    print('Rendered', name)


if __name__ == '__main__':
    lua, addon = boot()
    render(lua, addon, 'redesign-all', filter='All')
    for item_id, name in [(8951,'redesign-greater-defense'),(9030,'redesign-restorative')]:
        record = next(item for _, item in addon['Data']['Items']['items'].items() if item['itemId']==item_id)
        render(lua, addon, name, filter='Buffs' if item_id==8951 else 'Emergency', action=dict(kind='item',item=record))
    render(lua, addon, 'redesign-supplies', filter='Food & drink')
    render(lua, addon, 'redesign-emergency', filter='Emergency')
    render(lua, addon, 'redesign-preview', preview=True)
    render(lua, addon, 'redesign-small-screen', preview=True, screen=(800,600))
    render(lua, addon, 'redesign-ranks', filter='Emergency', action=dict(kind='supplyFamily', family='bandage'))
    render(lua, addon, 'redesign-engineering', filter='Emergency', action=dict(kind='supplyFamily', family='dummy'))
    render(lua, addon, 'redesign-antivenom', filter='Emergency', action=dict(kind='supplyFamily', family='antivenom'))
    item = next(item for _, item in addon['Data']['Items']['items'].items() if item['itemId'] == 8949)
    render(lua, addon, 'redesign-item-detail', filter='Buffs', action=dict(kind='item', item=item))
    render(lua, addon, 'redesign-pet-guide', view='petguide', filter='Pets', query='owl')
    render(lua, addon, 'redesign-companion', view='training', class_name='Warlock')
    render(lua, addon, 'redesign-horde', faction='Horde', filter='Food & drink')
    render(lua, addon, 'redesign-unknown-faction', faction=None, filter='Food & drink')
    render(lua, addon, 'redesign-cooking', view='training', action=dict(kind='profession',family='cooking'))
    snapshot=addon['Professions']['Read']()
    for key in ('skills','baseSkills','maxSkills'): snapshot[key]['bandage']=225
    for _,recipe in addon['Professions']['recipes']['bandage'].items():
        snapshot['known'][recipe['spellId']]=recipe['craftSkill']<=225
    original_reader=addon['Professions']['Read']
    addon['Professions']['Read']=lua.eval('function(value) return function() return value end end')(snapshot)
    lua.globals().MOCK['Fire']('SKILL_LINES_CHANGED')
    render(lua, addon, 'redesign-triage', view='training', action=dict(kind='profession',family='bandage'))
    addon['Professions']['Read']=original_reader
    print('Custom artwork rendered:', ', '.join(sorted(custom_assets)) or '(none)')
    print('Native texture placeholders:', len(native_placeholders))
    if native_placeholders:
        print('\n'.join(sorted(native_placeholders)))
