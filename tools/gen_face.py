#!/usr/bin/env python3
"""Rostos para os corpos base do PixelLab: tons de pele e barbas (personalização).

Numa cabeça de ~10 px de largura, o que diferencia um rosto é o tom da pele e os pelos do
rosto. Este script gera, a partir de corpo_<sexo>.png (8 direções de 64x64 lado a lado):

  - corpo_<sexo>_<tom>.png   o corpo com a pele recolorida (TONS; "clara" é o original)
  - barbas_homem.png         camadas de barba, uma linha por estilo de BARBAS x 8 direções:
                               "sem"        remendo de pele que cobre a barba por fazer do
                                            corpo base (não se tinge; segue o tom da pele:
                                            barbas_homem_<tom>.png)
                               as outras    em tons de cinza; o jogo tinge com a cor do cabelo
    O corpo base do homem já vem com barba por fazer ("rala" = não pôr camada nenhuma).
    As barbas são desenhadas pela geometria do rosto (linhas contadas a partir do topo da
    cabeça e o lado para onde o rosto olha em cada direção).

Como o gen_hair.py, acha as regiões pela cor em cada quadro, então serve para os quadros
de animação também.

    python3 tools/gen_face.py [--preview caminho.png]
"""
import colorsys
import os
import sys

from PIL import Image

import gen_hair as gh

DIR = gh.DIR
CELL = gh.CELL
# tom: (multiplicador de matiz em graus, saturação x, valor x)
TONS = {
    "clara": None,
    "media": (-2.0, 1.08, 0.86),
    "morena": (-4.0, 1.12, 0.68),
    "escura": (-6.0, 1.05, 0.5),
}
BARBAS = ["sem", "cheia", "bigode", "cavanhaque"]


def hsv(p):
    return colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)


def is_skin(p):
    """Pele: laranja-rosada. A calça é marrom mais amarelada e escura; a camiseta é creme."""
    if p[3] == 0 or gh.is_outline(p):
        return False
    h, s, v = hsv(p)
    deg = h * 360.0
    if deg > 300.0:
        deg -= 360.0
    if s < 0.3:
        return False  # camiseta, couro cabeludo raspado
    if -10.0 <= deg <= 27.5 and v >= 0.5:
        return True
    return -10.0 <= deg <= 19.0 and v >= 0.36  # sombra avermelhada da pele


def skin_tone(img, tone):
    """Cópia da imagem com a pele no tom pedido."""
    spec = TONS[tone]
    out = img.copy()
    if spec is None:
        return out
    dh, ks, kv = spec
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if not is_skin(p):
                continue
            h, s, v = hsv(p)
            # os tons escuros perdem menos nas luzes, para o volume continuar legível
            v2 = v * (kv + (1.0 - kv) * 0.25 * v)
            r, g, b = colorsys.hsv_to_rgb((h + dh / 360.0) % 1.0, min(1.0, s * ks), v2)
            px[x, y] = (round(r * 255), round(g * 255), round(b * 255), p[3])
    return out


# Lado para onde o rosto olha em cada direção (ordem de gen_hair.DIRS): 0 = de frente,
# +1 = para a direita, -1 = para a esquerda, None = de costas (sem barba visível).
FACING = {"s": (0, 1.0), "se": (1, 0.7), "e": (1, 0.5), "ne": None, "n": None, "nw": None, "w": (-1, 0.5), "sw": (-1, 0.7)}


def face_box(cell, di):
    """Geometria da parte de baixo do rosto: (linha do bigode, x inicial, x final, centro).

    A cabeça tem sempre a mesma altura no sprite (13 px): a linha do nariz/bigode fica 10 px
    abaixo do topo, a boca 11 e o queixo 12. A largura vem da linha dos olhos.
    """
    px = cell.load()
    face = FACING[gh.DIRS[di]]
    if face is None:
        return None
    top = next((y for y in range(CELL) if any(px[x, y][3] > 0 for x in range(CELL))), None)
    if top is None:
        return None
    eye = top + 8
    xs = [x for x in range(CELL) if px[x, eye][3] > 0]
    if not xs:
        return None
    # só o bloco da cabeça (o primeiro trecho contínuo a partir do centro do topo)
    tx = [x for x in range(CELL) if px[x, top][3] > 0]
    cx = (tx[0] + tx[-1]) // 2
    x0 = cx
    while x0 - 1 >= 0 and px[x0 - 1, eye][3] > 0:
        x0 -= 1
    x1 = cx
    while x1 + 1 < CELL and px[x1 + 1, eye][3] > 0:
        x1 += 1
    side, frac = face
    x0, x1 = x0 + 1, x1 - 1  # sem o contorno
    w = x1 - x0 + 1
    if side > 0:
        x0 = x1 - round(w * frac) + 1
    elif side < 0:
        x1 = x0 + round(w * frac) - 1
    mid = (x0 + x1) / 2.0 + side * (x1 - x0) * (0.0 if frac == 1.0 else 0.2)
    return top + 10, x0, x1, mid


def beard_cells(cell, di, style):
    """(pixels da barba, pixels a remendar com pele)."""
    px = cell.load()
    box = face_box(cell, di)
    if box is None:
        return set(), set()
    y0, x0, x1, mid = box

    def face(x, y):
        return 0 <= x < CELL and 0 <= y < CELL and px[x, y][3] > 0 and not gh.is_outline(px[x, y])

    lower = {(x, y) for y in range(y0, y0 + 3) for x in range(x0, x1 + 1) if face(x, y)}
    # barba por fazer do corpo base: pixels acinzentados e escuros nessa região
    stub = set()
    for (x, y) in lower | {(x, y0 + 3) for x in range(x0, x1 + 1) if face(x, y0 + 3)}:
        h, s, v = hsv(px[x, y])
        if s < 0.46 and v < 0.7:
            stub.add((x, y))
    if style == "sem":
        return set(), stub
    if style == "cheia":
        keep = {(x, y) for (x, y) in lower if not (y == y0 and abs(x - mid) < 0.6)}
    elif style == "bigode":
        keep = {(x, y) for (x, y) in lower if y == y0 and abs(x - mid) <= 2.2}
        # pontas caídas (bigode de guidão)
        keep |= {(x, y) for (x, y) in lower if y == y0 + 1 and 1.6 <= abs(x - mid) <= 2.6}
    else:  # cavanhaque
        keep = {(x, y) for (x, y) in lower if y >= y0 + 1 and abs(x - mid) <= 1.2}
    return keep, stub - keep


def near_skin(cell, x, y):
    """Cor de pele mais perto de (x, y), para o remendo que tira a barba."""
    px = cell.load()
    for r in range(1, 5):
        best = None
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r:
                    continue
                q = (x + dx, y + dy)
                if 0 <= q[0] < CELL and 0 <= q[1] < CELL and is_skin(px[q[0], q[1]]):
                    p = px[q[0], q[1]]
                    # prefere a pele de cima (bochecha), não a do pescoço em sombra
                    if best is None or (dy < 0 and best[1] >= 0):
                        best = (p, dy)
        if best:
            return best[0]
    return None


def render(cell, style, di):
    layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    keep, patch = beard_cells(cell, di, style)
    lp = layer.load()
    for (x, y) in patch:
        c = near_skin(cell, x, y)
        if c:
            lp[x, y] = c
    if keep:
        y1 = max(y for _, y in keep)
        for (x, y) in keep:
            lp[x, y] = gh.G_DARK if (y == y1 and style != "bigode") else gh.G_MID
    return layer


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    bodies = {}
    for sex in ("homem", "mulher"):
        body = Image.open(os.path.join(DIR, "corpo_%s.png" % sex)).convert("RGBA")
        for tone in TONS:
            img = skin_tone(body, tone)
            bodies[(sex, tone)] = img
            if tone != "clara":
                img.save(os.path.join(DIR, "corpo_%s_%s.png" % (sex, tone)))
    # barbas: só o corpo do homem tem barba por fazer para servir de guia
    beards = {}
    for tone in TONS:
        body = bodies[("homem", tone)]
        sheet = Image.new("RGBA", (CELL * 8, CELL * len(BARBAS)), (0, 0, 0, 0))
        for si, style in enumerate(BARBAS):
            for di in range(8):
                cell = body.crop((di * CELL, 0, di * CELL + CELL, CELL))
                sheet.paste(render(cell, style, di), (di * CELL, si * CELL))
        beards[tone] = sheet
        sheet.save(os.path.join(DIR, "barbas_homem%s.png" % ("" if tone == "clara" else "_" + tone)))
    print("salvo: corpos em %d tons e barbas_homem*.png (%d estilos x 8 direções)" % (len(TONS), len(BARBAS)))
    if preview:
        show = [0, 1, 2, 4, 7]
        box = (26, 34)
        tones = list(TONS)
        W = box[0] * len(show)
        img = Image.new("RGBA", (W * 2 + 6, box[1] * (len(tones) + len(BARBAS) + 1)), (58, 84, 48, 255))
        hair_col = (70, 44, 30)

        def head(body, di, extra=None):
            cell = body.crop((di * CELL, 0, di * CELL + CELL, CELL))
            if extra is not None:
                cell = cell.copy()
                cell.alpha_composite(extra.crop((di * CELL, 0, di * CELL + CELL, CELL)))
            bb = cell.getbbox()
            cx = (bb[0] + bb[2]) // 2
            return cell.crop((cx - 13, bb[1] - 2, cx + 13, bb[1] + 32))

        for ti, tone in enumerate(tones):
            for si, sex in enumerate(("homem", "mulher")):
                for ci, di in enumerate(show):
                    img.alpha_composite(head(bodies[(sex, tone)], di), (si * (W + 6) + ci * box[0], ti * box[1]))
        # barbas no tom claro (esquerda) e moreno (direita); primeira linha = rala (sem camada)
        for bi, tone in enumerate(("clara", "morena")):
            body = bodies[("homem", tone)]
            for ci, di in enumerate(show):
                img.alpha_composite(head(body, di), (bi * (W + 6) + ci * box[0], len(tones) * box[1]))
            for si in range(len(BARBAS)):
                row = beards[tone].crop((0, si * CELL, CELL * 8, si * CELL + CELL))
                if BARBAS[si] != "sem":
                    row = tint_beard(row, hair_col)
                for ci, di in enumerate(show):
                    img.alpha_composite(head(body, di, row), (bi * (W + 6) + ci * box[0], (len(tones) + 1 + si) * box[1]))
        img.resize((img.width * 5, img.height * 5), Image.NEAREST).save(preview)
        print("prévia:", preview)


def tint_beard(layer, rgb):
    """Tinge só os cinzas da camada (o remendo de pele fica como está)."""
    out = layer.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[0] == p[1] == p[2]:
                px[x, y] = (p[0] * rgb[0] // 255, p[1] * rgb[1] // 255, p[2] * rgb[2] // 255, 255)
    return out


if __name__ == "__main__":
    main()
