"""Paint quest idle/walk/play sheets on the learned 3x3 bodies.

Women use assets/sprites/alice/{idle,walk,play}.png (33 px).
Men use assets/sprites/male/{idle,walk,play}.png (35 px).
Pose and registration stay on that sheet. Identity is hair, cloth
color, and the small accessories already flagged on the cast.
Portraits are not written.
"""

from collections import Counter, deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MALE = ROOT / "assets" / "sprites" / "male"
ALICE = ROOT / "assets" / "sprites" / "alice"
QUESTS = ROOT / "assets" / "quests"
CELL = 160
INK = (0x2E, 0x22, 0x2F)
PUPIL = (0x23, 0x11, 0x26)
EYE = (0xFF, 0xF8, 0xEA)
SCREEN = (0x68, 0xB1, 0xB3)

# Canonical male idle colors. Walk and play frames snap back onto these.
PALETTE = [
    (0x2E, 0x22, 0x2F),
    (0x31, 0x36, 0x38),
    (0xFC, 0xA7, 0x90),
    (0x96, 0x6C, 0x6C),
    (0xFD, 0xCB, 0xB0),
    (0x9B, 0xAB, 0xB2),
    (0xFF, 0xFF, 0xFF),
    (0x62, 0x55, 0x65),
    (0xC7, 0xDC, 0xD0),
    (0x6E, 0x27, 0x27),
    (0x45, 0x29, 0x3F),
    (0xF6, 0x81, 0x81),
    (0x67, 0x66, 0x33),
    (0x37, 0x4E, 0x4A),
    (0x7F, 0x70, 0x8A),
    (0x9E, 0x45, 0x39),
    (0x4C, 0x3E, 0x24),
    (0xCF, 0x65, 0x7F),
    (0xAB, 0x94, 0x7A),
]
SKIN_HI, SKIN_MID, SKIN_SH = (0xFD, 0xCB, 0xB0), (0xFC, 0xA7, 0x90), (0x96, 0x6C, 0x6C)
SHOE_HI, SHOE_MID, SHOE_SH = (0xFF, 0xFF, 0xFF), (0xD8, 0xDC, 0xE0), (0x31, 0x36, 0x38)
DARK_SHOE = ((0x22, 0x20, 0x28), (0x3A, 0x38, 0x48), (0x6A, 0x65, 0x78))
GLASSES = (0x2A, 0x24, 0x30)

DY = {
    "idle": (0, 0, 1, 1, 0, 0, 0, 1, 1),
    "walk": (0, 1, 3, 2, 0, 0, 2, 3, 1),
    "play": (0, 0, 2, 3, 5, 3, 2, 1, 1),
}


def hx(value):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def ramp(mid, shadow=0.58, light=0.42):
    dark = tuple(max(0, min(255, int(channel * shadow))) for channel in mid)
    bright = tuple(max(0, min(255, int(channel + (255 - channel) * light))) for channel in mid)
    if dark == mid:
        dark = tuple(max(0, channel - 28) for channel in mid)
    if bright == mid:
        bright = tuple(min(255, channel + 28) for channel in mid)
    return dark, mid, bright


def cast_entry(hair, jacket, shirt, pants, shoes="light", glasses=False, beard=None, eyes=EYE, body="male"):
    return {
        "body": body,
        "hair": ramp(hx(hair)),
        "jacket": ramp(hx(jacket)),
        "shirt": ramp(hx(shirt), 0.72, 0.28),
        "pants": ramp(hx(pants)),
        "shoes": DARK_SHOE if shoes == "dark" else (SHOE_SH, SHOE_MID, SHOE_HI),
        "glasses": glasses,
        "beard": beard,
        "eyes": eyes,
    }


def woman(hair, jacket, shirt, pants, shoes="light"):
    return cast_entry(hair, jacket, shirt, pants, shoes=shoes, body="alice")


# Colors follow each quest portrait and the written identity.
# Women copy alice. Men copy male.
CAST = {
    "mali": woman("5a3828", "7aaa86", "f0e6d0", "e4d8c4"),
    "boon": cast_entry("c8c4b4", "6a4630", "f0e2c4", "4a382c", glasses=True, beard="moustache"),
    "pim": woman("6a4030", "e09878", "f4e6dc", "c47868"),
    "dao": woman("3a2838", "e06850", "f0d8c0", "a84838"),
    "narin": woman("3a242c", "c43838", "f0d0c8", "8a2428", shoes="dark"),
    "vivian": woman("2c2830", "5a3050", "f3ead8", "3a2838", shoes="dark"),
    "rex": cast_entry("2a2830", "2a2832", "4a4652", "32303a", shoes="dark"),
    "kai": woman("2c2834", "1aa090", "d8ece8", "3a6858"),
    "selene": woman("7a4038", "684078", "f0d8e4", "4a3058", shoes="dark"),
    "beep": cast_entry("4a5568", "f0ece4", "2a8a86", "3a3e48", eyes=SCREEN),
    "orbit": cast_entry("4a3828", "e06028", "f0e0c0", "c46830"),
    "crumb": cast_entry("f0ece0", "c43838", "2a2428", "2a2428", beard="goatee"),
    "mint": woman("2c2830", "3a6840", "d8e0d4", "2a4030"),
    "aki": cast_entry("2c2830", "f0ece8", "c43838", "e8e4e0"),
    "phakin": cast_entry("2c3040", "3a4068", "d8d4cc", "2a3048"),
    "rose": woman("c44848", "c04038", "2a2428", "3a5070"),
    "ingfah": woman("3a2830", "78b0e0", "f0e8e0", "68a0d0"),
    "leo": cast_entry("2a2830", "f0e6d0", "f7f3ea", "2a2830", shoes="dark"),
    "vega": woman("3a3840", "2a2830", "e0c060", "2a2830", shoes="dark"),
    "aurelian": cast_entry("c8c8d0", "f0e6d4", "f7f1e4", "d8d0c4", shoes="dark", beard="beard"),
}


def nearest(color):
    return min(PALETTE, key=lambda item: sum((a - b) * (a - b) for a, b in zip(item, color)))


def load_frames(animation):
    image = Image.open(MALE / f"{animation}.png").convert("RGBA")
    frames = []
    for index in range(9):
        origin = ((index % 3) * CELL, (index // 3) * CELL)
        frames.append(image.crop((origin[0], origin[1], origin[0] + CELL, origin[1] + CELL)))
    return frames


def snap_frame(frame):
    source = frame.load()
    snapped = [[None] * CELL for _ in range(CELL)]
    alpha = [[False] * CELL for _ in range(CELL)]
    for y in range(CELL):
        for x in range(CELL):
            pixel = source[x, y]
            if pixel[3] == 0:
                continue
            alpha[y][x] = True
            snapped[y][x] = nearest(pixel[:3])
    # Drop single-pixel snap noise from the male walk/play color drift.
    cleaned = [row[:] for row in snapped]
    for y in range(CELL):
        for x in range(CELL):
            if not alpha[y][x]:
                continue
            neighbors = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < CELL and 0 <= yy < CELL and alpha[yy][xx]:
                    neighbors.append(snapped[yy][xx])
            if neighbors and all(item != snapped[y][x] for item in neighbors):
                cleaned[y][x] = Counter(neighbors).most_common(1)[0][0]
    edge = [[False] * CELL for _ in range(CELL)]
    for y in range(CELL):
        for x in range(CELL):
            if not alpha[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < CELL and 0 <= yy < CELL and alpha[yy][xx]):
                    edge[y][x] = True
                    break
    return cleaned, alpha, edge


def components(alpha, accept):
    seen = [[False] * CELL for _ in range(CELL)]
    groups = []
    for y in range(CELL):
        for x in range(CELL):
            if seen[y][x] or not alpha[y][x] or not accept(x, y):
                continue
            queue = deque([(x, y)])
            seen[y][x] = True
            pixels = []
            while queue:
                cx, cy = queue.popleft()
                pixels.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = cx + dx, cy + dy
                    if 0 <= xx < CELL and 0 <= yy < CELL and not seen[yy][xx] and alpha[yy][xx] and accept(xx, yy):
                        seen[yy][xx] = True
                        queue.append((xx, yy))
            groups.append(pixels)
    return groups


def paint(snapped, alpha, edge, spec, dy):
    hair_limit = 48 + dy
    shirt = {
        (x, y)
        for y in range(CELL)
        for x in range(CELL)
        if alpha[y][x] and snapped[y][x] == (0xFF, 0xFF, 0xFF) and y < hair_limit + 80 and y > hair_limit
    }
    shirttail = max((y for _, y in shirt), default=84 + dy)
    output = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    pixels = output.load()
    eyes = []
    for y in range(CELL):
        row = snapped[y]
        for x in range(CELL):
            if not alpha[y][x]:
                continue
            color = row[x]
            material = classify(color, x, y, edge[y][x], hair_limit, shirttail)
            if material == "eye":
                eyes.append((x, y))
            pixels[x, y] = tone(material, color, spec, x, y, edge, alpha) + (255,)
    if spec["beard"]:
        top = 40 + dy if spec["beard"] == "moustache" else 41 + dy
        bottom = 43 + dy if spec["beard"] == "moustache" else 46 + dy
        for y in range(top, bottom + 1):
            for x in range(CELL):
                if pixels[x, y][3] and pixels[x, y][:3] in (SKIN_HI, SKIN_MID, SKIN_SH):
                    pixels[x, y] = spec["hair"][0] + (255,)
    eye_set = set(eyes)
    eye_groups = components(alpha, lambda x, y: (x, y) in eye_set)
    for group in eye_groups:
        if len(group) < 2:
            continue
        px, py = max(group)
        pixels[px, py] = PUPIL + (255,)
    return output


def classify(color, x, y, is_edge, hair_limit, shirttail):
    if is_edge:
        return "ink"
    if color == (0x2E, 0x22, 0x2F):
        return "hair" if y < hair_limit else "ink"
    if color == (0x31, 0x36, 0x38):
        return "hair" if y < hair_limit else "shoe"
    if color in ((0xFC, 0xA7, 0x90), (0xFD, 0xCB, 0xB0), (0x96, 0x6C, 0x6C), (0x6E, 0x27, 0x27), (0x45, 0x29, 0x3F), (0xF6, 0x81, 0x81), (0xCF, 0x65, 0x7F), (0x9E, 0x45, 0x39)):
        return "skin"
    if color == (0x62, 0x55, 0x65):
        return "glasses"
    if color == (0xFF, 0xFF, 0xFF):
        if y < hair_limit:
            return "eye"
        if y > shirttail + 18:
            return "shoe"
        return "shirt"
    if color in ((0x67, 0x66, 0x33), (0x37, 0x4E, 0x4A), (0x4C, 0x3E, 0x24)):
        return "pants" if y >= shirttail - 2 else "jacket"
    if color in ((0x9B, 0xAB, 0xB2), (0x7F, 0x70, 0x8A), (0xC7, 0xDC, 0xD0), (0xAB, 0x94, 0x7A)):
        return "jacket"
    return "jacket"


def tone(material, source, spec, x, y, edge, alpha):
    if material == "ink":
        return INK
    if material == "eye":
        return spec["eyes"]
    if material == "glasses":
        return GLASSES if spec["glasses"] else SKIN_MID
    if material == "hair":
        return shade_band(spec["hair"], x, y, edge, alpha)
    if material == "skin":
        if source == SKIN_HI:
            return SKIN_HI
        if source == SKIN_MID:
            return SKIN_MID
        return SKIN_SH
    if material == "jacket":
        if source == (0x7F, 0x70, 0x8A):
            return spec["jacket"][0]
        if source == (0xC7, 0xDC, 0xD0):
            return spec["jacket"][2]
        return shade_band(spec["jacket"], x, y, edge, alpha)
    if material == "shirt":
        return spec["shirt"][2] if source == (0xFF, 0xFF, 0xFF) else spec["shirt"][1]
    if material == "pants":
        if source == (0x4C, 0x3E, 0x24):
            return spec["pants"][0]
        return shade_band(spec["pants"], x, y, edge, alpha)
    if material == "shoe":
        shadow, mid, high = spec["shoes"]
        if source == (0x31, 0x36, 0x38) or y > 132:
            return shadow
        return high
    return INK


def shade_band(ramp_colors, x, y, edge, alpha):
    shadow, mid, high = ramp_colors
    right = x + 1 < CELL and edge[y][x + 1]
    below = y + 1 < CELL and edge[y + 1][x]
    above = y > 0 and (not alpha[y - 1][x] or edge[y - 1][x])
    if right or below:
        return shadow
    if above:
        return high
    return mid


# Alice idle/walk/play share these 20 colors. Stops match the authored shading.
ALICE_HAIR = {
    (0x23, 0x11, 0x26): 0,
    (0x72, 0x40, 0x39): 0,
    (0x5F, 0x31, 0x2E): 1,
    (0x6B, 0x38, 0x2E): 2,
}
ALICE_CLOTH = {(0x7F, 0x60, 0x4A): 0, (0xCB, 0xAD, 0x82): 1, (0xDD, 0xC1, 0x97): 2}
ALICE_PANTS = {(0x15, 0x28, 0x40): 0, (0x2C, 0x50, 0x6B): 1}
ALICE_SKIN = {
    (0xA6, 0x65, 0x4A): 0,
    (0xBB, 0x6C, 0x53): 0,
    (0xFC, 0xBA, 0x83): 1,
    (0xD8, 0x96, 0x74): 1,
    (0xFF, 0xBC, 0x85): 2,
    (0xFC, 0xBF, 0x87): 2,
}
ALICE_SHOE = {(0x73, 0x73, 0x73): 0, (0xF0, 0xF0, 0xF0): 1, (0xFF, 0xFF, 0xFF): 2}
ALICE_EYE = (0xFF, 0xF8, 0xEA)
ALICE_SKIN_OUT = ((0xA6, 0x65, 0x4A), (0xFC, 0xBA, 0x83), (0xFF, 0xBC, 0x85))
ALICE_FILL = {(0x5F, 0x31, 0x2E), (0x6B, 0x38, 0x2E), (0x72, 0x40, 0x39)}


def grid_from(frame):
    source = frame.load()
    grid = [[None] * CELL for _ in range(CELL)]
    for y in range(CELL):
        for x in range(CELL):
            pixel = source[x, y]
            if pixel[3]:
                grid[y][x] = pixel[:3]
    return grid


def neighbor_counts(grid, x, y):
    fill = skin = eye = 0
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        xx, yy = x + dx, y + dy
        if not (0 <= xx < CELL and 0 <= yy < CELL):
            continue
        neighbor = grid[yy][xx]
        if neighbor in ALICE_FILL:
            fill += 1
        elif neighbor in ALICE_SKIN:
            skin += 1
        elif neighbor == ALICE_EYE:
            eye += 1
    return fill, skin, eye


def alice_marks(grid):
    """Keep #231126 as hair, except pupils, a blink, and the mouth."""
    eyes = [(x, y) for y in range(CELL) for x in range(CELL) if grid[y][x] == ALICE_EYE]
    opaque = [(x, y) for y in range(CELL) for x in range(CELL) if grid[y][x] is not None]
    hair_top = min(y for _, y in opaque)
    if eyes:
        eye_bottom = max(y for _, y in eyes)
        eye_left = min(x for x, _ in eyes)
        eye_right = max(x for x, _ in eyes)
        blink = False
    else:
        face = [
            (x, y)
            for y in range(CELL)
            for x in range(CELL)
            if grid[y][x] in ALICE_SKIN and hair_top + 4 <= y <= hair_top + 24
        ]
        eye_bottom = hair_top + 13
        eye_left = min(x for x, _ in face)
        eye_right = max(x for x, _ in face)
        blink = True
    pupils = set()
    mouth = set()
    blink_row = []
    for y in range(CELL):
        for x in range(CELL):
            if grid[y][x] != PUPIL:
                continue
            fill, skin, eye = neighbor_counts(grid, x, y)
            if fill:
                continue
            if eye >= 2:
                pupils.add((x, y))
            elif blink and skin and hair_top + 11 <= y <= hair_top + 15 and eye_left <= x <= eye_right:
                blink_row.append((x, y))
            elif skin >= 3 and y >= eye_bottom + 4 and eye_left + 2 <= x <= eye_right - 2:
                mouth.add((x, y))
    if blink_row:
        lid_y = max({y for _, y in blink_row}, key=lambda row: sum(1 for _, yy in blink_row if yy == row))
        for x, y in blink_row:
            if y != lid_y:
                continue
            run = 1
            xx = x - 1
            while xx >= 0 and grid[y][xx] == PUPIL:
                run += 1
                xx -= 1
            xx = x + 1
            while xx < CELL and grid[y][xx] == PUPIL:
                run += 1
                xx += 1
            if run >= 3:
                pupils.add((x, y))
    return pupils, mouth


def paint_alice(frame, spec):
    grid = grid_from(frame)
    pupils, mouth = alice_marks(grid)
    output = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    pixels = output.load()
    unknown = 0
    for y in range(CELL):
        for x in range(CELL):
            color = grid[y][x]
            if color is None:
                continue
            if color == INK:
                painted = INK
            elif color == ALICE_EYE:
                painted = spec["eyes"]
            elif color in ALICE_CLOTH:
                painted = spec["jacket"][ALICE_CLOTH[color]]
            elif color in ALICE_PANTS:
                painted = spec["pants"][ALICE_PANTS[color]]
            elif color in ALICE_SKIN:
                painted = ALICE_SKIN_OUT[ALICE_SKIN[color]]
            elif color in ALICE_SHOE:
                painted = spec["shoes"][ALICE_SHOE[color]]
            elif color in ALICE_HAIR:
                painted = PUPIL if (x, y) in pupils or (x, y) in mouth else spec["hair"][ALICE_HAIR[color]]
            else:
                unknown += 1
                painted = INK
            pixels[x, y] = painted + (255,)
    return output, unknown


def sheet_alice(frames, spec):
    sheet = Image.new("RGBA", (CELL * 3, CELL * 3), (0, 0, 0, 0))
    unknown = 0
    for index, frame in enumerate(frames):
        cel, missed = paint_alice(frame, spec)
        unknown += missed
        sheet.paste(cel, ((index % 3) * CELL, (index // 3) * CELL))
    return sheet, unknown


def sheet_from(frames, spec, animation):
    sheet = Image.new("RGBA", (CELL * 3, CELL * 3), (0, 0, 0, 0))
    prepared = [snap_frame(frame) for frame in frames]
    for index, (snapped, alpha, edge) in enumerate(prepared):
        cel = paint(snapped, alpha, edge, spec, DY[animation][index])
        sheet.paste(cel, ((index % 3) * CELL, (index // 3) * CELL))
    return sheet


def check(sheet, animation, width):
    pixels = sheet.load()
    partial = 0
    colors = set()
    problems = []
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
            if maxy != 136:
                problems.append(f"sole {maxy}")
            found_width, height = maxx - minx + 1, maxy - miny + 1
            if found_width != width or not 111 <= height <= 114:
                problems.append(f"size {found_width}x{height}")
            if not 55 <= minx and maxx <= 110:
                problems.append(f"x {minx}-{maxx}")
        elif animation == "walk" and not 134 <= maxy <= 137:
            problems.append(f"f{index} sole {maxy}")
    if partial:
        problems.append(f"partial {partial}")
    if len(colors) > 26:
        problems.append(f"colors {len(colors)}")
    return problems, len(colors)


def main():
    male_frames = {name: load_frames(name) for name in ("idle", "walk", "play")}
    alice_frames = {}
    image_root = ALICE
    for name in ("idle", "walk", "play"):
        image = Image.open(image_root / f"{name}.png").convert("RGBA")
        frames = []
        for index in range(9):
            origin = ((index % 3) * CELL, (index // 3) * CELL)
            frames.append(image.crop((origin[0], origin[1], origin[0] + CELL, origin[1] + CELL)))
        alice_frames[name] = frames
    for name, spec in CAST.items():
        folder = QUESTS / name
        folder.mkdir(parents=True, exist_ok=True)
        width = 33 if spec["body"] == "alice" else 35
        for animation in ("idle", "walk", "play"):
            if spec["body"] == "alice":
                sheet, unknown = sheet_alice(alice_frames[animation], spec)
            else:
                sheet = sheet_from(male_frames[animation], spec, animation)
                unknown = 0
            problems, count = check(sheet, animation, width)
            if unknown:
                problems.append(f"unknown {unknown}")
            sheet.save(folder / f"{animation}.png")
            status = "ok" if not problems else " ".join(problems)
            print(f"{name:12} {spec['body']:5} {animation:4} colors={count:2} {status}")


if __name__ == "__main__":
    main()
