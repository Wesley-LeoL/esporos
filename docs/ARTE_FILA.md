# Fila de arte do PixelLab

Lista do que falta gerar no PixelLab, na ordem. Uma tarefa agendada roda todo dia, gasta
as gerações disponíveis seguindo esta fila, integra no jogo, marca o que foi feito e
envia para o main. Detalhes técnicos de cada tipo de arte: `assets/art/pixellab/README.md`.

**Conta:** plano de teste, sem assinatura. Só há o bônus diário (+5 por noite, acumula até
20). Uma geração por vez (pedir uma direção de animação por chamada). Ferramentas "pro"
(`create_tiles_pro`, `create_building_kit`, `create_path_tiles`, tileset `mode="pro"`)
exigem assinatura e não estão disponíveis.

**Tema:** steampunk (vapor, latão, cobre, madeira escura, fuligem); eletricidade rudimentar.
Cores sóbrias: ajustar saturação e brilho para a paleta do jogo (`scripts/ui/ui_theme.gd`).

Legenda: `[x]` feito · `[ ]` falta · custo em gerações entre parênteses.

## 1. Mapa (prioridade)

### Chão
- [x] Texturas de 19 tipos de chão (10 tilesets top-down) — ver README
- [ ] AZULEJO: piso de azulejo branco com rejunte escuro, padrão quadriculado (1)
- [ ] Transições suaves entre terrenos (grama/terra, estrada/calçada, água/margem): os conjuntos em `assets/art/pixellab/chao/sets/` já têm os 16 ladrilhos de transição; falta o código (dual-grid no mundo). Sem custo.

### Objetos do mapa (`create_map_object`, 1 cada, vista "high top-down", fundo transparente)
Substituem os props da arte provisória (`assets/art/generated/`), mesmo nome de arte.
Tamanho próximo do sprite atual do prop; pé (base) embaixo, no centro.
- [ ] arvore (2 variações): árvore de copa redonda
- [ ] pinheiro
- [ ] arvore_morta: árvore seca, galhos retorcidos, cinza
- [ ] arbusto / moita
- [ ] pedra grande / rochas
- [ ] poste de lampião a gás/elétrico, ferro fundido (substitui poste_rua e poste_neon)
- [ ] barril de madeira com aros de ferro
- [ ] caixote de madeira
- [ ] tambor de fogo (tambor_fogo)
- [ ] carcaça de locomóvel abandonado (carro destruído)
- [ ] hidrante / registro de vapor com válvulas de latão
- [ ] banco de praça de ferro fundido
- [ ] armadilha de espinhos (estacas de madeira)
- [ ] cogumelo gigante de esporos (zona de esporos)

### Construções (sem `create_building_kit`, que exige assinatura)
- [ ] Paredes e telhados: testar `create_map_object` para pedaços de parede de tijolo, madeira e chapa rebitada; se não ficar bom, esperar assinatura.

## 2. Personagens

- [x] Corpos base (homem, mulher), tons de pele, cabelos, barbas
- [x] Andar do homem (5 direções + espelho)
- [ ] Andar da mulher: `animate_character(ceb1c426-2c54-4f88-8186-6eaecb071ee5, template "walking-8-frames", nome "andar")`, direções s, se, e, ne, n (5)
- [ ] Correr (homem e mulher): template "running-8-frames" (10)
- [ ] Parado respirando: "breathing-idle" (10)
- [ ] Atacar: "cross-punch" ou "lead-jab" (10)
- [ ] Levar golpe: "taking-punch" (10)
- [ ] Morrer: "falling-back-death" (10)
- [ ] Agachado andando: "crouched-walking" (10)
- [ ] Roupas como camadas (estudar `create_character_state` + extração por cor)

## 3. Inimigos, NPCs e animais
- [ ] Infectado comum, corredor, brutamonte, explosivo, rastejante, chamador
- [ ] Saqueador, guarda e comerciante de vila
- [ ] Veado, javali e coelho (`create_character` com body_type quadruped, modo standard)

## Registro
- 2026-11-12: corpos base, cabelos, barbas, andar do homem.
- 2026-11-16: 10 tilesets de chão (TERRA, GRAMA, TERRA_BATIDA, GRAMA_SECA, ESTRADA, CALCADA, AGUA, VAU, PISO_MADEIRA, CARPETE, PISO_CONCRETO, ESPOROS, GRAMA_ESPOROS, CONC_A, CONC_B, VILA, PISO, LAVOURA).
