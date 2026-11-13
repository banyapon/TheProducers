"""Restyle quest idle and walk sheets to the 3x3 style lock.

Pose and registration stay on the alice and male sheets. Identity comes
from each 2x2 portrait: a distinct hair silhouette, one outer-cloth hue,
and one accessory. Women wear either an evening gown or a short skirt.
A few men wear shorts. Play sheets and portraits are not written.

Style rule, from .agents/skills/aseprite-3x3-character/style-lora.md:
no two ids share both hair silhouette and outer-cloth hue.
"""

from pathlib import Path
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_quest_sheets as base

CELL = base.CELL
INK = base.INK
PUPIL = base.PUPIL
EYE = base.EYE
ROOT = base.ROOT
QUESTS = base.QUESTS
SKIN_W = base.ALICE_SKIN_OUT
SKIN_M = (base.SKIN_SH, base.SKIN_MID, base.SKIN_HI)
GOLD = ((0x8A, 0x6A, 0x28), (0xE6, 0xC8, 0x5A), (0xFF, 0xE8, 0xA0))
SILVER = (0xC8, 0xCC, 0xD4)
SCREEN_DARK = (0x14, 0x22, 0x28)
PINK = (0xF0, 0x98, 0xA8)
CUP = ((0x2A, 0x28, 0x38), (0x5A, 0x58, 0x70))

# hair, garment, accessory. Outer hue is the jacket ramp, already unique per pair.
LOOK = {
    "mali": {"hair": "bob", "garment": "skirt", "extra": "flower", "bottom": "c04868"},
    "pim": {"hair": "shoulder", "garment": "skirt", "extra": "pearl", "bottom": "a04058"},
    "dao": {"hair": "curls", "garment": "gown", "slit": True, "extra": "earring"},
    "narin": {"hair": "long", "garment": "gown", "slit": True, "extra": "earring"},
    "vivian": {"hair": "sleek", "garment": "gown", "extra": "pin"},
    "rex": {"hair": "buzz", "garment": "shorts", "extra": "chain", "bottom": "3a5878"},
    "kai": {"hair": "pony", "garment": "skirt", "crop": True, "extra": "hoop", "bottom": "241c28"},
    "selene": {"hair": "swept", "garment": "gown", "slit": True, "extra": "drops"},
    "beep": {"hair": "monitor", "garment": "pants", "extra": "antenna"},
    "orbit": {"hair": "visor", "garment": "pants", "extra": "moustache"},
    "crumb": {"hair": "cap", "garment": "shorts", "extra": "bolt", "bottom": "242028"},
    "mint": {"hair": "pixie", "garment": "skirt", "extra": "phones", "bottom": "2a3038"},
    "aki": {"hair": "quiff", "garment": "shorts", "extra": "band", "bottom": "243868"},
    "phakin": {"hair": "sidepart", "garment": "shorts", "extra": "strap", "bottom": "6a5438"},
    "rose": {"hair": "spikes", "garment": "skirt", "extra": "stud", "bottom": "1a1820"},
    "ingfah": {"hair": "braid", "garment": "gown", "extra": "pearl"},
    "leo": {"hair": "slick", "garment": "pants", "extra": "bow"},
    "vega": {"hair": "updo", "garment": "gown", "extra": "star"},
    "boon": {"hair": "wavy", "garment": "pants", "extra": "none"},
    "aurelian": {"hair": "swept-silver", "garment": "pants", "extra": "tie"},
}


def skin_ramp(spec):
    return SKIN_W if spec["body"] == "alice" else SKIN_M


def empty():
    return [[None] * CELL for _ in range(CELL)]


def read_grid(image):
    grid = empty()
    pixels = image.load()
    for y in range(CELL):
        for x in range(CELL):
            pixel = pixels[x, y]
            if pixel[3]:
                grid[y][x] = pixel[:3]
    return grid


def write_grid(grid):
    image = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(CELL):
        for x in range(CELL):
            if grid[y][x] is not None:
                pixels[x, y] = grid[y][x] + (255,)
    return image


def sole_of(grid):
    for y in range(CELL - 1, -1, -1):
        if any(grid[y][x] is not None for x in range(CELL)):
            return y
    return 136


def tone_at(x, left, right, ramp):
    if right <= left:
        return ramp[1]
    span = (x - left) / (right - left)
    if span > 0.72:
        return ramp[0]
    if span < 0.28:
        return ramp[2]
    return ramp[1]


def find_waist(grid, pants):
    for y in range(64, 118):
        xs = [x for x in range(CELL) if grid[y][x] in pants]
        if len(xs) >= 6 and max(xs) - min(xs) >= 8:
            return y, min(xs), max(xs)
    return None


def shoe_top(grid, shoes):
    """Lowest band of shoe pixels. Dark cloth higher up can share a shoe tone."""
    for y in range(112, CELL):
        if any(grid[y][x] in shoes for x in range(CELL)):
            return y
    return 127


def paint_span(grid, y, left, right, ramp, blocked, limit):
    if y < 20 or y > limit or y >= CELL:
        return
    for x in range(max(55, left), min(111, right + 1)):
        if grid[y][x] in blocked:
            continue
        grid[y][x] = INK if x in (left, right) else tone_at(x, left, right, ramp)


def recolor_pants(grid, pants, ramp, skin=None):
    for y in range(CELL):
        xs = [x for x in range(CELL) if grid[y][x] in pants]
        if not xs:
            continue
        left, right = min(xs), max(xs)
        for x in xs:
            grid[y][x] = skin and tone_at(x, left, right, skin) or tone_at(x, left, right, ramp)


def anchor(grid):
    top = None
    xs = []
    for y in range(20, 96):
        row = [x for x in range(CELL) if grid[y][x] is not None]
        if not row:
            continue
        if top is None:
            top = y
        if 36 <= y <= 78:
            xs.extend(row)
    center = sorted(xs)[len(xs) // 2] if xs else 80
    return top or 25, center


def cloth_pixel(color, skin, shoes, hair):
    return color not in skin and color not in shoes and color not in hair and color not in (EYE, PUPIL, None)


def row_colors(grid, y, colors):
    return [x for x in range(CELL) if grid[y][x] in colors]


def leg_runs(xs):
    if not xs:
        return []
    runs = []
    start = prev = xs[0]
    for x in xs[1:]:
        if x > prev + 1:
            runs.append((start, prev))
            start = x
        prev = x
    runs.append((start, prev))
    return runs


def rim_tone(x, left, right, ramp):
    if x >= right - 1:
        return ramp[0]
    if x <= left + 1:
        return ramp[2]
    return ramp[1]


def paint_cloth(grid, y, left, right, ramp, skip):
    left = max(55, left)
    right = min(110, right)
    if right - left < 2 or not 0 <= y < CELL:
        return
    for x in range(left, right + 1):
        if grid[y][x] in skip:
            continue
        grid[y][x] = INK if x in (left, right) else rim_tone(x, left, right, ramp)


def cloth_columns(grid, y, skip, center):
    xs = []
    for x in range(max(52, center - 24), min(112, center + 25)):
        color = grid[y][x]
        if color is None or color == INK or color in skip:
            continue
        xs.append(x)
    return xs


def apply_bottom(grid, spec, look):
    """Replace the source trousers using the painted leg pixels.

    Skirts and gowns fill the gap between the legs. Shorts keep that gap.
    Bare legs below a hem stay on the original stride.
    """
    kind = look["garment"]
    if kind == "pants":
        return
    skin_colors = skin_ramp(spec)
    skin = set(skin_colors)
    shoes = set(spec["shoes"])
    hair = set(spec["hair"])
    pants = set(spec["pants"])
    shirt = set(spec["shirt"])
    jacket = set(spec["jacket"])
    limit = sole_of(grid)
    feet = min(shoe_top(grid, shoes), limit)
    top, anchor_center = anchor(grid)
    found = find_waist(grid, pants)
    # Male sheets paint the trouser pixels with the jacket ramp, so the pants
    # colors only survive at the ankle. Use the hip line in that case.
    pants_on_legs = found is not None and found[0] <= top + 78
    if pants_on_legs:
        waist, hip_l, hip_r = found
        center = (hip_l + hip_r) // 2
    else:
        waist = top + 66
        center = anchor_center
        hip_l, hip_r = center - 8, center + 8
    skip = shoes | hair | {EYE, PUPIL, SCREEN_DARK}

    if kind == "gown":
        ramp = spec["jacket"]
        for y in range(max(48, waist - 26), waist):
            for x in row_colors(grid, y, shirt):
                grid[y][x] = tone_at(x, hip_l, hip_r, ramp)
        for y in range(waist, feet):
            xs = row_colors(grid, y, pants | {INK})
            body = [x for x in xs if hip_l - 8 <= x <= hip_r + 8] or [hip_l, hip_r]
            grow = min(3, (y - waist) // 8)
            left, right = min(body) - grow, max(body) + grow
            for x in range(max(55, left), min(111, right + 1)):
                if grid[y][x] in skip or grid[y][x] in skin:
                    continue
                if grid[y][x] not in pants and grid[y][x] != INK and grid[y][x] not in jacket and grid[y][x] is not None:
                    continue
                grid[y][x] = INK if x in (left, right) else rim_tone(x, left, right, ramp)
            # Close empty pixels inside the gown so the stride gap does not split the skirt.
            for x in range(max(55, left + 1), min(110, right)):
                if grid[y][x] is None:
                    grid[y][x] = rim_tone(x, left, right, ramp)
        if look.get("slit"):
            slit = center + 2
            for y in range(waist + 12, feet):
                for x in range(slit, slit + 3):
                    if grid[y][x] in shoes or grid[y][x] in hair:
                        continue
                    grid[y][x] = tone_at(x, slit, slit + 2, skin_colors)
                if 0 <= slit + 3 < CELL and grid[y][slit + 3] is not None:
                    grid[y][slit + 3] = INK
        return

    ramp = base.ramp(base.hx(look["bottom"]))
    hem = min(waist + (9 if kind == "skirt" else 8), feet - 6)
    if not pants_on_legs:
        bare = skin | shoes | hair | {EYE, PUPIL, SCREEN_DARK}
        shoe_at = [limit] * CELL
        for x in range(CELL):
            top_shoe = None
            for y in range(limit, waist + 16, -1):
                color = grid[y][x]
                if color in shoes:
                    top_shoe = y
                elif color not in (None, INK) and top_shoe is not None:
                    break
            if top_shoe is not None:
                shoe_at[x] = top_shoe
        for y in range(waist, hem):
            for run_l, run_r in leg_runs(cloth_columns(grid, y, bare, center)):
                for x in range(run_l, run_r + 1):
                    grid[y][x] = INK if y == hem - 1 else rim_tone(x, run_l, run_r, ramp)
        foot = max(hem + 4, limit - 16)
        for y in range(hem, foot):
            columns = [x for x in cloth_columns(grid, y, bare, center) if y < shoe_at[x]]
            for run_l, run_r in leg_runs(columns):
                for x in range(run_l, run_r + 1):
                    grid[y][x] = rim_tone(x, run_l, run_r, skin_colors)
        # A raised stride can leave a jacket-colored stripe beside the new skin.
        # Stop above the shoe so the original sole stays intact.
        cloth_left = jacket | shirt
        for _ in range(4):
            pending = []
            for y in range(hem, foot):
                for x in range(52, 112):
                    if grid[y][x] not in cloth_left:
                        continue
                    if any(
                        0 <= x + dx < CELL and 0 <= y + dy < CELL and grid[y + dy][x + dx] in skin
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                    ):
                        pending.append((x, y))
            for x, y in pending:
                grid[y][x] = skin_colors[1]
        return
    if look.get("crop"):
        band = waist - 12
        for y in range(band, waist - 2):
            xs = [x for x in range(hip_l, hip_r + 1) if grid[y][x] in jacket or grid[y][x] in shirt]
            for x in xs:
                grid[y][x] = skin_colors[1]
            if xs and y == band:
                for x in range(min(xs), max(xs) + 1):
                    if grid[y][x] == skin_colors[1]:
                        grid[y][x] = INK
    for y in range(waist, hem):
        xs = row_colors(grid, y, pants)
        if len(xs) < 3:
            continue
        left, right = min(xs), max(xs)
        flare = 0 if kind == "shorts" else min(3, (y - waist) // 3)
        left, right = left - flare, right + flare
        if kind == "shorts":
            for run_l, run_r in leg_runs(xs):
                for x in range(run_l, run_r + 1):
                    if grid[y][x] in skip:
                        continue
                    grid[y][x] = INK if y == hem - 1 else tone_at(x, run_l, run_r, ramp)
            continue
        paint_cloth(grid, y, left, right, ramp, skip | skin)
        for x in range(max(55, left + 1), min(110, right)):
            if grid[y][x] is None:
                grid[y][x] = tone_at(x, left, right, ramp)
        grid[y][max(55, left)] = INK
        grid[y][min(110, right)] = INK
    for y in range(hem, feet):
        xs = row_colors(grid, y, pants)
        for run_l, run_r in leg_runs(xs):
            for x in range(run_l, run_r + 1):
                if grid[y][x] in shoes:
                    continue
                grid[y][x] = tone_at(x, run_l, run_r, skin_colors)


def hair_box(grid, hair):
    pts = [(x, y) for y in range(CELL) for x in range(CELL) if grid[y][x] in hair]
    if not pts:
        return None
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys), pts


def put(grid, x, y, color, limit):
    if 55 <= x <= 110 and 20 <= y <= limit and y < CELL:
        grid[y][x] = color


def hang_hair(grid, ramp, miny, maxy, limit, side, length, braid=False):
    """Hang a lock just outside the body so long hair reads at this scale."""
    for i in range(length):
        y = maxy - 2 + i
        if y >= limit - 4 or y < miny:
            continue
        xs = [x for x in range(CELL) if grid[y][x] is not None]
        if not xs:
            continue
        edge = xs[0] - 1 if side < 0 else xs[-1] + 1
        if braid and i % 3 == 2:
            put(grid, edge, y, INK, limit)
            continue
        put(grid, edge, y, INK, limit)
        inner = edge - side
        if 0 <= inner < CELL and grid[y][inner] is not None:
            grid[y][inner] = ramp[1]
        else:
            put(grid, edge + side, y, ramp[1], limit)


def apply_hair(grid, spec, look):
    hair = set(spec["hair"])
    ramp = spec["hair"]
    box = hair_box(grid, hair)
    if box is None:
        return
    minx, miny, maxx, maxy, pts = box
    limit = sole_of(grid)
    style = look["hair"]
    center = (minx + maxx) // 2
    if style == "bob":
        for x, y in pts:
            if y > miny + 16 and x < center:
                grid[y][x] = None
    elif style == "sleek":
        for x, y in pts:
            if y > miny + 13 and x < center + 1:
                grid[y][x] = None
    elif style == "pixie":
        for x, y in pts:
            if y > miny + 11 and (x < center or x > maxx - 2):
                grid[y][x] = None
        for x in range(minx, maxx + 1, 3):
            if grid[miny][x] in hair:
                grid[miny][x] = None
    elif style == "spikes":
        for index, x in enumerate(range(minx + 1, maxx, 3)):
            put(grid, x, miny - 1, ramp[2] if index % 2 == 0 else INK, limit)
            if grid[miny][x] in hair and index % 2:
                grid[miny][x] = None
    elif style == "buzz":
        for x, y in pts:
            if y > miny + 7 and (x < minx + 4 or x > maxx - 3):
                grid[y][x] = None
    elif style == "quiff":
        for x in range(center + 1, maxx):
            put(grid, x, miny - 1, ramp[2] if x < maxx - 2 else INK, limit)
        for x, y in pts:
            if y > miny + 9 and x < minx + 3:
                grid[y][x] = None
    elif style == "long":
        hang_hair(grid, ramp, miny, maxy, limit, side=-1, length=24)
    elif style == "swept":
        hang_hair(grid, ramp, miny, maxy, limit, side=1, length=20)
    elif style == "pony":
        for dy, color in ((-1, ramp[2]), (0, ramp[1]), (1, ramp[0]), (2, ramp[1]), (3, INK)):
            put(grid, minx - 1, miny + 1 + dy, color, limit)
        hang_hair(grid, ramp, miny, maxy, limit, side=-1, length=12)
    elif style == "braid":
        hang_hair(grid, ramp, miny, maxy, limit, side=-1, length=22, braid=True)
    elif style == "curls":
        bumps = [(x, y) for x, y in pts if x > 0 and grid[y][x - 1] is None and y % 4 == 0]
        for x, y in bumps[:5]:
            put(grid, x - 1, y, INK, limit)
            put(grid, x - 1, y - 1, ramp[1], limit)
    elif style == "updo":
        for dy in range(-2, 5):
            for dx in range(-2, 2):
                color = INK if dx == -2 or dy in (-2, 4) else (SILVER if dx == 1 and dy in (0, 1) else ramp[1])
                put(grid, minx + dx, miny + 2 + dy, color, limit)
    elif style == "cap":
        for x, y in pts:
            if y <= miny + 8:
                local = 2 if x < center else 0 if x > center + 2 else 1
                grid[y][x] = ((0xF4, 0xF1, 0xEA), (0xFF, 0xFF, 0xFF), (0xC8, 0xC4, 0xBA))[local] if y > miny else INK
    elif style == "monitor":
        dark = (0x3A, 0x40, 0x48)
        mid = (0x8A, 0x90, 0x98)
        cyan = (0x68, 0xB1, 0xB3)
        for x, y in list(pts):
            grid[y][x] = mid if x < center else dark
        face_top = miny + 5
        face_bot = min(miny + 18, maxy + 4)
        for y in range(face_top, face_bot):
            for x in range(minx + 2, maxx):
                if grid[y][x] is None:
                    continue
                grid[y][x] = dark if x <= minx + 3 or x >= maxx - 2 or y == face_top else SCREEN_DARK
        eye_y = face_top + 4
        for dx in range(2):
            put(grid, center - 4 + dx, eye_y, cyan, limit)
            put(grid, center + 2 + dx, eye_y, cyan, limit)
        put(grid, center, eye_y + 4, PINK, limit)
        put(grid, center + 2, miny - 1, INK, limit)
        put(grid, center + 2, miny - 2, (0xE6, 0xC8, 0x5A), limit)
    elif style == "visor":
        for x, y in pts:
            if y <= miny + 2 or x <= minx + 1 or x >= maxx - 1:
                grid[y][x] = (0xF4, 0xF1, 0xEA) if y == miny + 1 else spec["jacket"][1]
    elif style == "slick":
        for x in range(minx, maxx + 1):
            if grid[miny][x] in hair and (x < minx + 2 or x > maxx - 2):
                grid[miny][x] = None
    # sidepart, shoulder, wavy, swept-silver keep the source silhouette.
    close_holes(grid, ramp)


def close_holes(grid, ramp):
    """Fill a fully enclosed hole left in the head after a hair trim."""
    hair = set(ramp)
    for y in range(20, 70):
        for x in range(55, 111):
            if grid[y][x] is not None:
                continue
            neighbors = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < CELL and 0 <= yy < CELL and grid[yy][xx] is not None:
                    neighbors.append(grid[yy][xx])
            if len(neighbors) < 4 or not any(color in hair for color in neighbors):
                continue
            grid[y][x] = ramp[1]


def interior(grid, x, y):
    if not (0 <= x < CELL and 0 <= y < CELL) or grid[y][x] is None:
        return False
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        xx, yy = x + dx, y + dy
        if not (0 <= xx < CELL and 0 <= yy < CELL) or grid[yy][xx] is None:
            return False
    return True


def apply_extra(grid, spec, look):
    hair = set(spec["hair"])
    box = hair_box(grid, hair)
    if box is None:
        return
    minx, miny, maxx, maxy, _pts = box
    limit = sole_of(grid)
    center = (minx + maxx) // 2
    kind = look["extra"]
    skin = set(skin_ramp(spec))
    if kind == "flower":
        if grid[miny + 6][minx + 3] in hair:
            grid[miny + 6][minx + 3] = EYE
        if grid[miny + 6][minx + 4] in hair:
            grid[miny + 6][minx + 4] = GOLD[1]
    elif kind in ("earring", "pearl", "hoop", "stud", "drops"):
        ear = None
        for y in range(miny + 8, miny + 18):
            for x in range(minx, center):
                if grid[y][x] in skin and interior(grid, x, y):
                    ear = (x, y)
                    break
            if ear:
                break
        if ear:
            x, y = ear
            grid[y][x] = EYE if kind == "pearl" else GOLD[1]
            if kind == "drops" and y + 2 < CELL and grid[y + 1][x] is not None:
                grid[y + 1][x] = SILVER
                grid[y + 2][x] = GOLD[1]
            if kind == "hoop" and grid[y + 1][x] is not None:
                grid[y + 1][x] = GOLD[0]
    elif kind == "pin":
        put(grid, center + 3, maxy + 6, GOLD[1], limit)
        put(grid, center + 4, maxy + 6, GOLD[2], limit)
    elif kind == "star":
        put(grid, center + 2, maxy + 8, GOLD[1], limit)
        put(grid, center + 3, maxy + 7, GOLD[2], limit)
        put(grid, center + 3, maxy + 9, GOLD[0], limit)
        for x, y in ((maxx - 2, miny + 3), (maxx - 2, miny + 4), (maxx - 1, miny + 4)):
            if grid[y][x] in hair:
                grid[y][x] = SILVER
    elif kind == "chain":
        for x in range(center - 1, center + 4):
            if maxy + 7 < CELL and grid[maxy + 7][x] is not None:
                grid[maxy + 7][x] = SILVER
    elif kind == "phones":
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0)):
            put(grid, minx + 2 + dx, maxy + 1 + dy, CUP[0] if dx < 1 else CUP[1], limit)
            put(grid, maxx - 3 + dx, maxy + 1 + dy, CUP[0], limit)
    elif kind == "band":
        red = spec["shirt"][1]
        white = spec["jacket"][2]
        for x in range(minx + 1, maxx):
            if grid[miny + 4][x] in hair:
                grid[miny + 4][x] = white if abs(x - center) < 2 else red
    elif kind == "bolt":
        for dx, dy in ((0, 0), (0, 1), (-1, 2), (-1, 3)):
            y = maxy + 8 + dy
            x = center + 1 + dx
            if 0 <= y < CELL and grid[y][x] is not None:
                grid[y][x] = GOLD[1]
    elif kind == "strap":
        for i in range(7):
            x, y = center - 3 + i, maxy + 2 + i
            if 0 <= y < CELL and 0 <= x < CELL and grid[y][x] is not None:
                grid[y][x] = spec["hair"][0]
    elif kind == "bow":
        y = maxy + 2
        for dx, color in ((-2, INK), (-1, INK), (0, EYE), (1, INK), (2, INK)):
            if 0 <= y < CELL and grid[y][center + dx] is not None:
                grid[y][center + dx] = color
    elif kind == "tie":
        for dy, color in ((2, GOLD[0]), (3, GOLD[1]), (4, GOLD[0])):
            y = maxy + dy
            if y < CELL and grid[y][center] is not None:
                grid[y][center] = color
    elif kind == "moustache":
        eyes = [(x, y) for y in range(CELL) for x in range(CELL) if grid[y][x] == spec["eyes"]]
        if eyes:
            ey = max(y for _, y in eyes)
            ex = sum(x for x, _ in eyes) // len(eyes)
            for dx in range(-2, 3):
                if grid[ey + 4][ex + dx] in skin:
                    grid[ey + 4][ex + dx] = spec["hair"][0]
    elif kind == "antenna":
        pass


def repair_edges(grid):
    for y in range(CELL):
        for x in range(CELL):
            color = grid[y][x]
            if color is None or color in (EYE, PUPIL, SCREEN_DARK, PINK):
                continue
            exposed = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < CELL and 0 <= yy < CELL) or grid[yy][xx] is None:
                    exposed = True
                    break
            if exposed and color != INK:
                # Keep a one-pixel rim of the color inside a thicker form.
                rim = 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < CELL and 0 <= yy < CELL and grid[yy][xx] not in (None, INK):
                        rim += 1
                if rim == 0:
                    grid[y][x] = INK


def dress_frame(frame, name, spec):
    look = LOOK[name]
    grid = read_grid(frame)
    apply_bottom(grid, spec, look)
    apply_hair(grid, spec, look)
    apply_extra(grid, spec, look)
    repair_edges(grid)
    return write_grid(grid)


def measure(sheet):
    pixels = sheet.load()
    colors = set()
    partial = 0
    notes = []
    for index in range(9):
        ox, oy = (index % 3) * CELL, (index // 3) * CELL
        minx, miny, maxx, maxy = CELL, CELL, -1, -1
        for y in range(CELL):
            for x in range(CELL):
                pixel = pixels[ox + x, oy + y]
                if pixel[3] == 0:
                    continue
                if pixel[3] != 255:
                    partial += 1
                colors.add(pixel[:3])
                minx, miny = min(minx, x), min(miny, y)
                maxx, maxy = max(maxx, x), max(maxy, y)
        if index == 0:
            notes.append(f"f0 {maxx - minx + 1}x{maxy - miny + 1} sole {maxy} x {minx}-{maxx} top {miny}")
            if maxy != 136:
                notes.append("SOLE")
            if minx < 55 or maxx > 110 or miny < 20:
                notes.append("BOUNDS")
        elif not 134 <= maxy <= 137:
            notes.append(f"f{index} sole {maxy}")
    if partial:
        notes.append(f"partial {partial}")
    if len(colors) > 26:
        notes.append("COLORS")
    return notes, len(colors)


def assert_unique():
    pairs = []
    for name, look in LOOK.items():
        outer = base.CAST[name]["jacket"][1]
        pairs.append((look["hair"], outer, name))
    seen = {}
    for hair, outer, name in pairs:
        key = (hair, outer)
        if key in seen:
            raise SystemExit(f"style collision {name} and {seen[key]} {key}")
        seen[key] = name


def build():
    assert_unique()
    male_frames = {name: base.load_frames(name) for name in ("idle", "walk")}
    alice_frames = {}
    for name in ("idle", "walk"):
        image = Image.open(base.ALICE / f"{name}.png").convert("RGBA")
        alice_frames[name] = [
            image.crop(((index % 3) * CELL, (index // 3) * CELL, (index % 3) * CELL + CELL, (index // 3) * CELL + CELL))
            for index in range(9)
        ]
    preview = Image.new("RGBA", (5 * 340, 4 * 360), (20, 18, 28, 255))
    draw = ImageDraw.Draw(preview)
    order = list(base.CAST)
    for index, name in enumerate(order):
        spec = base.CAST[name]
        folder = QUESTS / name
        column, row = index % 5, index // 5
        for animation in ("idle", "walk"):
            frames = alice_frames[animation] if spec["body"] == "alice" else male_frames[animation]
            if spec["body"] == "alice":
                sheet, _unknown = base.sheet_alice(frames, spec)
            else:
                sheet = base.sheet_from(frames, spec, animation)
            dressed = Image.new("RGBA", (CELL * 3, CELL * 3), (0, 0, 0, 0))
            for frame_index in range(9):
                cel = sheet.crop(((frame_index % 3) * CELL, (frame_index // 3) * CELL, (frame_index % 3) * CELL + CELL, (frame_index // 3) * CELL + CELL))
                dressed.paste(dress_frame(cel, name, spec), ((frame_index % 3) * CELL, (frame_index // 3) * CELL))
            dressed.save(folder / f"{animation}.png")
            notes, count = measure(dressed)
            print(f"{name:12} {look_line(name):16} {animation:4} colors={count:2} {' '.join(notes)}")
            sample = 0 if animation == "idle" else 4
            cel = dressed.crop(((sample % 3) * CELL, (sample // 3) * CELL, (sample % 3) * CELL + CELL, (sample // 3) * CELL + CELL))
            scaled = cel.resize((160, 160), Image.NEAREST)
            ox = column * 340 + (0 if animation == "idle" else 170)
            oy = row * 360 + 18
            preview.paste(scaled, (ox, oy), scaled)
        draw.text((column * 340 + 4, row * 360 + 2), look_line(name) + " " + name, fill=(240, 220, 180, 255))
    preview_path = Path(r"D:\AppDataRelocated\Local\Temp\quest-wardrobe-preview.png")
    preview.save(preview_path)
    print(preview_path)


def look_line(name):
    look = LOOK[name]
    return f"{look['hair']}/{look['garment']}"


if __name__ == "__main__":
    build()
