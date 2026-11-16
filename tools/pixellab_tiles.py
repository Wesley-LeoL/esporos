#!/usr/bin/env python3
"""Importa um tileset top-down do PixelLab como textura de chão do jogo.

O PixelLab (plano sem assinatura) gera tilesets top-down de 32 px com dois terrenos. Daqui
saem as duas texturas "cheias" (os ladrilhos com os 4 cantos do mesmo terreno), com as
cores ajustadas para a paleta do jogo (menos saturada, mais escura: steampunk), gravadas
em assets/art/pixellab/chao/<TIPO>.png. O tools/gen_ground.py projeta essas texturas no
losango isométrico 80x40 (ver texture_tile) no lugar do desenho procedural.

    python3 tools/pixellab_tiles.py <tileset_id> <TIPO_DE_BAIXO> <TIPO_DE_CIMA> [ajustes]

Os tipos são os nomes de GROUND_TYPES (TERRA, GRAMA...); "-" pula um terreno. Ajustes, por
terreno (sufixo :b de baixo, :c de cima, ou sem sufixo para os dois):
    sat=0.6   multiplica a saturação     val=0.85  multiplica o brilho
    hue=-10   gira o matiz (graus)       quente=0.1 puxa para o âmbar
O tileset inteiro (com as transições) também fica guardado em chao/sets/ para um dia
fazer as bordas entre terrenos.
"""
import colorsys
import json
import os
import sys
import urllib.request

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "art", "pixellab", "chao")
API = "https://api.pixellab.ai/mcp/tilesets/%s/%s"


def fetch(tid, what):
    url = API % (tid, what) + ("?inline=true" if what == "image" else "")
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read()


def grade(img, sat=0.62, val=0.86, hue=0.0, quente=0.08):
    out = img.copy()
    px = out.load()
    amber = (0.11, 0.5, 0.7)  # matiz, saturação e brilho do âmbar da paleta
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            h = (h + hue / 360.0) % 1.0
            s = min(1.0, s * sat)
            v = min(1.0, v * val)
            rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
            ar, ag, ab = colorsys.hsv_to_rgb(*amber)
            rr = rr * (1 - quente) + ar * v * quente
            gg = gg * (1 - quente) + ag * v * quente
            bb = bb * (1 - quente) + ab * v * quente
            px[x, y] = (round(rr * 255), round(gg * 255), round(bb * 255), a)
    return out


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    tid, low, up = sys.argv[1], sys.argv[2], sys.argv[3]
    adj = {"b": {}, "c": {}}
    for a in sys.argv[4:]:
        k, v = a.split("=")
        side = None
        if ":" in k:
            k, side = k.split(":")
        for sd in ([side] if side else ["b", "c"]):
            adj[sd][k] = float(v)
    os.makedirs(os.path.join(OUT, "sets"), exist_ok=True)
    png = fetch(tid, "image")
    meta = json.loads(fetch(tid, "metadata"))
    with open(os.path.join(OUT, "sets", tid + ".png"), "wb") as f:
        f.write(png)
    with open(os.path.join(OUT, "sets", tid + ".json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    sheet = Image.open(os.path.join(OUT, "sets", tid + ".png")).convert("RGBA")
    full = {}
    for t in meta["tileset_data"]["tiles"]:
        cs = set(t["corners"].values())
        if len(cs) == 1:
            bb = t["bounding_box"]
            full[cs.pop()] = sheet.crop((bb["x"], bb["y"], bb["x"] + bb["width"], bb["y"] + bb["height"]))
    for side, name, key in (("b", low, "lower"), ("c", up, "upper")):
        if name == "-":
            continue
        if key not in full:
            print("sem ladrilho cheio de", key)
            continue
        tex = grade(full[key], **adj[side])
        tex.save(os.path.join(OUT, name + ".png"))
        print("salvo:", name, "<-", meta.get(key + "_description", "")[:70])


if __name__ == "__main__":
    main()
