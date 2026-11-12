#!/usr/bin/env python3
"""Animais de caça (arte provisória, vista de lado): veado, javali e coelho.

Gera assets/art/generated/animals/animals.png: uma linha por animal, na ordem de KINDS, e
5 colunas: parado, 3 quadros de andar e a carcaça. Célula de CW x CH px; os pés ficam em
(CW/2, FOOT_Y). Os quadros olham para a direita; o jogo espelha para a esquerda.
A arte definitiva vai substituir esta folha (mesmo tamanho de célula e mesma ordem).

    python3 tools/gen_animals.py
"""
import os

from PIL import Image, ImageDraw

CW, CH = 48, 44
FOOT_Y = 40
KINDS = ["veado", "javali", "coelho"]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "generated", "animals")

OUTLINE = (42, 32, 48, 255)


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def outline(img):
    """Contorno escuro de 1 px em volta de tudo que foi desenhado."""
    px = img.load()
    w, h = img.size
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0 and px[nx, ny] != OUTLINE:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = OUTLINE
    return img


def legs(d, xs, top, offs, color, hoof, w=2):
    """Pernas verticais; offs = deslocamento em x do pé de cada perna (passo)."""
    for x, o in zip(xs, offs):
        mid = (top + FOOT_Y) // 2
        d.rectangle([x, top, x + w - 1, mid], fill=color)
        d.rectangle([x + o, mid, x + o + w - 1, FOOT_Y - 1], fill=color)
        d.rectangle([x + o, FOOT_Y - 1, x + o + w - 1, FOOT_Y], fill=hoof)


def veado(frame):
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, light, dark, hoof = hexc("#9a6b45"), hexc("#c9a274"), hexc("#6b4630"), hexc("#2a2030")
    antler = hexc("#d8c9a8")
    if frame == 4:  # carcaça deitada de lado
        d.ellipse([9, 30, 33, 39], fill=body)
        d.ellipse([12, 34, 30, 39], fill=light)
        for x in (13, 18, 25, 30):
            d.line([x, 38, x + 5, 41], fill=dark, width=2)
        d.polygon([(31, 31), (38, 33), (38, 37), (31, 37)], fill=body)
        d.ellipse([36, 33, 43, 39], fill=body)
        d.point((41, 35), fill=OUTLINE)
        d.line([38, 33, 41, 29], fill=antler)
        d.line([40, 31, 43, 30], fill=antler)
        d.rectangle([7, 32, 9, 34], fill=hexc("#efe6d6"))
        return outline(img)
    bob = 1 if frame in (1, 3) else 0
    offs = {0: (0, 0, 0, 0), 1: (-2, 2, -2, 2), 2: (0, 0, 0, 0), 3: (2, -2, 2, -2)}[frame]
    legs(d, (14, 17, 28, 31), 26 + bob, offs, dark, hoof)
    d.ellipse([11, 16 + bob, 34, 28 + bob], fill=body)
    d.ellipse([14, 22 + bob, 32, 29 + bob], fill=light)
    d.ellipse([11, 16 + bob, 34, 24 + bob], fill=body)
    # pescoço e cabeça
    d.polygon([(29, 18 + bob), (34, 9 + bob), (38, 10 + bob), (35, 22 + bob)], fill=body)
    d.ellipse([33, 6 + bob, 41, 13 + bob], fill=body)
    d.rectangle([40, 9 + bob, 43, 12 + bob], fill=light)
    d.point((43, 10 + bob), fill=OUTLINE)
    d.point((38, 8 + bob), fill=OUTLINE)
    d.polygon([(33, 7 + bob), (31, 3 + bob), (35, 6 + bob)], fill=dark)
    # galhada
    d.line([36, 6 + bob, 37, 1 + bob], fill=antler)
    d.line([37, 3 + bob, 40, 1 + bob], fill=antler)
    d.line([36, 4 + bob, 34, 1 + bob], fill=antler)
    # rabo
    d.rectangle([9, 17 + bob, 11, 20 + bob], fill=hexc("#efe6d6"))
    return outline(img)


def javali(frame):
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, light, dark, hoof = hexc("#5c4a44"), hexc("#7d6a60"), hexc("#3b2e2c"), hexc("#221a20")
    tusk = hexc("#efe6d6")
    if frame == 4:
        d.ellipse([8, 29, 34, 40], fill=body)
        d.ellipse([12, 34, 30, 40], fill=light)
        for x in (13, 18, 25, 29):
            d.line([x, 39, x + 4, 42], fill=dark, width=2)
        d.ellipse([30, 31, 42, 40], fill=body)
        d.rectangle([41, 35, 44, 38], fill=light)
        d.point((42, 34), fill=tusk)
        d.point((38, 34), fill=OUTLINE)
        d.line([10, 29, 30, 28], fill=dark)
        return outline(img)
    bob = 1 if frame in (1, 3) else 0
    offs = {0: (0, 0, 0, 0), 1: (-1, 2, -2, 1), 2: (0, 0, 0, 0), 3: (2, -1, 1, -2)}[frame]
    legs(d, (13, 16, 28, 31), 31 + bob, offs, dark, hoof)
    d.ellipse([9, 19 + bob, 36, 34 + bob], fill=body)
    d.ellipse([13, 28 + bob, 32, 35 + bob], fill=light)
    d.ellipse([9, 19 + bob, 36, 30 + bob], fill=body)
    # crina no dorso
    d.line([13, 19 + bob, 30, 18 + bob], fill=dark, width=2)
    for x in range(14, 30, 3):
        d.point((x, 17 + bob), fill=dark)
    # cabeça baixa, focinho e presa
    d.ellipse([30, 21 + bob, 42, 33 + bob], fill=body)
    d.rectangle([41, 27 + bob, 45, 31 + bob], fill=light)
    d.point((45, 29 + bob), fill=OUTLINE)
    d.line([41, 27 + bob, 42, 24 + bob], fill=tusk)
    d.point((38, 25 + bob), fill=OUTLINE)
    d.polygon([(33, 21 + bob), (32, 17 + bob), (36, 20 + bob)], fill=dark)
    # rabo
    d.line([8, 24 + bob, 6, 27 + bob], fill=dark)
    return outline(img)


def coelho(frame):
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, light, dark = hexc("#a39384"), hexc("#d2c6b6"), hexc("#75675c")
    if frame == 4:
        d.ellipse([16, 34, 30, 40], fill=body)
        d.ellipse([19, 37, 28, 40], fill=light)
        d.ellipse([28, 34, 35, 40], fill=body)
        d.line([33, 35, 38, 34], fill=dark, width=2)
        d.rectangle([14, 36, 16, 38], fill=hexc("#f2ece0"))
        d.point((32, 37), fill=OUTLINE)
        return outline(img)
    hop = {0: 0, 1: 2, 2: 4, 3: 2}[frame]
    y = -hop
    # patas: encolhidas parado, esticadas no salto
    if frame == 0:
        d.rectangle([18, 37, 23, 40], fill=dark)
        d.rectangle([28, 38, 30, 40], fill=dark)
    else:
        d.line([18, 36 + y, 14, 40 + y], fill=dark, width=2)
        d.line([29, 37 + y, 33, 40 + y], fill=dark, width=2)
    d.ellipse([16, 29 + y, 30, 39 + y], fill=body)
    d.ellipse([19, 34 + y, 28, 39 + y], fill=light)
    d.ellipse([16, 29 + y, 30, 36 + y], fill=body)
    d.ellipse([27, 26 + y, 35, 34 + y], fill=body)
    d.point((33, 29 + y), fill=OUTLINE)
    d.point((35, 31 + y), fill=hexc("#d98a8a"))
    # orelhas
    d.line([29, 26 + y, 28, 19 + y], fill=body, width=2)
    d.line([31, 26 + y, 32, 19 + y], fill=dark, width=2)
    # rabo
    d.rectangle([14, 32 + y, 16, 34 + y], fill=hexc("#f2ece0"))
    return outline(img)


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (CW * 5, CH * len(KINDS)), (0, 0, 0, 0))
    for r, fn in enumerate((veado, javali, coelho)):
        for f in range(5):
            sheet.paste(fn(f), (f * CW, r * CH))
    path = os.path.join(OUT, "animals.png")
    sheet.save(path)
    print("salvo:", os.path.normpath(path), sheet.size)


if __name__ == "__main__":
    main()
