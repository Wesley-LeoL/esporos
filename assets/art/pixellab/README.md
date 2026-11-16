# Arte definitiva (PixelLab)

Arte nova do jogo, feita no PixelLab (tema steampunk). Os **personagens dos jogadores já
usam esta arte** (criação de personagem e jogo); o resto continua com a arte provisória de
`assets/art/generated/` até cada conjunto ficar completo.

**No jogo:** `tools/bake_char_layers.py` grava as folhas prontas em `assets/art/characters/`
(9 colunas: parado + 8 do andar; 8 linhas na ordem do enum Facing) e
`scripts/art/char_art.gd` empilha as camadas. A aparência fica em `SurvivorData.visual`
({sexo, pele, cabelo, cor, barba}), vai no save e na rede como um inteiro (`Player.vis`).
A máscara de gás é uma camada desenhada por script (aparece com a máscara vestida).
Enquanto não houver arte nova, o ataque usa a pose parada com um avanço e a mulher anda
balançando a pose parada.

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
- Braço de pistão, monóculo e lanterna (a arte antiga mostrava; a nova ainda não).

Ids no PixelLab: homem `1a3b3585-a35d-42b3-8d99-a2e044acef46`, mulher (v2)
`ceb1c426-2c54-4f88-8186-6eaecb071ee5`.

## Chão (`chao/`): texturas do mapa

O plano sem assinatura não libera os tiles isométricos "pro". Por isso o chão vem de
**tilesets top-down de 32 px** (`create_topdown_tileset`, modo padrão, 1 geração cada, dois
terrenos por conjunto):

1. `tools/pixellab_tiles.py <tileset_id> <TIPO_DE_BAIXO> <TIPO_DE_CIMA> [ajustes]` baixa o
   conjunto, pega os ladrilhos "cheios" de cada terreno, ajusta as cores para a paleta
   (menos saturação, mais escuro, um pouco de âmbar) e grava `chao/<TIPO>.png`. O conjunto
   inteiro, com as transições, fica em `chao/sets/` (para as bordas entre terrenos depois).
2. `python3 tools/gen_art.py --only ground` projeta as texturas no losango 80x40
   (`gen_ground.texture_tile`: cada losango cobre 2x2 repetições, então não há emenda).
   Faixas, faixa de pedestre e mancha de óleo usam a textura do asfalto com as marcas do
   desenho antigo por cima. Tipo sem textura continua procedural (hoje: AZULEJO e as pontes).

| Conjunto (id) | De baixo | De cima | Ajustes usados |
|---|---|---|---|
| 6e4b7ef7-787d-4061-bc5f-ff80dd7f2bd3 | TERRA | GRAMA | grama: `sat=0.5 val=0.8 quente=0.14` |
| 9de167cd-2546-4df8-974d-f72cf1f83230 | TERRA_BATIDA | GRAMA_SECA | padrão |
| 43989555-604b-4316-9993-267ba3c3317c | ESTRADA | CALCADA | padrão |
| 47b1a10b-bf31-43cf-951d-5365a8b5c6c0 | AGUA | VAU | `hue:b=95 sat:b=0.95 val:b=0.85 quente:b=0 hue:c=90 sat:c=0.75 val:c=1.25 quente:c=0` |
| 882f08be-e740-449b-871c-7b1c5e3a57df | CARPETE | PISO_MADEIRA | `sat=0.75` (o PixelLab trocou os dois) |
| 37c2e32f-ea06-4be9-88ad-fd11c4912ed2 | PISO_CONCRETO | — | o azulejo saiu liso; ficou o procedural |
| e73e0194-ff88-4a86-8e29-e4e680eaa69a | ESPOROS | (GRAMA_ESPOROS) | a grama com esporos é a GRAMA apagada + as manchas do ESPOROS (script no histórico do commit) |
| fb432761-646c-4d42-8040-536777cfc8de | CONC_B | CONC_A | padrão (trocados) |
| 768d2ca0-614f-4543-a102-654bb854ea5f | VILA | PISO | padrão |
| cb8ca219-0fa3-43b4-b607-ca0737007948 | LAVOURA | — | padrão |
