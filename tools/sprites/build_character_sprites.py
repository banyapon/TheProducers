#!/usr/bin/env python3
"""Redraw every NPC/VIP/Alice on the motion of assets/sprites/male (9 frames x 4 sheets).

The male sheets provide pose and timing. Each frame is split into semantic parts
(cloth, inner, skin, pants, shoes, outline), recoloured from the character's 6x4 sheet,
then given a head rebuilt from the hair silhouette of their 2x2 portrait.

Writes raw 480x480 sheets to <out>/<id>/<animation>.png. Aseprite then assembles the
sources and final sheets (see assemble_sprites.lua).

    python tools/sprites/build_character_sprites.py <out> [id ...]
"""
import colorsys
import json
import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
ANIMS = ["idle", "walk", "talk", "play"]
CELL = 160
OUTLINE = (0x2e, 0x22, 0x2f)

# Classes of the semantic body map.
EMPTY, LINE, CLOTH, INNER, SKIN, PANTS, SHOES = range(7)

# Source palette of the male sprite: colour -> group and tone (0 darkest).
SOURCE = {
    0x2e222f: ("line", 0), 0x45293f: ("line", 0), 0x313638: ("line", 0),
    0x625565: ("gray", 0), 0x7f708a: ("gray", 1), 0x9babb2: ("gray", 2),
    0xc7dcd0: ("white", 1), 0xffffff: ("white", 2),
    0x4c3e24: ("olive", 0), 0x374e4a: ("olive", 0), 0x676633: ("olive", 1),
    0xab947a: ("skin", 1), 0x966c6c: ("skin", 0), 0x6e2727: ("skin", 0), 0x9e4539: ("skin", 0),
    0xcf657f: ("skin", 0), 0xf68181: ("skin", 1), 0xfca790: ("skin", 1), 0xfdcbb0: ("skin", 2),
}
SOURCE_RGB = np.array([[(k >> 16) & 255, (k >> 8) & 255, k & 255] for k in SOURCE], dtype=np.int32)
SOURCE_INFO = list(SOURCE.values())
GROUPS = ["line", "gray", "white", "olive", "skin"]

# Per-character art direction, read from the 6x4 and 2x2 references.
# cloth/inner/pants come from the 6x4 sheet; hair/skin come from the portrait palette.
# style: closed (tee, polo, hoodie, closed shirt) or open (jacket, suit, vest, open shirt)
# below: rows of hair allowed below the chin; extra: rows long hair keeps growing past the portrait.
CAST = {
    "alice": dict(style="closed", cloth="c1a47b", collar=True, buttons=True, below=30, extra=16, pants="284861"),
    "npc-01-male-buzz": dict(style="open", inner="fbefdf", sleeves=True),
    "npc-02-female-bob": dict(style="closed", cloth="fb7a64", below=3),
    "npc-03-male-sidepart": dict(style="open", inner="e59536", sleeves=True),
    "npc-04-female-long": dict(style="closed", below=30, extra=18),
    "npc-05-male-spikes": dict(style="closed"),
    "npc-06-female-ponytail": dict(style="closed", below=30, extra=8),
    "npc-07-male-quiff": dict(style="open", inner="f5e7da", sleeves=True),
    "npc-08-female-bun": dict(style="closed", cloth="9fa4ae"),
    "npc-09-male-curly": dict(style="open", inner="f4e3cc", sleeves=True),
    "npc-10-female-braid": dict(style="closed", cloth="e983b2", below=30, extra=14, glasses="2e222f"),
    "npc-11-male-bald": dict(style="open", inner="2b2d3f", sleeves=True, beard="4b4040", bald=True),
    "npc-12-female-wavy": dict(style="open", inner="eb655e", below=30, extra=12),
    "npc-13-male-mohawk": dict(style="closed", hoodie=True, sleeves=True),
    "npc-14-female-pixie": dict(style="open", inner="f9edde", sleeves=True),
    "npc-15-male-shag": dict(style="closed", below=4),
    "npc-16-female-sidesweep": dict(style="open", inner="faefe4", below=3),
    "npc-17-male-ponytail": dict(style="closed", collar=True, buttons=True, stubble="9c6b55", below=24, extra=3),
    "npc-18-female-twintails": dict(style="closed", cloth="3757b2", hoodie=True, sleeves=True, below=30, extra=8),
    "npc-19-male-afro": dict(style="closed", hoodie=True, sleeves=True, beard="281c2d"),
    "npc-20-female-curly": dict(style="closed", cloth="3dc4c6", collar=True, below=30, extra=8),
    "npc-21-male-undercut": dict(style="open", inner="f9efe1", sleeves=True),
    "npc-22-female-bangs": dict(style="closed", cloth="fccc51", below=2),
    "npc-23-male-sidesweep": dict(style="open", inner="fbf3dd"),
    "npc-24-female-highpony": dict(style="closed", cloth="eb6757", below=24, extra=4),
    "super-01": dict(style="open", inner="f9ecde", sleeves=True, tie="d6a23f", glasses="7a5a2a"),
    "super-02": dict(style="open", inner="d97054", below=3),
    "super-03": dict(style="open", inner="fbead6", sleeves=True, tie="d9822b", beard="3a2228"),
    "super-04": dict(style="open", inner="f8e6d0", sleeves=True),
    "super-05": dict(style="open", inner="f9eee2", sleeves=True, tie="2f5da8", glasses="6a5a6a", bald=True),
    "super-06": dict(style="closed", cloth="5b2d75", sleeves=True),
}


def rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def ramp(base, steps=(-0.34, -0.16, 0.0, 0.16)):
    """Four tones with cool shadows and warm lights, as the male palette does."""
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb(base) if True))
    tones = []
    for step in steps:
        hue = h
        if s > 0.08:
            target = 0.78 if step < 0 else 0.13
            delta = (target - h + 0.5) % 1.0 - 0.5
            hue = (h + delta * abs(step) * 0.28) % 1.0
        sat = min(1.0, s * (1 + (-step) * 0.45)) if step < 0 else s * (1 - step * 0.8)
        val = min(1.0, max(0.04, v * (1 + step) if step < 0 else v + (1 - v) * step * 1.8 + 0.04))
        if step < 0 and v < 0.28:
            val = v * (1 + step * 0.5)
        tones.append(tuple(round(c * 255) for c in colorsys.hsv_to_rgb(hue, sat, val)))
    return tones


def box_neighbours(mask, radius):
    return ndi.binary_dilation(mask, structure=np.ones((radius * 2 + 1, radius * 2 + 1), bool))


def ring(mask):
    return ndi.binary_dilation(mask, structure=ndi.generate_binary_structure(2, 1)) & ~mask


# ---------------------------------------------------------------- male motion analysis

def load_male():
    frames = {}
    for animation in ANIMS:
        sheet = np.array(Image.open(ASSETS / f"sprites/male/{animation}.png").convert("RGBA"))
        frames[animation] = [sheet[(i // 3) * CELL:(i // 3 + 1) * CELL, (i % 3) * CELL:(i % 3 + 1) * CELL] for i in range(9)]
    return frames


def snap(frame):
    """Maps a frame to source (group index, tone) through the nearest source colour."""
    alpha = frame[..., 3] > 0
    diff = frame[..., :3].astype(np.int32)[:, :, None, :] - SOURCE_RGB[None, None]
    nearest = (diff * diff).sum(-1).argmin(-1)
    groups = np.full(alpha.shape, -1, np.int8)
    tones = np.zeros(alpha.shape, np.int8)
    for index, (group, tone) in enumerate(SOURCE_INFO):
        hit = (nearest == index) & alpha
        groups[hit] = GROUPS.index(group)
        tones[hit] = tone
    return groups, tones


HEAD_BOX = (66, 22, 92, 48)  # x0, y0, x1, y1 of the male head in idle frame 0.
CHIN = (79, 46)  # bottom of the face in idle frame 0.


def head_offsets(frames):
    x0, y0, x1, y1 = HEAD_BOX
    template = frames["idle"][0][y0:y1, x0:x1].astype(np.int32)
    weight = template[..., 3:] > 0
    offsets = {}
    for animation in ANIMS:
        offsets[animation] = []
        for frame in frames[animation]:
            best, best_score = (0, 0), None
            for dy in range(-4, 9):
                for dx in range(-16, 9):
                    window = frame[y0 + dy:y1 + dy, x0 + dx:x1 + dx].astype(np.int32)
                    delta = np.abs(window[..., :3] - template[..., :3]).sum(-1, keepdims=True)
                    delta = delta + (window[..., 3:] == 0) * 500
                    score = (delta * weight).sum()
                    if best_score is None or score < best_score:
                        best_score, best = score, (dx, dy)
            offsets[animation].append(best)
    return offsets


def parse_body(frame, offset):
    """Returns class/tone maps of a frame with the male head removed."""
    groups, tones = snap(frame)
    labels = np.zeros(groups.shape, np.int8)
    out_tones = np.zeros(groups.shape, np.int8)
    dx, dy = offset
    line, gray, white, olive, skin = range(5)
    # Tee bottom marks the waist; everything lower is pants or shoes.
    rows = np.where(((groups == white) & (tones == 2)).any(1))[0]
    rows = rows[(rows > 46 + dy) & (rows < 98)]
    waist = int(rows.max()) if rows.size else 76
    # Shirt hem hangs a few rows under the tee; gray further down is a shoe.
    cloth_gray = (groups == gray) & (np.arange(CELL)[:, None] <= waist + 10)
    near_cloth = box_neighbours(cloth_gray, 3)

    shoes_top = 118
    for y in range(CELL):
        for x in range(CELL):
            group = groups[y, x]
            if group < 0:
                continue
            tone = tones[y, x]
            if group == line:
                labels[y, x], out_tones[y, x] = LINE, 0
            elif group == skin:
                labels[y, x], out_tones[y, x] = SKIN, tone
            elif group == gray:
                if y <= waist + 10:
                    labels[y, x], out_tones[y, x] = CLOTH, tone
                else:
                    labels[y, x], out_tones[y, x] = SHOES, 1
            elif group == white:
                if y <= waist + 2:
                    labels[y, x], out_tones[y, x] = INNER, tone
                else:
                    labels[y, x], out_tones[y, x] = SHOES, tone + 1
            else:  # olive
                if y <= waist + 8 and near_cloth[y, x]:
                    labels[y, x], out_tones[y, x] = CLOTH, tone
                elif y >= shoes_top + 12:
                    labels[y, x], out_tones[y, x] = SHOES, 0
                else:
                    labels[y, x], out_tones[y, x] = PANTS, tone + (1 if tone else 0)
    specks, count = ndi.label(labels == SKIN, structure=np.ones((3, 3)))
    for index in range(1, count + 1):
        part = specks == index
        if part.sum() < 10 and box_neighbours(part, 1)[labels == CLOTH].any():
            labels[part], out_tones[part] = CLOTH, 1
    # Remove the head: all rows above the chin around its tracked position.
    chin_y = CHIN[1] + dy
    head_area = np.zeros(labels.shape, bool)
    head_area[:chin_y + 1, HEAD_BOX[0] + dx - 5:HEAD_BOX[2] + dx + 5] = True
    labels[head_area] = EMPTY
    return labels, out_tones, waist


def sleeves_on_forearms(labels, tones, neck_x, chin_y, waist):
    """Long sleeves: forearm skin becomes cloth; only the hand stays bare."""
    components, count = ndi.label(labels == SKIN, structure=np.ones((3, 3)))
    yy, xx = np.ogrid[:CELL, :CELL]
    for index in range(1, count + 1):
        part = components == index
        ys, xs = np.where(part)
        if ys.size < 20 or (ys.min() <= chin_y + 8 and abs(xs.mean() - neck_x) < 7):
            continue  # neck or a stray shade pixel
        # The two ends of the forearm are its most distant pixels.
        points = np.stack([ys, xs], 1)
        start = points[((points - points.mean(0)) ** 2).sum(1).argmax()]
        end_a = points[((points - start) ** 2).sum(1).argmax()]
        end_b = points[((points - end_a) ** 2).sum(1).argmax()]
        if ((end_a - end_b) ** 2).sum() < 13 ** 2:
            continue  # foreshortened: only a hand shows
        lower, upper = (end_a, end_b) if end_a[0] > end_b[0] else (end_b, end_a)
        inner, outer = (end_a, end_b) if abs(end_a[1] - neck_x) < abs(end_b[1] - neck_x) else (end_b, end_a)
        hands = []
        half = xs.mean()
        left, right = points[xs < half], points[xs >= half]
        crossed = xs.max() - xs.min() >= 14 and left.size and right.size \
            and abs(left[:, 0].min() - right[:, 0].min()) <= 6 and ys.min() < waist - 8
        if crossed:  # Both forearms touch: the hands are the two highest points.
            hands = [left[left[:, 0].argmin()], right[right[:, 0].argmin()]]
        elif lower[0] >= waist + 2 or (lower is outer and lower[0] >= waist - 3):
            hands = [lower]  # A hanging arm reaches the waist.
        elif abs(outer[1] - neck_x) - abs(inner[1] - neck_x) >= 5:
            hands = [inner]  # A bent arm brings the hand in front of the body.
        else:
            hands = [upper]  # A lifted forearm.
        hand = np.zeros(part.shape, bool)
        radius = 6.0 if crossed else 7.5
        for tip in hands:
            hand |= (yy - tip[0]) ** 2 + (xx - tip[1]) ** 2 <= radius ** 2
        sleeve = part & ~hand
        labels[sleeve] = CLOTH
        tones[sleeve] = np.clip(tones[sleeve], 0, 2)
        labels[part & hand & box_neighbours(sleeve, 1)] = LINE  # cuff


def close_garment(labels, tones):
    """Tee, hoodie, polo: one garment, so the open-shirt seams go away."""
    inner = labels == INNER
    for y in np.where(inner.any(1))[0]:
        xs = np.where(inner[y])[0]
        for x in range(xs.min() - 4, xs.max() + 5):
            if labels[y, x] == LINE and labels[y, max(x - 1, 0):x + 2].astype(bool).all():
                labels[y, x], tones[y, x] = CLOTH, 1
    labels[inner] = CLOTH
    tones[inner] = np.where(tones[inner] >= 2, 2, 1)


def narrow_female(labels, tones, waist, chin_y, center):
    """Slimmer torso by removing columns at the body centre, so outlines stay intact."""
    new_labels, new_tones = labels.copy(), tones.copy()
    for y in range(chin_y + 4, waist + 15):
        progress = (y - (chin_y + 4)) / max(1, waist - chin_y - 4)
        cut = 2 if progress < 0.3 else 3 if progress < 0.95 else 2 if y < waist + 8 else 1
        left = cut // 2
        right = cut - left
        for source, target in ((labels, new_labels), (tones, new_tones)):
            row = source[y].copy()
            target[y] = 0
            target[y, left:center] = row[:center - left]
            target[y, center:CELL - right] = row[center + right:]
    return new_labels, new_tones


def colourize(labels, tones, ramps):
    image = np.zeros((CELL, CELL, 4), np.uint8)
    image[labels == LINE] = (*OUTLINE, 255)
    for label, tone_map in ((CLOTH, {0: 0, 1: 1, 2: 2}), (INNER, {0: 0, 1: 1, 2: 2}), (SKIN, {0: 0, 1: 1, 2: 2}),
                            (PANTS, {0: 0, 1: 1, 2: 2}), (SHOES, {0: 0, 1: 1, 2: 2, 3: 3})):
        for tone, index in tone_map.items():
            hit = (labels == label) & (tones == tone)
            image[hit] = (*ramps[label][index], 255)
    return image


# ---------------------------------------------------------------- head rebuilt from the portrait

def lab(colors):
    c = np.asarray(colors, float) / 255
    return np.stack([0.3 * c[..., 0] + 0.59 * c[..., 1] + 0.11 * c[..., 2],
                     c[..., 0] - c[..., 1], c[..., 1] - c[..., 2]], -1) * np.array([1.0, 1.4, 1.4])


HEAD_SCALE = 0.55  # All portraits share one framing, so one scale keeps head sizes even.
FACE_WIDTHS = [7, 9, 11, 13, 13, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 13, 11, 9]  # from the chin up
EYE_ABOVE_CHIN = 8
CANVAS_W, CANVAS_H, CHIN_ROW, CENTRE = 72, 112, 60, 36


def face_template(female):
    face = np.zeros((CANVAS_H, CANVAS_W), bool)
    widths = list(FACE_WIDTHS)
    if female:
        widths[:4] = [5, 7, 9, 11]
    for up, width in enumerate(widths):
        face[CHIN_ROW - up, CENTRE - width // 2:CENTRE + width // 2 + 1] = True
    return face


def portrait_head(char_id, entry, spec, female):
    path = ASSETS / entry["reference_portrait"][len("res://assets/"):]
    sheet = np.array(Image.open(path).convert("RGBA"))
    cell = sheet[:sheet.shape[0] // 2, :sheet.shape[1] // 2].copy()
    size = cell.shape[0]
    palette = entry["palette"]
    skin_lab, hair_lab = lab(rgb(palette["skin"])), lab(rgb(palette["hair"]))
    colors = lab(cell[..., :3])
    alpha = cell[..., 3] > 0
    skin_dist = np.linalg.norm(colors - skin_lab, axis=-1)
    hair_dist = np.linalg.norm(colors - hair_lab, axis=-1)

    # Locate the face only to align the portrait: biggest skin area and the eye whites in it.
    skin = alpha & (skin_dist < 0.20) & (skin_dist < hair_dist + 0.02)
    components, count = ndi.label(skin)
    sizes = ndi.sum(skin, components, range(1, count + 1))
    face = ndi.binary_fill_holes(components == (int(np.argmax(sizes)) + 1))
    ys, _ = np.where(face)
    top, bottom = ys.min(), ys.max()
    whites = face & alpha & (cell[..., :3].min(-1) > 215)
    wy, wx = np.where(whites)
    eye_row = int(np.median(wy)) if wy.size else int(top + (bottom - top) * 0.5)
    cols = np.where(face[eye_row])[0]
    centre = (cols.min() + cols.max()) / 2
    eye_x = wx.mean() if wx.size else centre
    flip = eye_x > centre + 0.5  # The sprite looks to its left, like the male sprite.

    # Hair: dark or hair-coloured pixels, minus the skin.
    hair = alpha & ~skin & (hair_dist < 0.24)
    outlines = alpha & ~skin & (colors[..., 0] < 0.2)
    outlines[max(eye_row - 6, 0):] = False
    hair |= outlines
    if spec.get("bald"):
        hair &= hair_dist < 0.18
    cloth = lab(rgb(spec.get("cloth", palette["cloth"])))
    if np.linalg.norm(cloth - hair_lab) > 0.10:
        hair &= ~(np.linalg.norm(colors - cloth, axis=-1) < 0.08)

    eye_px = CHIN_ROW - EYE_ABOVE_CHIN
    hair_small = np.zeros((CANVAS_H, CANVAS_W), bool)
    tone_small = np.full((CANVAS_H, CANVAS_W), 2, np.int8)
    luminance = colors[..., 0]
    base = float(lab(rgb(palette["hair"]))[0])
    for y in range(CANVAS_H):
        for x in range(CANVAS_W):
            sx0, sx1 = (x - CENTRE) / HEAD_SCALE + centre, (x + 1 - CENTRE) / HEAD_SCALE + centre
            sy0, sy1 = (y - eye_px) / HEAD_SCALE + eye_row, (y + 1 - eye_px) / HEAD_SCALE + eye_row
            ix0, ix1, iy0, iy1 = int(np.floor(sx0)), int(np.ceil(sx1)), int(np.floor(sy0)), int(np.ceil(sy1))
            if ix1 <= 0 or iy1 <= 0 or ix0 >= size or iy0 >= size:
                continue
            part = hair[max(iy0, 0):min(iy1, size), max(ix0, 0):min(ix1, size)]
            if part.size and part.mean() >= 0.45:
                hair_small[y, x] = True
                lum = luminance[max(iy0, 0):min(iy1, size), max(ix0, 0):min(ix1, size)][part].mean()
                tone_small[y, x] = 3 if lum > base + 0.07 and y < eye_px - 4 else 1 if lum < base - 0.05 else 2

    below = spec.get("below", 0)
    extra = spec.get("extra", 0)
    # The portrait ends at the shoulders: long hair grows on, one rounded lock per run of hair.
    if extra and below > 8:
        beside = hair_small.copy()
        beside[:, CENTRE - 3:CENTRE + 4] = False
        beside[:CHIN_ROW] = False
        rows = np.where(beside.sum(1) >= 2)[0]
        last_row = int(rows.max()) if rows.size else CHIN_ROW
        length = CHIN_ROW + extra - last_row
        runs, count = ndi.label(beside[last_row])
        for run in range(1, count + 1):
            xs = np.where(runs == run)[0]
            for k in range(1, length + 1):
                inset = max(0, k - (length - 2))
                start, end = xs.min() + inset, xs.max() - inset
                if start <= end:
                    hair_small[last_row + k, start:end + 1] = True
                    tone_small[last_row + k, start:end + 1] = 2
        hair_small[CHIN_ROW + 2:, CENTRE - 3:CENTRE + 4] = False
    else:
        hair_small[CHIN_ROW + below + 1:] = False

    # Keep the features clear: from the brows down, hair may only touch the face edge.
    face_mask = face_template(female)
    clear_from = eye_px - 4
    inner = ndi.binary_erosion(face_mask, iterations=1)
    keep_out = inner & (np.arange(CANVAS_H)[:, None] >= clear_from)
    if flip:
        hair_small, tone_small = hair_small[:, ::-1], tone_small[:, ::-1]
    hair_small &= ~keep_out
    if not spec.get("bald"):
        crown = face_mask & (np.arange(CANVAS_H)[:, None] < clear_from - 1)
        hair_small |= crown

    labelled, count = ndi.label(hair_small, structure=np.ones((3, 3)))
    if count:
        sizes = ndi.sum(hair_small, labelled, range(1, count + 1))
        keep = [i + 1 for i, area in enumerate(sizes) if area >= 25 or area == sizes.max()]
        hair_small = np.isin(labelled, keep)
    return dict(hair=hair_small, tones=tone_small, face=face_mask, chin=CHIN_ROW, centre=CENTRE, eye=eye_px)


def draw_head(head, spec, ramps, female, animation, frame_index, sway):
    """Returns one head pose: face plate, features, then hair on top."""
    hair, tones, face = head["hair"], head["tones"], head["face"]
    h, w = hair.shape
    chin, centre, eye_row = head["chin"], head["centre"], head["eye"]
    image = np.zeros((h, w, 4), np.uint8)
    hair_ramp, skin_ramp = ramps["hair"], ramps[SKIN]

    if sway:  # Secondary motion: hair under the chin lags behind the body.
        hair, tones = hair.copy(), tones.copy()
        for y in range(chin + 7, h):
            hair[y], tones[y] = np.roll(hair[y], sway), np.roll(tones[y], sway)

    image[ring(face)] = (*OUTLINE, 255)
    image[face] = (*skin_ramp[2], 255)
    xx, yy = np.arange(w)[None, :], np.arange(h)[:, None]
    # Light from the left of the image, jaw in soft shadow.
    edge = face & ~ndi.binary_erosion(face, iterations=1)
    image[edge & (xx > centre)] = (*skin_ramp[1], 255)
    image[face & (yy == chin)] = (*skin_ramp[1], 255)

    def px(x, y, colour):
        if 0 <= y < h and 0 <= x < w:
            image[y, x] = (*colour, 255)

    for key, rows in (("beard", 6), ("stubble", 4)):
        if key in spec:
            tone = rgb(spec[key])
            for y in range(chin - rows, chin + 1):
                cols = np.where(face[y])[0]
                for x in range(cols.min(), cols.max() + 1):
                    if key == "stubble" and (x + y) % 2:
                        continue
                    if key == "beard" and y < chin - 3 and cols.min() + 2 <= x <= cols.max() - 2:
                        continue  # cheeks stay clear, the moustache is added below
                    px(x, y, tone)

    left_eye, right_eye = centre - 6, centre + 1  # eye = 3 wide; faces turn slightly left
    nose_x = centre - 1
    blink = (animation == "idle" and frame_index == 4) or (animation == "talk" and frame_index == 5)
    brow = hair_ramp[0] if not spec.get("bald") else (0x4b, 0x40, 0x40)
    for eye in (left_eye, right_eye):
        for dx in range(0, 3):
            px(eye + dx, eye_row - 3, brow)
        if blink:
            for dx in range(0, 3):
                px(eye + dx, eye_row, OUTLINE)
        else:
            if "glasses" not in spec:
                for dx in range(0, 3):
                    px(eye + dx, eye_row - 1, OUTLINE)
            px(eye, eye_row, OUTLINE)
            px(eye + 1, eye_row, OUTLINE)
            px(eye + 2, eye_row, (255, 255, 255))
            px(eye, eye_row + 1, (255, 255, 255))
            px(eye + 1, eye_row + 1, OUTLINE)
            px(eye + 2, eye_row + 1, (255, 255, 255))
        if female:
            px(eye - 1 if eye == left_eye else eye + 3, eye_row - 1, OUTLINE)
    px(nose_x, eye_row + 3, skin_ramp[0])
    px(nose_x + 1, eye_row + 3, skin_ramp[1])
    mouth_y = chin - 3
    if "beard" in spec:
        for dx in range(-2, 3):
            px(nose_x + dx, mouth_y - 1, rgb(spec["beard"]))
    lip = (0xc2, 0x4b, 0x5a) if female else (0x9e, 0x45, 0x39)
    for dx in range(-1, 2):
        px(nose_x + dx, mouth_y, lip)
    if animation == "talk" and frame_index % 2 == 1:
        for dx in range(-1, 2):
            px(nose_x + dx, mouth_y + 1, (0x6e, 0x27, 0x27))
    if female:
        px(left_eye, eye_row + 3, skin_ramp[1])
        px(right_eye + 2, eye_row + 3, skin_ramp[1])
    if "glasses" in spec:
        tone = rgb(spec["glasses"])
        for eye in (left_eye, right_eye):
            for dx in range(-1, 4):
                px(eye + dx, eye_row - 2, tone)
                px(eye + dx, eye_row + 2, tone)
            for dy in range(-1, 2):
                px(eye - 1, eye_row + dy, tone)
                px(eye + 3, eye_row + dy, tone)

    if hair.any():
        image[ring(hair) & ~ndi.binary_erosion(face, iterations=1)] = (*OUTLINE, 255)
        for tone_index, ramp_index in ((1, 1), (2, 2), (3, 3)):
            image[hair & (tones == tone_index)] = (*hair_ramp[ramp_index], 255)
        image[hair & ~ndi.binary_erosion(hair, iterations=1) & (xx > centre + 2)] = (*hair_ramp[1], 255)
        image[hair & (yy > chin + 2) & ((xx * 3 + yy // 5) % 6 == 0)] = (*hair_ramp[0], 255)
    return image


def paste(canvas, layer, x, y):
    lh, lw = layer.shape[:2]
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + lw, canvas.shape[1]), min(y + lh, canvas.shape[0])
    if x1 <= x0 or y1 <= y0:
        return
    source = layer[y0 - y:y1 - y, x0 - x:x1 - x]
    hit = source[..., 3] > 0
    canvas[y0:y1, x0:x1][hit] = source[hit]


# ---------------------------------------------------------------- garment details

def details(image, labels, offset, waist, spec, ramps, closed):
    dx, dy = offset
    neck_x = CHIN[0] + dx
    collar_y = CHIN[1] + dy + 4
    cloth = ramps[CLOTH]
    if closed and spec.get("hoodie"):
        for x in range(neck_x - 7, neck_x + 8):
            for y in range(collar_y - 1, collar_y + 4):
                if labels[y, x] == CLOTH or labels[y, x] == LINE:
                    if abs(x - neck_x) >= 2 or y >= collar_y + 2:
                        image[y, x] = (*cloth[1 if y < collar_y + 2 else 0], 255)
        for side in (-2, 2):
            for y in range(collar_y + 3, collar_y + 10):
                if labels[y, neck_x + side] == CLOTH:
                    image[y, neck_x + side] = (*cloth[3], 255)
    if closed and spec.get("collar"):
        for side in (-1, 1):
            for k in range(0, 4):
                x, y = neck_x + side * (2 + k), collar_y + k // 2
                if labels[y, x] in (CLOTH, LINE, SKIN):
                    image[y, x] = (*cloth[3], 255)
                if labels[y + 1, x] == CLOTH:
                    image[y + 1, x] = (*cloth[0], 255)
    if closed and spec.get("buttons"):
        for y in range(collar_y + 3, waist + 1):
            if labels[y, neck_x] == CLOTH:
                image[y, neck_x] = (*cloth[1], 255)
    if not closed and "tie" in spec:
        tie = ramp(spec["tie"])
        for y in range(collar_y + 1, waist - 4):
            half = 0 if y < collar_y + 3 else 1
            for x in range(neck_x - half, neck_x + half + 1):
                if labels[y, x] == INNER:
                    image[y, x] = (*tie[2 if x <= neck_x else 1], 255)


# ---------------------------------------------------------------- character

def build_character(char_id, entry, spec, male, offsets, out):
    palette = entry["palette"]
    female = (char_id == "alice" or "female" in char_id or (char_id.startswith("super-") and int(char_id[-2:]) % 2 == 0))
    cloth = spec.get("cloth", palette["cloth"])
    closed = spec["style"] == "closed"
    world = np.array(Image.open(ASSETS / entry["reference_world"][len("res://assets/"):]).convert("RGBA").resize((192, 192), 0))
    pants_sample = world[:48, :32][35:40, 11:21].reshape(-1, 4)
    pants_sample = pants_sample[pants_sample[:, 3] > 0][:, :3]
    pants_sample = pants_sample[pants_sample.astype(int).sum(1) > 150]  # outlines are not the colour
    if "pants" in spec:
        pants = spec["pants"]
    else:
        values, counts = np.unique(pants_sample, axis=0, return_counts=True)
        pants = "%02x%02x%02x" % tuple(values[counts.argmax()])
    ramps = {
        CLOTH: ramp(cloth), INNER: ramp(spec.get("inner", cloth)), SKIN: ramp(palette["skin"], (-0.34, -0.14, 0.0, 0.1)),
        PANTS: ramp(pants, (-0.34, -0.16, 0.0, 0.14)), SHOES: ramp(palette["shoes"], (-0.55, -0.22, -0.06, 0.0)),
        "hair": ramp(palette["hair"], (-0.4, -0.2, 0.0, 0.1)),
    }
    head = portrait_head(char_id, entry, spec, female)
    target = out / char_id
    target.mkdir(parents=True, exist_ok=True)
    for animation in ANIMS:
        sheet = np.zeros((CELL * 3, CELL * 3, 4), np.uint8)
        for index, frame in enumerate(male[animation]):
            offset = offsets[animation][index]
            labels, tones, waist = parse_body(frame, offset)
            chin_y = CHIN[1] + offset[1]
            neck_x = CHIN[0] + offset[0]
            if spec.get("sleeves"):
                sleeves_on_forearms(labels, tones, neck_x, chin_y, waist)
            if closed:
                close_garment(labels, tones)
            if female:
                labels, tones = narrow_female(labels, tones, waist, chin_y, neck_x)
            image = colourize(labels, tones, ramps)
            details(image, labels, offset, waist, spec, ramps, closed)
            sway = 0
            if animation == "walk":
                sway = [0, 1, 1, 0, -1, -1, 0, 1, 0][index]
            elif animation == "play":
                sway = [0, 0, 1, 1, 0, -1, -1, 0, 0][index]
            pose = draw_head(head, spec, ramps, female, animation, index, sway)
            paste(image, pose, neck_x - head["centre"], chin_y - head["chin"])
            x, y = (index % 3) * CELL, (index // 3) * CELL
            sheet[y:y + CELL, x:x + CELL] = image
        Image.fromarray(sheet, "RGBA").save(target / f"{animation}.png")


def main():
    out = pathlib.Path(sys.argv[1])
    only = sys.argv[2:]
    manifest = json.loads((ASSETS / "fullbody/manifest.json").read_text(encoding="utf-8"))["characters"]
    male = load_male()
    offsets = head_offsets(male)
    print({k: v for k, v in offsets.items()})
    for char_id, spec in CAST.items():
        if only and char_id not in only:
            continue
        build_character(char_id, manifest[char_id], spec, male, offsets, out)
        print("built", char_id)


if __name__ == "__main__":
    main()
