#!/usr/bin/env python3
"""Camadas de cabelo para os corpos base do PixelLab (personalização do personagem).

Os corpos base (assets/art/pixellab/personagens/corpo_<sexo>.png: 8 direções lado a lado,
64x64 cada, na ordem s, se, e, ne, n, nw, w, sw) são carecas, com o couro cabeludo raspado
num tom acinzentado. Este script acha esse couro cabeludo em cada direção e desenha os
penteados por cima, como camada separada e transparente, em tons de cinza (o jogo tinge
com a cor do cabelo). Para os quadros de animação, use place(): ela desloca a camada da
rotação parada para onde a cabeça está em cada quadro (ver head_anchor).

    python3 tools/gen_hair.py            # gera as folhas em assets/art/pixellab/personagens/
    python3 tools/gen_hair.py --preview caminho.png
"""
import colorsys
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(HERE, "..", "assets", "art", "pixellab", "personagens")
CELL = 64
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
STYLES = ["raspado", "curto", "medio", "longo", "coque", "moicano"]
# tons da camada (cinzas): escuro, médio, claro. O jogo multiplica pela cor do cabelo.
G_DARK, G_MID, G_LIGHT = (96, 96, 96, 255), (168, 168, 168, 255), (232, 232, 232, 255)
OUT = (24, 18, 22, 255)


def is_outline(p):
    return p[3] > 0 and max(p[:3]) < 56


def is_scalp(p):
    """Couro cabeludo raspado: cinza-bege, pouco saturado (a pele é alaranjada)."""
    if p[3] == 0 or is_outline(p):
        return False
    h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
    # tom claro do raspado, ou a sombra dele (mais escura e um pouco mais saturada)
    return (s < 0.42 and 0.45 < v < 0.85) or (s < 0.68 and 0.3 < v < 0.58)


def head_rows(cell):
    """Linha do topo da cabeça e linha do queixo/pescoço (a mais estreita depois da cabeça)."""
    px = cell.load()
    widths = []
    for y in range(CELL):
        xs = [x for x in range(CELL) if px[x, y][3] > 0]
        widths.append((xs[-1] - xs[0] + 1) if xs else 0)
    top = next(y for y in range(CELL) if widths[y] > 0)
    widest = max(range(top, top + 10), key=lambda y: widths[y])
    neck = min(range(widest + 2, widest + 10), key=lambda y: widths[y])
    return top, neck


def scalp_mask(cell):
    px = cell.load()
    top, neck = head_rows(cell)
    m = set()
    # só da linha dos olhos para cima (abaixo disso o cinza é barba por fazer)
    for y in range(top, top + int((neck - top) * 0.62) + 1):
        for x in range(CELL):
            if is_scalp(px[x, y]):
                m.add((x, y))
    # tira pontos soltos (barba por fazer, brilho do olho): fica só o maior bloco ligado
    best = set()
    seen = set()
    for p in m:
        if p in seen:
            continue
        comp, stack = set(), [p]
        while stack:
            q = stack.pop()
            if q in comp or q not in m:
                continue
            comp.add(q)
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                stack.append((q[0] + d[0], q[1] + d[1]))
        seen |= comp
        if len(comp) > len(best):
            best = comp
    return best, top, neck


def head_anchor(cell):
    """Âncora da cabeça num quadro: (x do centro, linha do topo). None se o quadro é vazio.

    Nos quadros de animação o PixelLab redesenha o couro cabeludo com cor de pele, então não
    dá para achar o cabelo pela cor. A cabeça só sobe, desce e desliza (não gira): basta
    achar a âncora e deslocar a camada feita para a rotação parada da mesma direção.
    """
    px = cell.load()
    top = next((y for y in range(CELL) if any(px[x, y][3] > 0 for x in range(CELL))), None)
    if top is None:
        return None
    # largura da cabeça 4 px abaixo do topo, no bloco contínuo que contém o centro do topo
    tx = [x for x in range(CELL) if px[x, top][3] > 0]
    cx = (tx[0] + tx[-1]) // 2
    y = min(CELL - 1, top + 4)
    x0 = cx
    while x0 - 1 >= 0 and px[x0 - 1, y][3] > 0:
        x0 -= 1
    x1 = cx
    while x1 + 1 < CELL and px[x1 + 1, y][3] > 0:
        x1 += 1
    return (x0 + x1) / 2.0, top


def place(layer, base_cell, frame_cell):
    """A camada (feita para base_cell) deslocada para a cabeça de frame_cell."""
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    a, b = head_anchor(base_cell), head_anchor(frame_cell)
    if a is None or b is None:
        return out
    dx = int(round(b[0] - a[0]))
    dy = b[1] - a[1]
    out.paste(layer, (dx, dy))
    return out


def grow(mask, dirs):
    out = set(mask)
    for (x, y) in mask:
        for dx, dy in dirs:
            out.add((x + dx, y + dy))
    return out


def hair_cells(cell, style):
    """Conjunto de pixels do cabelo desse penteado numa direção."""
    px = cell.load()
    scalp, top, neck = scalp_mask(cell)
    if not scalp:
        return set(), scalp
    def body(x, y):
        return 0 <= x < CELL and 0 <= y < CELL and px[x, y][3] > 0
    def skin(x, y):
        return body(x, y) and not is_outline(px[x, y]) and (x, y) not in scalp
    hair = set(scalp)
    if style == "raspado":
        return hair, scalp
    # volume: cresce 1 px para cima e para os lados, cobrindo o contorno da cabeça
    up_side = ((0, -1), (1, 0), (-1, 0))
    hair = grow(hair, up_side)
    hair = {(x, y) for (x, y) in hair if not skin(x, y) or (x, y) in scalp}
    if style == "curto":
        return hair, scalp
    if style == "moicano":
        xs = [x for x, _ in scalp]
        cx = (min(xs) + max(xs)) // 2
        crest = {(x, y) for (x, y) in scalp if abs(x - cx) <= 1}
        ys = [y for _, y in crest]
        for x in (cx - 1, cx, cx + 1):
            for k in range(1, 4):
                crest.add((x, min(ys) - k))
        return crest, scalp
    hair = grow(hair, ((0, -1),))
    if style == "coque":
        ys = [y for _, y in scalp]
        xs = [x for x, y in scalp if y <= min(ys) + 2]
        cx = sum(xs) // len(xs)
        ty = min(ys) - 2
        for dx in range(-2, 3):
            for dy in range(-3, 1):
                if abs(dx) + abs(dy + 1) <= 3:
                    hair.add((cx + dx, ty + dy))
        return hair, scalp
    # médio e longo: cada coluna desce a partir do fim do couro cabeludo, sem cobrir o rosto
    length = (neck - top) // 2 + 1 if style == "medio" else (neck - top) + 5
    cols = {}
    for (x, y) in hair:
        cols[x] = max(cols.get(x, y), y)
    for x, y0 in cols.items():
        for k in range(1, length + 1):
            y = y0 + k
            if skin(x, y) and y < neck:
                break  # rosto: o cabelo para aqui
            hair.add((x, y))
    return hair, scalp


def render(cell, style):
    """Camada (RGBA, cinzas) de um penteado numa direção."""
    layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    hair, scalp = hair_cells(cell, style)
    if not hair:
        return layer
    lp = layer.load()
    ys = [y for _, y in hair]
    y0, y1 = min(ys), max(ys)
    for (x, y) in hair:
        if not (0 <= x < CELL and 0 <= y < CELL):
            continue
        t = (y - y0) / max(1, y1 - y0)
        col = G_LIGHT if t < 0.22 else (G_MID if t < 0.7 else G_DARK)
        if (x + y) % 5 == 0 and col == G_MID:
            col = G_DARK  # fios
        lp[x, y] = col
    if style != "raspado":
        for (x, y) in hair:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in hair and 0 <= q[0] < CELL and 0 <= q[1] < CELL and cell.getpixel(q)[3] == 0:
                    lp[q[0], q[1]] = OUT
    return layer


def tint(layer, rgb):
    out = layer.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p != OUT:
                px[x, y] = (p[0] * rgb[0] // 255, p[1] * rgb[1] // 255, p[2] * rgb[2] // 255, 255)
    return out


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    rows = []
    for sex in ("homem", "mulher"):
        body = Image.open(os.path.join(DIR, "corpo_%s.png" % sex)).convert("RGBA")
        sheet = Image.new("RGBA", (CELL * 8, CELL * len(STYLES)), (0, 0, 0, 0))
        for si, style in enumerate(STYLES):
            for di in range(8):
                cell = body.crop((di * CELL, 0, di * CELL + CELL, CELL))
                sheet.paste(render(cell, style), (di * CELL, si * CELL))
        sheet.save(os.path.join(DIR, "cabelos_%s.png" % sex))
        rows.append((body, sheet))
    print("salvo: cabelos_homem.png, cabelos_mulher.png (%d penteados x 8 direções)" % len(STYLES))
    if preview:
        colors = [(92, 58, 36), (36, 30, 34), (196, 148, 70), (150, 52, 32), (190, 190, 196), (120, 80, 46)]
        show = [0, 1, 2, 4, 6]  # s, se, e, n, w
        W = CELL * len(show) * 2
        H = CELL * (len(STYLES) + 1)
        img = Image.new("RGBA", (W, H), (58, 84, 48, 255))
        for bi, (body, sheet) in enumerate(rows):
            for ci, di in enumerate(show):
                cell = body.crop((di * CELL, 0, di * CELL + CELL, CELL))
                img.alpha_composite(cell, (bi * W // 2 + ci * CELL, 0))
                for si in range(len(STYLES)):
                    lay = sheet.crop((di * CELL, si * CELL, di * CELL + CELL, si * CELL + CELL))
                    pos = (bi * W // 2 + ci * CELL, (si + 1) * CELL)
                    img.alpha_composite(cell, pos)
                    img.alpha_composite(tint(lay, colors[si]), pos)
        img.resize((W * 3, H * 3), Image.NEAREST).save(preview)
        print("prévia:", preview)


if __name__ == "__main__":
    main()
