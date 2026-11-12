# Arte definitiva (PixelLab)

Arte nova do jogo, feita no PixelLab (tema steampunk). Ainda **não está ligada ao jogo**: o
jogo continua usando a arte provisória de `assets/art/generated/` até cada conjunto ficar
completo.

## Personagens (`personagens/`): sistema de camadas

O personagem é montado por camadas, na ordem: corpo → barba → cabelo (→ roupas, depois).
Sprites de 64x64, 8 direções na ordem `s, se, e, ne, n, nw, w, sw`.

| Arquivo | O que é | De onde vem |
|---|---|---|
| `corpo_homem.png`, `corpo_mulher.png` | Corpo base parado, careca, de regata e calça: 8 direções lado a lado | PixelLab |
| `corpo_<sexo>_<tom>.png` | O mesmo corpo em outro tom de pele (`media`, `morena`, `escura`; o original é a `clara`) | `tools/gen_face.py` |
| `cabelos_<sexo>.png` | 6 penteados (linhas: raspado, curto, medio, longo, coque, moicano) x 8 direções, em cinza: o jogo tinge com a cor do cabelo | `tools/gen_hair.py` |
| `barbas_homem[_<tom>].png` | 4 barbas (linhas: sem, cheia, bigode, cavanhaque) x 8 direções. "sem" é um remendo de pele (por isso existe uma folha por tom); as outras são cinza e se tingem como o cabelo. O corpo base já tem barba por fazer | `tools/gen_face.py` |
| `andar_homem.png` | Andar: 8 quadros (colunas) x 8 direções (linhas). `nw`, `w` e `sw` são o espelho de `ne`, `e` e `se` | PixelLab + `tools/pixellab_import.py` |

- **Camadas nos quadros de animação:** cabelo e barba são feitos para a pose parada e
  deslocados para onde a cabeça está em cada quadro (`gen_hair.place`).
- **Prévia:** `python3 tools/gen_char_preview.py saida.gif` monta alguns personagens andando.
- **Importar do PixelLab:** as folhas chegam com cabeçalho e fundo opaco;
  `tools/pixellab_import.py` limpa e espelha as direções.

## Falta

- Andar da mulher; correr, parado respirando, agachado, atacar, levar golpe e morrer dos dois.
- Roupas e equipamentos como camadas.
- Ligar tudo na criação de personagem e no jogo.

Ids no PixelLab: homem `1a3b3585-a35d-42b3-8d99-a2e044acef46`, mulher (v2)
`ceb1c426-2c54-4f88-8186-6eaecb071ee5`.
