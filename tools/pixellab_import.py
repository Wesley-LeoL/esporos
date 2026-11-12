#!/usr/bin/env python3
"""Importa para o jogo uma folha de sprites vinda do PixelLab.

As folhas chegam como imagem com um cabeçalho de texto em cima e fundo opaco azul-escuro.
Este script corta o cabeçalho, deixa o fundo transparente e, para animações de personagem,
completa as 8 direções espelhando as do lado direito.

Animação (linhas = direções s, se, e, ne, n, nessa ordem; colunas = quadros):
    python3 tools/pixellab_import.py anim  entrada.png  andar_homem.png
  Saída: 8 linhas na ordem de gen_hair.DIRS (s, se, e, ne, n, nw, w, sw); nw, w e sw são o
  espelho de ne, e e se.

Rotações (uma linha, 8 direções na ordem do PixelLab ou já na nossa):
    python3 tools/pixellab_import.py folha entrada.png  saida.png
"""
import os
import sys

from PIL import Image, ImageOps

CELL = 64
BG = (31, 37, 44)
DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "art", "pixellab", "personagens")


def clean(path):
    """Tira o cabeçalho (a altura que sobra além de um múltiplo de 64) e o fundo."""
    im = Image.open(path).convert("RGBA")
    extra = im.height % CELL
    im = im.crop((0, extra, im.width - im.width % CELL, im.height))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][:3] == BG:
                px[x, y] = (0, 0, 0, 0)
    return im


def anim(src, dst):
    im = clean(src)
    rows = im.height // CELL
    if rows != 5:
        sys.exit("esperava 5 linhas (s, se, e, ne, n); a folha tem %d" % rows)
    frames = im.width // CELL
    out = Image.new("RGBA", (frames * CELL, 8 * CELL), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    # nw, w, sw = espelho de ne, e, se (quadro a quadro)
    for dst_row, src_row in ((5, 3), (6, 2), (7, 1)):
        for f in range(frames):
            cell = im.crop((f * CELL, src_row * CELL, f * CELL + CELL, src_row * CELL + CELL))
            out.paste(ImageOps.mirror(cell), (f * CELL, dst_row * CELL))
    out.save(dst)
    print("salvo:", dst, out.size, "(%d quadros x 8 direções)" % frames)


def sheet(src, dst):
    im = clean(src)
    im.save(dst)
    print("salvo:", dst, im.size)


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in ("anim", "folha"):
        sys.exit(__doc__)
    out_path = sys.argv[3] if os.path.dirname(sys.argv[3]) else os.path.join(DIR, sys.argv[3])
    (anim if sys.argv[1] == "anim" else sheet)(sys.argv[2], out_path)
