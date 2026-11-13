#!/usr/bin/env python3
"""Prepara as camadas do personagem (arte do PixelLab) no formato que o jogo usa.

Lê assets/art/pixellab/personagens/ e grava em assets/art/characters/ folhas de 64x64 com
9 colunas (0 = parado, 1-8 = andar) e 8 linhas na ordem do enum Facing do jogo
(E, SE, S, SW, W, NW, N, NE). O pé fica em (32, 62). As camadas de cabelo, barba e máscara
já vêm deslocadas para a cabeça de cada quadro, então o jogo só empilha:

  corpo_<sexo>_<tom>.png        corpo no tom de pele
  barba_<estilo>_<tom>.png      remendo de pele que apaga a barba por fazer (não se tinge)
  barba_<estilo>.png            pelos da barba em cinza (o jogo tinge com a cor do cabelo)
  cabelo_<sexo>_<estilo>.png    cabelo em cinza (tingido)
  mascara_<sexo>.png            máscara de gás (aparece quando o personagem usa uma)

A mulher ainda não tem andar do PixelLab: o andar dela é a pose parada balançando 1 px.

    python3 tools/bake_char_layers.py
"""
import os

from PIL import Image

import gen_face as gf
import gen_hair as gh

CELL = 64
SRC = gh.DIR
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "art", "characters")
# linha do jogo (Facing E, SE, S, SW, W, NW, N, NE) -> índice em gh.DIRS (s, se, e, ne, n, nw, w, sw)
GAME_ROWS = [gh.DIRS.index(d) for d in ("e", "se", "s", "sw", "w", "nw", "n", "ne")]
WALK = 8
BOB = [0, 1, 1, 0, 0, 1, 1, 0]
BEARDS = [b for b in gf.BARBAS if b != "sem"] + ["sem"]

MASK_DARK = (44, 36, 34, 255)
MASK_MID = (78, 62, 52, 255)
BRASS = (196, 150, 72, 255)
BRASS_D = (128, 92, 44, 255)
GLASS = (126, 168, 150, 255)


def frames_for(sex):
    """[di][col] = quadro do corpo no tom claro; col 0 = parado."""
    body = Image.open(os.path.join(SRC, "corpo_%s.png" % sex)).convert("RGBA")
    walk_p = os.path.join(SRC, "andar_%s.png" % sex)
    walk = Image.open(walk_p).convert("RGBA") if os.path.exists(walk_p) else None
    out = []
    for di in range(8):
        base = body.crop((di * CELL, 0, di * CELL + CELL, CELL))
        row = [base]
        for f in range(WALK):
            if walk is not None:
                row.append(walk.crop((f * CELL, di * CELL, f * CELL + CELL, di * CELL + CELL)))
            else:
                fr = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
                fr.paste(base, (0, -BOB[f]))
                row.append(fr)
        out.append(row)
    return out


def mask_layer(cell, di):
    """Máscara de gás: couro na metade de baixo do rosto e um filtro de latão na frente."""
    layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    box = gf.face_box(cell, di)
    px = cell.load()
    lp = layer.load()
    top = next((y for y in range(CELL) if any(px[x, y][3] > 0 for x in range(CELL))), None)
    if top is None:
        return layer
    if box is None:
        # de costas: só a tira da máscara atravessando a nuca
        y = top + 8
        xs = [x for x in range(CELL) if px[x, y][3] > 0 and not gh.is_outline(px[x, y])]
        if xs:
            head = [x for x in xs if abs(x - (xs[0] + xs[-1]) / 2.0) <= 6]
            for x in head:
                lp[x, y] = MASK_DARK
        return layer
    y0, x0, x1, mid = box
    for y in range(y0 - 2, y0 + 3):
        for x in range(x0, x1 + 1):
            if px[x, y][3] > 0 and not gh.is_outline(px[x, y]):
                lp[x, y] = MASK_MID if y < y0 + 2 else MASK_DARK
    # óculos redondos (linha dos olhos) e filtro de latão
    eye = y0 - 3
    for x in range(x0, x1 + 1):
        if px[x, eye][3] > 0 and not gh.is_outline(px[x, eye]):
            lp[x, eye] = GLASS if abs(x - mid) >= 1.0 else MASK_DARK
    fx = int(round(mid))
    for dx, dy, c in ((0, 0, BRASS), (-1, 0, BRASS_D), (1, 0, BRASS_D), (0, 1, BRASS_D), (0, -1, BRASS)):
        x, y = fx + dx, y0 + 1 + dy
        if x0 - 1 <= x <= x1 + 1 and 0 <= y < CELL:
            lp[x, y] = c
    return layer


def split_beard(layer):
    """(remendo de pele, pelos em cinza)."""
    skin = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    hair = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    lp, sp, hp = layer.load(), skin.load(), hair.load()
    for y in range(layer.height):
        for x in range(layer.width):
            p = lp[x, y]
            if p[3] == 0:
                continue
            if p[0] == p[1] == p[2]:
                hp[x, y] = p
            else:
                sp[x, y] = p
    return skin, hair


def sheet(fn):
    img = Image.new("RGBA", (CELL * (WALK + 1), CELL * 8), (0, 0, 0, 0))
    for row, di in enumerate(GAME_ROWS):
        for col in range(WALK + 1):
            img.paste(fn(di, col), (col * CELL, row * CELL))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for sex in ("homem", "mulher"):
        fr = frames_for(sex)
        for tone in gf.TONS:
            sheet(lambda di, c: gf.skin_tone(fr[di][c], tone)).save(os.path.join(OUT, "corpo_%s_%s.png" % (sex, tone)))
            n += 1
        for style in gh.STYLES:
            hair = [gh.render(fr[di][0], style) for di in range(8)]
            sheet(lambda di, c: gh.place(hair[di], fr[di][0], fr[di][c])).save(os.path.join(OUT, "cabelo_%s_%s.png" % (sex, style)))
            n += 1
        masks = [mask_layer(fr[di][0], di) for di in range(8)]
        sheet(lambda di, c: gh.place(masks[di], fr[di][0], fr[di][c])).save(os.path.join(OUT, "mascara_%s.png" % sex))
        n += 1
        if sex != "homem":
            continue
        for style in BEARDS:
            for tone in gf.TONS:
                parts = [split_beard(gf.render(gf.skin_tone(fr[di][0], tone), style, di)) for di in range(8)]
                sheet(lambda di, c: gh.place(parts[di][0], fr[di][0], fr[di][c])).save(os.path.join(OUT, "barba_%s_%s.png" % (style, tone)))
                n += 1
                if tone == "clara" and style != "sem":
                    sheet(lambda di, c: gh.place(parts[di][1], fr[di][0], fr[di][c])).save(os.path.join(OUT, "barba_%s.png" % style))
                    n += 1
    print("salvo: %d folhas em %s" % (n, os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
