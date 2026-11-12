#!/usr/bin/env python3
"""Monta personagens por camadas (corpo + tom de pele + barba + cabelo) e gera prévias.

É a mesma montagem que o jogo vai fazer na criação de personagem; aqui serve para conferir
a arte. Usa as folhas de assets/art/pixellab/personagens/.

    python3 tools/gen_char_preview.py saida.gif      # animação de andar, 8 direções
    python3 tools/gen_char_preview.py saida.png      # um quadro de cada direção
"""
import os
import sys

from PIL import Image

import gen_face as gf
import gen_hair as gh

CELL = gh.CELL
BG = (58, 84, 48, 255)
# (sexo, tom de pele, penteado, cor do cabelo, barba)
LOOKS = [
    ("homem", "clara", "curto", (92, 58, 36), None),
    ("homem", "media", "longo", (36, 30, 34), "cheia"),
    ("homem", "morena", "moicano", (150, 52, 32), "bigode"),
    ("homem", "escura", "raspado", (36, 30, 34), "cavanhaque"),
    ("homem", "clara", "coque", (196, 148, 70), "sem"),
    ("homem", "media", "medio", (190, 190, 196), "cheia"),
]


def compose(sex, tone, hair, hair_rgb, beard, frame, di, base_cell):
    """Um quadro montado. frame = quadro do corpo (tom claro); base_cell = rotação parada."""
    out = gf.skin_tone(frame, tone)
    base_toned = gf.skin_tone(base_cell, tone)
    if beard:
        layer = gf.render(base_toned, beard, di)
        if beard != "sem":
            layer = gf.tint_beard(layer, hair_rgb)
        out.alpha_composite(gh.place(layer, base_cell, frame))
    if hair:
        out.alpha_composite(gh.place(gh.tint(gh.render(base_cell, hair), hair_rgb), base_cell, frame))
    return out


def main():
    dst = sys.argv[1]
    sheets = {}
    for sex in ("homem", "mulher"):
        p = os.path.join(gh.DIR, "andar_%s.png" % sex)
        if os.path.exists(p):
            sheets[sex] = (Image.open(os.path.join(gh.DIR, "corpo_%s.png" % sex)).convert("RGBA"), Image.open(p).convert("RGBA"))
    looks = [l for l in LOOKS if l[0] in sheets]
    n_frames = 8
    scale = 3
    frames = []
    for f in range(n_frames):
        img = Image.new("RGBA", (CELL * 8, CELL * len(looks)), BG)
        for li, (sex, tone, hair, rgb, beard) in enumerate(looks):
            body, walk = sheets[sex]
            for di in range(8):
                base = body.crop((di * CELL, 0, di * CELL + CELL, CELL))
                fr = walk.crop((f * CELL, di * CELL, f * CELL + CELL, di * CELL + CELL))
                img.alpha_composite(compose(sex, tone, hair, rgb, beard, fr, di, base), (di * CELL, li * CELL))
        frames.append(img.resize((img.width * scale, img.height * scale), Image.NEAREST).convert("RGB"))
    if dst.endswith(".gif"):
        frames[0].save(dst, save_all=True, append_images=frames[1:], duration=110, loop=0)
    else:
        frames[0].save(dst)
    print("salvo:", dst, frames[0].size)


if __name__ == "__main__":
    main()
