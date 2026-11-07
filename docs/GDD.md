# GDD & Contexto de Desenvolvimento: Projeto Esporos (Godot 4 - Multiplayer Co-op Tático)

**Papel da IA:** Arquiteto de Software, Game Designer Sênior e Engenheiro especialista em Godot Engine. Você vai me orientar passo a passo no desenvolvimento de um jogo de sobrevivência tática complexo em **multiplayer cooperativo**, ajudando a escrever scripts (GDScript, RPCs, sincronização de estado), criar a arquitetura de cenas, implementar mecânicas de rede e gerenciar o repositório do projeto.

---

## 0. Instruções de Setup Inicial (Instalação, Godot & Git Multiplayer)
Antes de iniciarmos a lógica, preciso que você me oriente a:
1. **Instalar a Godot Engine 4** (versão estável mais recomendada).
2. **Configurar o Repositório Git:** Criar a pasta do projeto vinculada ao repositório **`esporos`** no GitHub, com um `.gitignore` otimizado para Godot.
3. **Arquitetura de Rede Inicial (Multiplayer Peer-to-Peer / Server-Client):** Definir a estrutura básica de conexões usando o sistema nativo de `ENetMultiplayerPeer` da Godot 4 para suportar sessões cooperativas.

---

## 1. Visão Geral, Estilo Visual e Multiplayer
* **Engine:** Godot Engine 4.
* **Perspectiva / Estilo:** **Pixel Art 2D Isométrico puro** (cenários e personagens).
* **Movimentação do Personagem:** 2D Isométrica com movimentação e sprites em **8 direções** (Norte, Sul, Leste, Oeste, Nordeste, Noroeste, Sudeste, Sudoeste).
* **Estrutura Multiplayer Co-op:**
  * Foco em **sobrevivência cooperativa online** (Joga-se em equipe para fortificar bases, caçar suprimentos e realizar cirurgias uns nos outros).
  * Sincronização de estado rigorosa (posição, animações em 8 direções, inventários, ações de crafting e estado de infecção via RPCs e MultiplayerSynchronizer).

---

## 2. Premissa Narrativa e Ambientação
* **Cenário:** Mundo **steampunk** (era do vapor, latão, engrenagens e fuligem) com a atmosfera corrompida por esporos fúngicos tóxicos. A **eletricidade existe, mas é rudimentar e experimental**: lâmpadas incandescentes, lanternas a pilha seca, dínamos movidos a vapor ou a vento e células galvânicas. Glossário completo do tema na seção "Tema steampunk (fase 23)".
* **A Infecção Latente ("Carga Patogênica"):** Todos carregam o patógeno (0% a 100%). Gerenciada por máscaras de gás, troca de filtros, supressores e purificadores.
* **O Limite do Mundo ("O Mar de Esporos"):** Raiz procedural com raio de borda vasto e expandido. Perto do perímetro extremo, a concentração de esporos torna-se letal instantaneamente, destruindo filtros e gerando hordas infinitas.

---

## 3. Sistemas de Sobrevivência, Metabolismo e Medicina
* **Metabolismo Direto:** 
  * **Fome:** Necessidade de ingestão calórica para manter a estamina e a regeneração.
  * **Sede:** Água limpa vs. Água contaminada. Beber água de poças/fontes não tratadas acelera perigosamente a carga patogênica.
* **Medicina por Membros (Cooperativa):** 
  * Ferimentos localizados que exigem desinfecção, bandagens e antibióticos; ossos torcidos ou quebrados (quedas) pedem tala.
  * *Mecânica Co-op:* Um jogador pode realizar cirurgias de campo ou aplicar curativos em um aliado ferido, exigindo tempo estático e gerando vulnerabilidade para la dupla.

---

## 4. O Sistema de Próteses e o Regulador Craniano
* **O Dilema das Próteses:** Próteses mecânicas (fole pulmonar de latão, monóculo analítico, braço de pistão, pernas pneumáticas, placas subcutâneas) melhoram capacidades, mas gastam a carga de células galvânicas, superaquecem e geram tensão nervosa.
* **A Regra de Ouro: O Regulador Craniano:**
  * **Capacidade Base:** Sem regulador, o corpo suporta **apenas 1 prótese geral**. Instalar mais causa rejeição imediata.
  * **O Regulador Craniano (Mk I e Mk II):** Mecanismo de engrenagens no crânio que aumenta o limite de próteses gerais.
  * **Colapso Nervoso (O Limite do Corpo):**
    * Se o jogador ultrapassar o limite (regulador danificado, célula esgotada ou regulador removido), vem o colapso nervoso.
    * **Efeitos:** espasmos musculares, controle atrasado e desviado, visão turva e incapacidade temporária de mirar ou realizar ações complexas.

---

## 5. Sistema de Inventário, Equipamentos e Itens (Estilo Zomboid)
* **Arquitetura de Inventário Baseada em Peso e Volume:** Mochilas, bolsos, coldres e rigidez de capacidade de carga.
* **Categorias de Itens Essenciais no Mundo:**
  * **Ferramentas e Utilitários:** Chaves de fenda, martelos, serras, alicates, lanternas (com pilhas gastáveis), fitas adesivas (*Duct Tape*) para reparos de improviso.
  * **Recursos de Construção e Sucata:** Chapas de metal, tábuas de madeira, pregos, fios elétricos, sucatas eletrônicas e galões de combustível.
  * **Sobrevivência e Proteção Respiratória:** Máscaras de gás (com durabilidade de vedação), filtros de carvão ativado (descartáveis), galões de água limpa e cantis.
  * **Suprimentos Médicos:** Bandagens esterilizadas, gaze, talas, desinfetantes (álcool/iodo), antibióticos de uso restrito e analgésicos.
  * **Alimentação:** Comidas enlatadas (exigem abridor de latas ou faca), alimentos perecíveis que estragam no inventário com o tempo, sementes e ferramentas agrícolas.
  * **Armas e Munições:** Armas brancas improvisadas (com degradação e risco de quebrar no meio do combate), armas de fogo e caixas de munição específica.

---

## 6. Sistema de Criação de Personagem e Árvore de Habilidades

### 6.1. Criação de Personagem por Pontos
* Sistema inicial onde o jogador gasta uma quantidade fixa de **Pontos de Personagem** para moldar seu sobrevivente, investindo em atributos, perícias iniciais ou escolhendo traços/defeitos que ajustam o saldo de pontos.

### 6.2. Árvore Completa de Habilidades (Progressão por Uso)
* **A. Combate e Sobrevivência Física:**
  * *Luta Corpo a Corpo (CQC / Lâminas e Contundentes):* Afeta dano, consumo de estamina e durabilidade de armas brancas.
  * *Pontaria:* Reduz dispersão, acelera recarga e minimiza o ruído de armas de fogo.
  * *Atletismo e Agilidade:* Melhora fôlego, velocidade e tolerância a peso de carga.
  * *Furtividade:* Reduz raio sonoro de passos e aumenta camuflagem em áreas escuras.
* **B. Engenharia, Técnica e Ofício (Crafting):**
  * *Mecânica:* Reparo e customização de veículos, capacidade de fazer *hotwire*.
  * *Eletricidade:* Dínamos, fiação de cobre, lâmpadas, torres de engrenagens e células galvânicas (tecnologia ainda experimental).
  * *Carpintaria e Construção:* Paredes, barricadas, pisos e estruturas de base.
  * *Metalurgia e Soldagem:* Blindagens pesadas em metal e portões industriais.
* **C. Suporte, Ciência e Biologia:**
  * *Medicina e Primeiros Socorros:* Eficácia de bandagens, talas e cirurgias de campo.
  * *Próteses:* Instalar e manter próteses mecânicas; reduz a tensão nervosa e a rejeição.
  * *Agricultura e Botânica:* Cultivo de alimentos e identificação de plantas.
  * *Culinária:* Reduz intoxicação e garante bônus temporários de estamina.

---

## 7. O Sistema de Morte Definitiva ("Legado") e Co-op
* **Perma-death Real:** Ao morrer, o sobrevivente perece e o jogador renasce com um novo personagem em uma zona segura.
* **O Destino do Ex-Personagem:**
  * *Morte por Infecção (100%):* O corpo reanima como um **Infectado de Elite**, mantendo todo o loot e as próteses antigas, rondando a área para atormentar a equipe.
  * *Morte Física:* Vira um cadáver estático que atrai hordas, servindo como um baú recuperável se a equipe conseguir limpar a área.

---

## 8. Mundo Procedural, Assentamentos Vivos e Base-Building Cooperativo
* **Geração de Mundo Aleatória e Vasta (FastNoiseLite):** 
  * O mapa é gerado proceduralmente com um raio de borda amplo e expandido, garantindo longas distâncias para exploração.
  * **Dualidade do Mundo:** Contém tanto **estruturas abandonadas e ruínas** focadas puramente em looting e perigo, quanto **vilas e acampamentos ainda vivos** habitados por outros NPCs sobreviventes.
* **Ecologia Dinâmica e Evolução dos Assentamentos (O Mundo Vivo):**
  * O mundo simula o tempo e eventos em segundo plano. As vilas vivas não são estáticas: elas podem **evoluir, expandir o comércio e fortificar defesas** caso recebam ajuda do jogador (levando suprimentos, limpando zumbis ao redor ou consertando geradores), OU podem **decair, ser invadidas por hordas e ser tomadas por esporos**, virando zonas mortas e hostiles caso o jogador ignore seus pedidos de socorro ou escolha deixá-las à própria sorte.
* **Base-Building Modular:** Construção livre de paredes, pisos, geradores e sistemas de purificação de ar centralizados para a base usando `TileMap` isométrico.
* **Persistência em Rede:** Salvamento de deltas no mundo para garantir que as alterações feitas por qualquer jogador da sessão persistam corretamente no servidor.

---

## Decisões registradas (28/10/2026)

- **Modelo de rede:** um jogador hospeda e é a autoridade (servidor ENet, porta 7777). Os outros entram pelo IP. O jogo solo usa o mesmo código, numa sessão local sem rede.
- **Jogadores por sessão:** de 2 a 4.
- **Veículos:** entram no escopo (habilidade Mecânica: reparo e ligação direta). Modelos escolhidos na fase 8: locomóvel blindado a vapor e triciclo elétrico experimental (detalhes abaixo).
- **Matemática/Lógica:** sai da árvore de habilidades. Os requisitos de construção que a usavam passam para Eletricidade, Carpintaria e Metalurgia (fase 3).

### Inventário (fase 2)

- **Recipientes:** bolsos (4 L, sempre), mochila vestida (escolar 14 L; trilha 24 L, conteúdo pesa 25% menos; militar 34 L, 40% menos) e coldre de cinto (só armas, 2 L). Itens recebidos procuram espaço nessa ordem: coldre, mochila, bolsos. O que não cabe cai no chão num saco.
- **Peso:** acima da carga confortável o personagem fica lento (até -45%); o limite depende de Força e Atletismo (fase 3).
- **Estado por item:** armas e máscara têm durabilidade (a máscara vaza mais com a vedação baixa e perde vedação com golpes na cabeça; armas gastam a cada golpe que acerta e quebram). Perecíveis guardam o instante em que estragam no relógio do mundo: fresco, passado (75% das calorias) e estragado (40% e infecção). Bateria, galão de combustível, antisséptico (4 usos) e fita adesiva (5 usos) têm carga.
- **Ferramentas:** fita adesiva conserta armas e máscara (+30%). Enlatados exigem abridor, faca ou machete.
- **Saque:** [E] abre uma janela com o recipiente e o seu inventário lado a lado (pegar, pegar tudo, vestir direto, guardar). O baú construído guarda itens sem limite.

### Personagem (fase 3)

- **Criação por pontos (20):** Força e Resistência (2 a 9, base 5, 2 pontos por passo), habilidades iniciais até o nível 3 (2/5/9 pontos) e traços. Qualidades: Pulmões de aço, Imunidade forte, Metabolismo lento, Atleta, Organizado, Mãos firmes. Defeitos (devolvem até 10): Pulmão fraco, Glutão, Asmático, Sangue fino, Desajeitado, Lento, Barulhento. Há cinco modelos prontos (Equilibrado, Médica de campo, Engenheiro, Batedora, Brutamontes). A ficha é feita ao entrar na sessão e a cada morte; o anfitrião valida.
- **12 habilidades:** Luta corpo a corpo, Pontaria, Atletismo, Furtividade, Mecânica, Eletricidade, Carpintaria, Metalurgia, Medicina, Próteses, Agricultura, Culinária. Construções: madeira com Carpintaria; gerador, purificador e torre com Eletrônica + Metalurgia; selagem com as três. Implantes pedem Medicina + Cibernética. Saves antigos: Engenharia vira Eletrônica e Lógica vira Metalurgia.
- **Estamina:** Shift corre (+55% de velocidade) gastando estamina; cada golpe também gasta (armas pesadas mais; Luta reduz). Sem estamina não corre e o golpe enfraquece. Fome, sede, sobrecarga e infecção alta atrasam a recuperação.
- **Peso:** carga confortável = 16 kg + 1,2 por ponto de Força acima de 5 + 0,6 por nível de Atletismo.

### Próteses e regulador craniano (fase 4)

- **Núcleo neural:** sem processador o corpo aguenta 1 implante geral. Processador neural Mk1 (até 2) e Mk2 (até 4) ocupam o encaixe do cérebro e gastam bateria. Instalar além do limite causa rejeição imediata: o implante se perde, o membro é ferido e o estresse sináptico vai a 100%.
- **Estresse sináptico (0-100%):** cada implante ativo soma estresse (Cibernética e o processador reduzem; superaquecimento aumenta).
- **Sobrecarga:** mais implantes do que o cérebro suporta (bateria vazia, processador danificado ou removido) ou estresse ≥ 80%. Efeitos: o controle chega atrasado e desviado, espasmos empurram o personagem, os golpes saem em direção errada, o HUD treme e muda de cor, ações complexas (tratar, fabricar, operar, construir, consertar) ficam bloqueadas, o calor sobe e a cabeça sofre dano lento.
- **Implantes novos:** pernas hidráulicas (+12% de velocidade, corrida mais barata) e malha subdérmica (-25% de dano). Implantes podem ser removidos com um kit cirúrgico (Cibernética reduz o risco).

### Itens, armas de fogo, som e furtividade (fase 5)

- **Ferramentas** (não se gastam): martelo (também arma), chave de fenda, alicate e serra. Construções de madeira pedem martelo e pregos; elétricas pedem chave de fenda, alicate, fios e sucata eletrônica; torre e selagem pedem serra. Receitas novas: pregos, fios, munição 9 mm e cartuchos.
- **Utilidades e médicos:** lanterna (gasta carga; pilhas recarregam), cantil (3 goles, enche com água limpa), gaze (vale como bandagem), álcool 70% (5 usos, vale como antisséptico), analgésico (2 min sem penalidade de membros feridos).
- **Armas de fogo:** pistola 9 mm (pente 12, 430 px) e espingarda calibre 12 (2 cartuchos, 6 chumbos). Miram no mouse, têm dispersão (Pontaria reduz; cansaço aumenta), desgastam, engasgam quando gastas e quebram. [R] recarrega com a munição do inventário. A pistola cabe no coldre.
- **Som:** passos (andando 110, correndo 270, agachado 35 px; Furtividade reduz; Barulhento e sobrecarga aumentam), golpes, tiros (900 e 1300 px), portas, construções, demolições e torres fazem barulho. Infectados no raio vão investigar o local.
- **Furtividade:** [C] agacha (mais lento, quase silencioso, visto de 55% da distância). Correr e lanterna acesa aumentam a distância de visão. Infectados lembram do alvo por alguns segundos e depois vão até onde o viram. Andar agachado perto de infectados treina Furtividade. Camuflagem por áreas escuras fica para quando houver ciclo de luz.

### Ações com tempo e medicina cooperativa (fase 6)

- **Ações com tempo:** tratar (2 a 8 s), operar (14 s), remover implante (10 s), manutenção (5 s), fabricar, consertar, recarregar (1,6 s pistola, 2,4 s espingarda), comer, beber, vestir mochila ou máscara, trocar filtro e ler manuais. Uma barra aparece no HUD e sobre a cabeça do personagem (todos veem). Andar ou levar um golpe interrompe. Medicina, Cibernética e Pontaria encurtam o tempo.
- **Tratar um aliado:** na aba Corpo escolha o paciente (aliados a até ~2 tiles). Curativos, antibiótico, tala, instalação e remoção de implantes usam os suprimentos e as habilidades de quem trata. Os dois ficam parados e vulneráveis; se qualquer um se mexer ou for atacado, o procedimento para. Tratar outra pessoa é 25% mais rápido e rende 50% mais experiência; operar a si mesmo deixa o implante com integridade 80%.

### Ferimentos, roupas e armaduras (fase 12)

- **Golpe nem sempre sangra.** A chance de abrir ferida cresce com o dano (10% + 2,2% por ponto, até 75%). Golpes de menos de 4 pontos nunca sangram. A roupa reduz o dano ("defesa") e a chance de sangrar ("anti-corte").
- **Uma ferida por vez.** Com uma ferida aberta, um novo corte não abre outra em outro membro: ele piora o sangramento da que já existe (e a reabre, se estava enfaixada). Um golpe forte (16+) a torna profunda. O dano de vida continua indo para o membro atingido.
- **Roupas:** 5 espaços (cabeça, tronco, mãos, pernas, pés), além da máscara. Cada espaço cobre membros: o tronco cobre também 60% dos braços, as mãos 50% dos braços, os pés 40% das pernas. A defesa somada vai até 80%. As peças gastam ao absorver golpes; em farrapos (0%) protegem 40% do normal. Conserto com fita, como as outras coisas.
- **Conjuntos:** cada peça dá um bônus pequeno, e o conjunto completo soma um bônus maior:
  - *Mecânico* (macacão, luvas e botas de trabalho): consertos de itens, veículos e muros mais rápidos;
  - *Médico* (jaleco, luvas cirúrgicas e calça hospitalar): tratamentos mais rápidos e bandagens que fecham a ferida mais rápido;
  - *Tático* (capacete, colete, luvas, calça e botas militares): mais dano corpo a corpo e recarga mais rápida;
  - *Anti-esporos* (traje, luvas e botas de borracha): menos carga patogênica e menos gasto de filtro;
  - *Sucata* (capacete, armadura e caneleiras, fabricados na bancada): só proteção, e pesa.
- **Onde achar:** roupas comuns nas caixas comuns, as médicas em clínicas, as de mecânico, anti-esporos e militares nas caixas técnicas (as militares são raras). Todo sobrevivente começa de camiseta ou moletom, calça jeans e tênis.
- **Sem sutura (decisão de 30/10):** a bandagem segura o sangramento. Na ferida leve ele para; na profunda cai para 15%. Com o tempo (e sem infecção acima de 25%), a profunda enfaixada vira leve e a leve cicatriza. Medicina e o conjunto médico fazem a bandagem começar o fechamento mais adiantado. Saves antigos trocam kits de sutura por talas.
- **Ossos:** braços e pernas podem sofrer torção ou fratura. A torção sara sozinha em ~4 min (~1,5 min com tala); a fratura só sara imobilizada com tala (~10 min, comendo e bebendo). Perna machucada deixa o personagem lento (torção -15%, fratura -35%) e braço machucado tira dano corpo a corpo; a tala reduz a penalidade e o analgésico corta pela metade. Tala: item médico, fabricada com 1 madeira + 1 bandagem.
- **Quedas:** `SurvivorData.fall_injury(metros)` já calcula o dano de pular ou cair (abaixo de 2,5 m nada; até 4 m torção; até 7 m torção ou fratura numa perna; até 11 m fratura e dano no tronco; acima disso as duas pernas e risco de morte). Atletismo amortece 0,3 m por nível; implante de pernas, 1,5 m. Será chamada quando existirem prédios com andares (casas de dois andares, quartel de bombeiros) e janelas para pular.
- **Barra rápida:** a tecla 1-5 (ou um clique no espaço) só escolhe o item. Arma escolhida vai para a mão e o clique ataca; outro item (bandagem, comida, tala...) é usado com o clique do mouse. Escolher o mesmo espaço de novo solta (e guarda a arma).
- **Aba Corpo:** nas cores normais da interface. À esquerda ficam os espaços de roupa (botão direito: tirar ou consertar), os conjuntos e os bônus, e as roupas do inventário com o botão "Vestir". À direita, os 6 membros em linha, só com o nome: só o membro machucado (ferida, osso, infecção ou vida baixa) ganha contorno vermelho neon pulsando. Clicar num membro mostra a vida, o estado, a proteção da roupa e o tratamento.

### Interação com móveis, estações e máquinas (fase 13)

- **Móveis guardam os itens.** Nas casas, lojas, bares, clínicas e oficinas, os itens ficam nos móveis: geladeira (comida e água), fogão (panela, abridor, enlatados), pia (antisséptico, álcool, bandagens), armário (roupas, mochila, lanterna; às vezes arma), estante e arquivo (manuais, pilhas, sementes, eletrônica), prateleira e balcão (mantimentos e miudezas) e tambores (combustível e sucata). Na clínica, armário, arquivo e pia são médicos; na oficina, técnicos. Cerca de 35% dos móveis estão vazios (55% nas vilas vivas, onde os moradores guardam pouco). A caixa solta só aparece em prédio sem móvel que guarde coisas.
- **Estações:** bancada, fogareiro, fornalha (nova) e mesa de reparos. A receita que exige estação só se faz nela: chegue perto, aperte [E] e a janela da estação lista as receitas dela. A aba Inventário lista só o que se faz à mão. A mesa de reparos abre a lista de tudo o que está gasto (inventário e roupa vestida).
  - *Fogareiro:* queima lenha (1 madeira = 2 receitas).
  - *Fornalha* (sucata 6, metal 2; Metalurgia 1): funde 3 sucatas em 1 metal e faz pregos; 1 madeira por fornada.
- **Máquinas precisam de insumo**, além de energia:
  - *Gerador:* combustível (como antes);
  - *Eólico:* vento; *coletor:* chuva;
  - *Purificador:* filtro (1 filtro = 5 min ligado);
  - *Selagem de ar:* filtros (2 filtros = 6 min);
  - *Torre:* munição 9 mm (até 25 balas, 1 por tiro).
  Sem insumo, a máquina não liga nem gasta energia. [E] põe o insumo que estiver no inventário. As torres das vilas não precisam.

### Fechaduras, mira no mouse e ritmo das ações (fase 14)

- **Fechaduras:** fora das vilas vivas, alguns prédios (25% dos vivos, 35% dos abandonados, 18% dos tomados por esporos; nunca o prédio onde a equipe acorda) e alguns móveis (armário 35%, arquivo 45%, balcão 30%, estante 12%) e caixas técnicas (20%) estão trancados. Móvel trancado guarda mais itens. Fechaduras de loja, mercado, bar, clínica, oficina e arquivos são reforçadas.
  - *Chave:* a do móvel fica em outro móvel do mesmo prédio; a do prédio, num móvel de um prédio vizinho (até 16 tiles). Cada chave tem rótulo ("Chave (armário)", "Chave (casa em Vila Fantasma)") e abre todas as portas daquele prédio. Com a chave, destrancar leva 1 s.
  - *Forçar:* com gazua (60% simples / 35% reforçada), chave de fenda (22% / 8%) ou faca (15% / 5%), mais 4% por nível de Mecânica; leva 4 s com gazua e 6 s improvisando (Mecânica encurta). Falhar faz barulho e gasta 25% da gazua (ela quebra no zero). A gazua aparece em caixas técnicas e armários e se fabrica na bancada (1 metal + 1 sucata, alicate, Metalurgia 1 e Mecânica 1).
  - O que abriu fica aberto (vai para o save e para quem entra na partida).
- **Mira no mouse:** o personagem sempre olha para o mouse, ande para onde andar. Golpe corpo a corpo e tiro vão na direção exata do mouse. Dirigindo, ele olha para onde o veículo vai.
- **Ritmo das ações:** vestir e tirar roupa, máscara, mochila e coldre é imediato; construir também. Toda ação com tempo (comer, tratar, fabricar, consertar, forçar fechadura...) fecha o inventário ou a janela aberta, e a barra de progresso aparece no jogo.
- **Corte das paredes (revisado em 05/11):** regra fixa, sem depender de onde o personagem está dentro do prédio.
  - *Dentro* (prédio do mapa, ou piso construído pelo jogador): as paredes de baixo do prédio (a frente e as divisórias) ficam baixas o tempo todo; as de cima continuam inteiras.
  - *Fora:* nada abaixa; o piso fica escuro e o que está dentro (móveis, caixas, infectados, saqueadores, moradores, outros jogadores, corpos) não aparece.
  - *Espiando pela janela* (de fora, colado nela): o telhado some e dá para ver o interior, meio escuro. As paredes não mexem.
  - *Passando atrás:* paredes e telhado ficam translúcidos para o personagem aparecer, mas o que está dentro continua escondido.
  - Dentro ou fora é decidido pela célula do mapa (`World.cell_at`), a mesma conversão usada para posicionar as coisas.
  - As cercas das vilas nunca abaixam.
- **Rolagem das abas:** a posição da rolagem se mantém quando a tela se atualiza.
- **Barra rápida no inventário:** com o menu aberto, a barra rápida sai da lateral e aparece no topo da aba Inventário, para arrastar itens para ela.

### Combate e tipos de infectados (fase 15)

- **Ritmo:** ao chegar no alvo, o infectado para, prepara o golpe (o corpo avermelha e aparece um aviso), bate e fica um instante se recuperando. Apanhar no corpo a corpo faz cambalear e perde o golpe preparado; tiro quase não faz cambalear (a espingarda um pouco). Assim dá para bater e se afastar.
- **Empurrão (F):** afasta e derruba por ~1 s os infectados à frente, sem dano; gasta 8 de estamina.
- **Golpe furtivo:** em infectado distraído, ou chegando agachado pelas costas, o golpe dá o triplo de dano e derruba.
- **Agarrado (revisado em 02/11):** só o infectado comum agarra. Cada golpe dele que acerta tem 35% de chance de prender o personagem por ~2 s, sem sair do lugar. O empurrão (F) solta na hora, e cada golpe que você acerta reduz o tempo preso. Segurando, ele morde de novo mais rápido.
- **Tipos:** o comum é a grande maioria (cerca de 80%); os outros são raros, e os perigosos aparecem mais perto da borda.

| Tipo | Vida | Velocidade | Dano | Particularidade |
|---|---|---|---|---|
| Comum (a grande maioria) | 40 | lento | 8 | o golpe pode agarrar |
| Corredor | 26 | muito rápido | 7 | golpe rápido |
| Brutamonte | 150 | lento | 21 | quase não cambaleia; derruba muro, barricada e porta 2,5x mais rápido; vem nas hordas |
| Bolha de esporos | 34 | lento | 6 | ao morrer solta uma nuvem: sem máscara, +14 de carga patogênica; com máscara, gasta o filtro |
| Rastejante | 30 | muito lento | 11 | difícil de ver; só ataca as pernas |
| Chamador (raro) | 60 | normal | 8 | com menos de 30% de vida, se encolhe e grita: todo infectado a ~700 px vem atrás de quem o feriu, e mais 2 a 4 aparecem |

### Janelas, barricadas e casa-abrigo (fase 16)

- **Janela:** [E] quebra a janela inteira (barulho alto; de mão vazia, 45% de cortar o braço). Janela quebrada vira passagem.
- **Barricada** ([E] na janela, porta ou vão e "Barricar"; 2 madeiras, 4 pregos, martelo; 4 s): vai numa janela (inteira ou quebrada), porta ou vão de qualquer prédio, do mapa ou seu. Tem 160 de vida e bloqueia a passagem. [E] tira (devolve 1 madeira).
- **Infectados:** quem vê alguém dentro de um prédio vai até a abertura mais perto. Se estiver aberta, entra; se tiver barricada, bate nela; se for porta fechada, arromba (a porta cede depois de alguns golpes).
- **Abrigo:** um prédio do mapa sem nenhuma abertura passável (janela quebrada, vão ou porta aberta sem barricada) e com ao menos uma barricada vira o abrigo da equipe: é onde os sobreviventes novos acordam.

### Interação pelo [E] e tempo das ações (fase 21)

- **Menu do [E]:** apertar [E] num objeto do mundo abre um painel pequeno ao lado do personagem com as opções dele (opções impossíveis aparecem apagadas). Escolha com o mouse, com o número (1-9) ou com [E] de novo (a primeira possível); Esc fecha, e andar para longe também. Com uma opção só, o [E] já faz direto.
  - *Veículo:* dirigir, entrar como passageiro, ligação direta, abastecer, consertar, porta-malas, painel.
  - *Janela:* quebrar, barricar (inteira ou quebrada); andar alto: pular. *Porta:* abrir/fechar, usar a chave ou forçar, barricar. *Barricada:* tirar. *Muro da vila:* consertar.
  - *Eólico:* subir o mastro (2 metais, 2 sucatas). *Gerador:* abastecer. *Purificador, selagem, torre:* pôr filtro ou municiar. *Coletor:* recolher água. *Canteiro:* plantar, regar, colher. *Fogareiro e fornalha:* usar (janela de receitas) ou pôr lenha. *Cama:* dormir. *Escada:* subir/descer. *Móvel, caixa, corpo:* abrir.
  - As janelas grandes continuam só para fabricar (estações), conversar com a vila e o painel do veículo.
- **Tempo das ações:**

| Ação | Tempo |
|---|---|
| Barricar | 4 s (Carpintaria encurta) |
| Tirar barricada | 2 s |
| Quebrar janela / subir para pular | 0,8 s |
| Consertar muro | 3 s (conjunto de mecânico encurta) |
| Montar módulo do mastro | 5 s (conjunto de mecânico encurta) |
| Abastecer gerador | 2,5 s |
| Pôr filtro ou munição | 2 s |
| Pôr lenha | 1,5 s |
| Recolher água | 1,5 s |
| Canteiro | 2 s |
| Abrir/fechar porta, abrir móvel, escada, entrar no carro | imediato |

  Já tinham tempo: comer, beber, tratar, fabricar, consertar itens, recarregar, ligação direta, forçar fechadura.

### Sono, frio e chuva (fase 17)

- **Descanso:** cai de 100 a 0 em ~1,5 dia do jogo acordado (mais rápido lutando). Abaixo de 25, a estamina volta mais devagar; abaixo de 8, o personagem fica lento. [E] numa cama (das casas ou construída) dorme: recupera em ~4 min de jogo; jogando sozinho, o tempo passa 6x mais rápido. Mexer-se, levar dano ou um infectado/saqueador chegar perto acorda.
- **Temperatura do ar:** ~22 °C à tarde e ~8 °C de madrugada; nublado -2, chuva -6, tempestade -9, névoa -3.
- **Sensação:** ar + aquecimento da roupa x1,4 (cada peça tem "aquece"; molhada aquece até 60% menos) + 7 dentro de prédio + 14 perto de fogo (fogareiro ou fornalha acesos, tambor com fogo).
- **Corpo:** abaixo de 16 °C de sensação, o corpo esfria; acima de 18, volta aos 37. Abaixo de 35,5 °C: frio (estamina mais lenta). Abaixo de 34: hipotermia (mais lento, perde vida); abaixo de 32, perde vida rápido.
- **Chuva:** fora de prédio molha; seca no abrigo e bem rápido perto do fogo.
- **HUD:** barras novas de descanso e temperatura do corpo; avisos de molhado, com frio, hipotermia, exausto e agarrado.

### Casas abandonadas com infectados e defesa das vilas (fase 22)

- **Infectados dentro de casas:** casas abandonadas (50%) e tomadas por esporos (80%) podem ter 1 a 3 infectados lá dentro, sorteados quando um jogador chega a ~800 px pela primeira vez (nunca nascem colados nele). A maioria é comum; um em cada quatro é rastejante. Acampamentos de saqueadores não têm.
- **Cercas incompletas:** 40% das vilas não terminaram a cerca (1 ou 2 trechos abertos de 3 a 6 tiles por lado, fora os portões) e compensam com 2 guardas a mais. Na simulação longe dos jogadores, os guardas extras também seguram hordas e assaltos.
- **Espetos:** saíram da frente dos portões. Agora ficam espalhados em volta da vila, a 1-3 tiles da cerca, longe das ruas (5 a 8 por vila, mais 4 onde a cerca ficou aberta). Dá para passar por cima, mas quem pisa se fere: infectados, saqueadores e jogadores. No jogador, fere uma perna (6) e deixa lento pela metade por 3 s (aviso "pé ferido"). Vale também para as armadilhas que o jogador constrói.

### Saqueadores (fase 18)

- **Quem são:** bandos com pistola, espingarda, faca ou taco. Com arma de fogo atiram de longe e mantêm distância; com arma branca chegam perto e preparam o golpe. Feridos, às vezes fogem. Ao morrer largam a arma, munição e algum saque.
- **Onde:** acampamentos em prédios abandonados grandes, longe das vilas vivas (3 a 5 por acampamento; limpar todos conta no save), e patrulhas raras de 2 ou 3.
- **Inimigos de todos:** atacam jogadores, moradores e infectados; infectados também os caçam; guardas e torres atiram neles.
- **Assaltos:** uma vila com estoque alto pode ser assaltada no lugar de uma horda (30% das vezes). O bando abre caminho pela cerca, mata quem encontra e, se ficar 8 s no centro, rouba metade do estoque e a vila perde prosperidade. Longe dos jogadores, o assalto é simulado (guardas e cerca seguram parte) e pode custar moradores. Matar saqueadores perto de uma vila dá reputação.

### Prédios de vários andares (fase 19)

- **Prédios altos:** nas cidades, prédios de 2 ou 3 andares com comércio no térreo. Por fora, um bloco com janelas acesas coloridas, neon na quina, letreiro e laje com caixa d'água e antena; à noite, luzes iluminam a rua (mais fracas nos abandonados).
- **Andares de cima:** salas de verdade (apartamentos com móveis e saque), guardadas numa faixa reservada fora do mapa. A escada ([E]) liga um andar ao outro. Na primeira visita a um andar de prédio abandonado aparecem de 1 a 3 infectados. Esporos, clima e borda nos andares contam como no prédio lá embaixo.
- **Janela alta:** quebre e [E] para pular. O personagem cai do lado de fora do prédio, com o dano de queda de 3,5 m por andar.

### Sons (fase 20)

43 efeitos provisórios (gerados por `tools/gen_sfx.py`) tocados nos eventos do jogo. Para trocar qualquer um, use a tabela `autoload/sfx_table.gd`; a lista explicada está em `docs/SONS.md`.

### Mundo em chunks e vilas vivas (fase 7)

- **Mapa: cidades pequenas e aldeias (29/10):**
  - *Sem metrópole.* O mapa tem 6 cidades pequenas e cerca de 22 aldeias no campo. As cidades têm praça no centro, uma rua em anel e quatro ruas saindo dela, com lojas, mercado, bar, clínica, oficina e casas de frente para a rua. As aldeias são uma clareira com casas, celeiro e lavouras. Não há mais Abrigo Alfa: as 16 vilas vivas ficam espalhadas, cada uma cercada por uma cerca de chapas com portões onde as estradas passam (infectados não atravessam nem escolhem quem está lá dentro) e com NPCs.
  - *Estados de cada lugar:* **viva** (as 16 vilas, com NPCs e comércio), **abandonada** (janelas quebradas, paredes caídas, telhados faltando, entulho e mais saque) ou **tomada por esporos** (fungo no chão, nas paredes e dentro das casas, ar pesado em volta e mais infectados). Também há casas isoladas na beira das estradas, quase todas abandonadas.
  - *Estradas:* asfalto entre cidades e terra batida para as aldeias. Ao longo delas há carcaças e veículos abandonados.
  - *Prédios exploráveis:*
    - o piso é do chão (madeira, cerâmica, concreto); as paredes ficam nas bordas das células, com porta, janelas, vitrine, parede quebrada ou tomada por fungo, em 5 materiais;
    - as casas maiores têm uma divisória com passagem;
    - os móveis ficam encostados nas paredes: cama, armário, sofá, TV, cozinha, prateleiras, balcão, macas etc.;
    - as caixas de saque ficam nos cômodos.
  - *Corte estilo The Sims:* dentro de um prédio, o telhado some e as paredes entre o jogador e a câmera descem. As paredes que o jogador constrói seguem a mesma regra.
  - *Visto de fora:* não dá para ver o interior. Prédios sem telhado (ruínas) mostram o interior em sombra. Colado numa janela, vitrine ou buraco na parede, o jogador espia: o telhado some e o interior aparece com pouca sombra, mas as paredes continuam inteiras. Logo atrás do prédio, o telhado fica translúcido sobre o interior escuro.
- **Cerco às vilas (29/10):**
  - *Cerca com vida e níveis.* Cada trecho tem vida própria. Os níveis são: 1, chapa remendada (400); 2, chapa reforçada (800); 3, muralha de concreto com espetos (1500). A vila sobe de nível sozinha quando prospera (nível de prosperidade 2 e 3) e tem sucata no estoque. Os moradores consertam os trechos danificados e reconstroem os derrubados (um por vez, com sucata e sem infectado dentro). O jogador conserta com [E] por 2 sucatas (+35%, e ganha reputação).
  - *Infectados atacam.* Quem enxerga gente lá dentro (jogador ou morador) vai até uma brecha ou portão aberto. Se não houver, bate no trecho de muro mais perto até derrubar.
  - *Hordas.* Com jogador por perto, uma horda de 4 a 12+ infectados vem de tempos em tempos (maior com mais infestação), e chega um aviso. Longe dos jogadores, a horda é simulada: a força dela contra a defesa (nível da cerca e da vila) decide a infestação e as perdas.
  - *Defesa.* Os guardas lutam e os moradores fogem e podem morrer (cadáver). Há armadilhas de espetos do lado de fora dos portões e torres automáticas nos cantos, que só funcionam com cerca de nível 2 ou mais. A armadilha de espetos também entra no menu de construção.
  - *Queda.* Infectados dentro da cerca aumentam a infestação, e cada morador morto também. Com infestação em 100% ou sem moradores, a vila cai: os portões ficam abertos, os NPCs somem e ela vira zona morta. Limpar a área devolve a vila aos sobreviventes.
- **Começo e renascimento:** o primeiro sobrevivente acorda num prédio sorteado (vivo ou abandonado, longe dos esporos); quem entra depois no co-op acorda no mesmo prédio; após uma morte, numa cama da equipe ou, sem cama, num prédio novo sorteado.
- **HUD:** vitais só com ícone e barra; sem faixa de comandos; barra rápida de 5 espaços na direita (o item continua no inventário; 1 a 5 ou clique usam; botão direito tira). Curativos na barra tratam o membro mais ferido.
- **Modo construção [B]:** faixa única embaixo com as abas Fundação/Utilidades/Decoração por cima; escolher um item não fecha nada; moldura amarela na tela; a câmera desce para o personagem ficar no alto; a HUD normal some. B/Esc saem; X demolição.
- **Mundo maior:** raio de 150 tiles (antes 64) e 16 vilas. A geração planeja tudo em dados a partir da seed (igual em todos os peers); só os chunks de 16×16 células perto dos jogadores viram nós e tiles. O anfitrião carrega ao redor de todos os jogadores; cada cliente, ao redor de si. Caixas, construções, baús e pisos ficam em dados e valem com o chunk carregado ou não.
- **Vilas vivas:** prosperidade (nível 0 a 3) aumenta a produção, o número de guardas e as ofertas do comerciante. NPCs (comerciante, guardas, moradores) aparecem quando alguém se aproxima; guardas atacam infectados perto da vila. [E] num NPC abre o painel da vila.
- **Pedidos de socorro:** a vila pede comida, remédios, materiais ou peças elétricas, ou que se eliminem infectados por perto, com prazo de 6 minutos (aviso para todos e lista na aba Mundo). Atender sobe prosperidade, reputação e população e dá recompensa a quem entregou. Ignorar faz a vila perder moradores e acumular infestação, até cair.
- **Reputação:** doações e pedidos atendidos dão reputação da equipe com aquela vila; o comerciante troca itens da especialidade da vila por reputação.
- **Zonas mortas:** vila que cai fica sem NPCs, cercada de infectados e com esporos densos ao redor. Limpar a área por 30 s liberta a vila.
- Saves de antes desta fase: o mapa mudou, então só os sobreviventes (de volta ao abrigo), o legado e o tempo de jogo são aproveitados.

### Agricultura, culinária e veículos (fase 8)

- **Agricultura:** canteiro (3 madeiras + 4 pregos, martelo). [E] com enxada e sementes planta; regar (regador com 4 regas ou uma garrafa de água, limpa ou suja) dá ~150 s de água; a planta só cresce regada e com ar limpo (esporos < 0,35, ou dentro de uma selagem de ar); em esporos densos (≥ 0,6) ela morre. Batata (5 min), milho (6 min) e tomate (4 min). Agricultura acelera o crescimento e aumenta a colheita e a chance de recuperar sementes. O crescimento é calculado pelo relógio do mundo, então continua mesmo com o chunk descarregado.
- **Culinária:** fogareiro (2 metais + 3 sucatas) e panela. Receitas: sopa de batata, ensopado (feijão + batata + tomate), milho assado e ferver água suja (vira água limpa). Comida cozida dá "bem alimentado" por 3 min (estamina recupera 50% mais rápido). Sem prática, a comida pode queimar; Culinária também reduz a intoxicação de comida estragada.
- **Veículos (escolhidos):**
  - *Locomóvel blindado:* carro a vapor; 2,4x a velocidade a pé, 4 lugares (motorista + 3), porta-malas de 60 L, queima querosene (galões) na caldeira, barulhento (520 px), atropela forte.
  - *Triciclo elétrico:* protótipo experimental; 3,2x, só o piloto, porta-malas de 8 L, gasta células galvânicas, quase silencioso (240 px), atropela fraco.
  - Ficam abandonados na beira das estradas, trancados, com pouca energia e desgastados. Ligação direta exige Mecânica 2 (pode dar choque); consertar pede martelo, chave de fenda, 1 metal e 2 sucatas. Atropelar desgasta; abaixo de 30% de estado o veículo perde velocidade e a 0% não anda. Quem dirige controla o movimento (como a pé); passageiros acompanham. O porta-malas abre na janela de saque e os veículos vão para o save.
- **Construção estilo The Sims:** o piso ocupa a célula do losango; paredes, meia parede, parede com janela, porta e portão ficam nas **bordas** da célula (aponte o mouse para o lado do quadrado). As antigas paredes e portas em bloco saíram do jogo. A janela de construção [B] tem 3 abas:
  - *Fundação:* pisos (metal, madeira, concreto), paredes, janelas, portas e portões.
  - *Utilidades:* bancada de fabricação (receitas técnicas exigem estar perto dela), mesa de reparos, fogareiro, dínamo a vapor, cata-vento com dínamo, banco de acumuladores, purificador, torre, selagem de ar, coletor de chuva, canteiro, baú e cama.
  - *Decoração:* abajur de lâmpada, lampião elétrico, letreiro de lâmpadas, mesa, cadeira, sofá, tapete, vaso e estante.
- **Energia por produção e consumo:** construções de energia a até 10 tiles umas das outras formam uma rede. O eólico gera 22 W por módulo do mastro (1 a 5; [E] sobe um módulo por 2 metais + 2 sucatas) vezes o vento; prédios e construções por perto atrapalham o vento. O gerador a combustão (100 W) só queima o combustível que falta na rede. Os bancos de baterias guardam a sobra e cobrem a falta. Quando falta energia, a prioridade é selagem, purificador, torre e depois as luzes. As luzes só gastam à noite.
- **Mesa de reparos:** armas de fogo (fita + 1 sucata), mochilas e coldres só se consertam nela. Nela, todo conserto rende +45% (em vez de +30% com fita em qualquer lugar).
- **Dia, noite e clima:** um dia dura 24 minutos (1 hora do jogo = 1 minuto). À noite o mundo escurece; luzes acesas, a lanterna e os postes iluminam. No escuro, os infectados enxergam até 40% mais perto, exceto quem está com lanterna ou sob luz. Os climas são:
  - *Céu limpo* e *nublado*;
  - *Chuva:* abafa os passos (75%), rega os canteiros e enche os coletores;
  - *Tempestade:* vento forte (bom para os eólicos), passos a 55% e visão menor;
  - *Névoa de esporos:* +0,12 de esporos e visão a 60%.
  O clima muda a cada 3 a 7 minutos. O HUD mostra a hora e o clima.


## Tema steampunk (fase 23)

O jogo trocou o tema cyberpunk pelo **steampunk**. As mecânicas não mudaram; mudaram nomes,
textos, cores da interface e luzes. A eletricidade continua existindo, mas é rudimentar e
experimental (lâmpadas incandescentes, lanternas, dínamos, células galvânicas). Os ids
internos do código continuam os antigos (por exemplo `implante_braco`, `eletronica`,
`cibernetica`, `bateria`), para não quebrar saves nem testes.

| Antes (cyberpunk) | Agora (steampunk) | id interno |
|---|---|---|
| Implantes, aba Implantes | Próteses, aba Próteses | `implante_*`, `IMPLANTS` |
| Processador neural Mk1/Mk2 | Regulador craniano Mk I/Mk II | `proc_neural_mk1/2` |
| Filtro pulmonar mecânico | Fole pulmonar de latão | `implante_pulmao` |
| HUD de escaneamento | Monóculo analítico | `implante_hud` |
| Braço reforçado | Braço de pistão | `implante_braco` |
| Pernas hidráulicas | Pernas pneumáticas | `implante_pernas` |
| Malha subdérmica | Placas subcutâneas | `implante_derme` |
| Estresse sináptico / sobrecarga | Tensão nervosa / colapso nervoso | `synaptic`, `overloaded()` |
| Bateria (implantes, moto) | Célula galvânica | `bateria` |
| Banco de baterias | Banco de acumuladores | `bateria_casa` |
| Galão de combustível | Galão de querosene | `combustivel` |
| Gerador a combustão | Dínamo a vapor (caldeira) | `gerador` |
| Gerador eólico | Cata-vento com dínamo | `eolico` |
| Purificador industrial | Exaustor purificador | `purificador` |
| Torre automatizada | Torre de engrenagens | `torre` |
| Selagem de ar | Vedação pneumática | `vedacao` |
| Luminária, poste de luz, letreiro neon | Abajur de lâmpada, lampião elétrico, letreiro de lâmpadas | `luminaria`, `poste`, `letreiro` |
| Picape blindada / moto elétrica | Locomóvel blindado / triciclo elétrico | `picape`, `moto` |
| Eletrônica / Cibernética (habilidades) | Eletricidade / Próteses | `eletronica`, `cibernetica` |
| Fio elétrico, sucata eletrônica | Fio de cobre, peças elétricas | `fios`, `sucata_eletronica` |
| Pistola 9 mm, munição 9 mm | Pistola de carregador, balas de pistola | `pistola`, `municao_9mm` |
| Espingarda/cartucho calibre 12 | Espingarda de cano duplo, cartucho de chumbo | `espingarda`, `cartucho_12` |
| Conjunto tático | Conjunto do regimento | `tatico` |
| Roupas modernas (boné, tênis, jeans, moletom...) | Boina, sapatos de couro, calça de brim, suéter de lã... | mesmos ids |
| Geladeira | Caixa de gelo | `geladeira` |
| Terminal de campo | Diário de campo | — |

**Interface:** a paleta (`scripts/ui/ui_theme.gd` e `tools/gen_ui.py`) virou madeira escura,
latão, cobre e papel envelhecido; as linhas de varredura (efeito de monitor) foram desligadas.
As cores com sentido próprio continuam (vida vermelha, sede azul, contaminação verde).
**Luzes:** postes, letreiros e prédios usam tons quentes de lâmpada incandescente.
**Arte:** a arte do mundo ainda é a provisória (com traços cyberpunk, como letreiros e TVs);
ela será refeita no tema novo com o PixelLab.

## Estado da implementação

| Fase | Conteúdo | Situação |
|---|---|---|
| 1 | Base de rede: sessão (hospedar, entrar, solo), personagens sincronizados, infectados, construção, saque, vilas, morte e legado com autoridade no anfitrião, save por jogador | **feito** |
| 2 | Inventário por peso e volume (bolsos, mochilas, coldre, sobrecarga), itens com estado próprio (durabilidade, validade, cargas), janela de saque, baú, abridor de latas | **feito** |
| 3 | Criação por pontos (atributos, habilidades, traços), 12 habilidades, estamina e corrida | **feito** |
| 4 | Próteses (regulador craniano, limite de próteses, rejeição, tensão nervosa e colapso, remoção) | **feito** |
| 5 | Ferramentas e materiais, lanterna, cantil, médicos novos, armas de fogo com munição, som e furtividade | **feito** |
| 6 | Ações com tempo (barra, interrupção por movimento ou dano) e medicina cooperativa (curativos e cirurgias em aliados) | **feito** |
| 7 | Mundo em chunks (raio 150), vilas vivas com NPCs, prosperidade, reputação, comércio, pedidos de socorro e zonas mortas | **feito** |
| 8 | Agricultura (canteiro, sementes, rega, colheita), culinária (fogareiro, receitas, água fervida) e veículos (locomóvel blindado e triciclo elétrico) | **feito** |
| 10 | Padrão visual único (STYLE.md), arte própria no lugar do Town Sampler e do Neon District | **feito** |
| 11 | Cidades pequenas e aldeias (vivas, abandonadas, tomadas por esporos), prédios exploráveis com corte estilo The Sims | **feito** |
| 12 | Ferimentos com chance de sangrar (uma ferida por vez), torções e fraturas com tala, quedas, roupas e armaduras com conjuntos, barra rápida de escolher e clicar | **feito** |
| 13 | Móveis com itens (geladeira, armário, pia...), estações com janela de fabricação (bancada, fogareiro, fornalha, mesa de reparos) e máquinas que gastam insumo (filtro, munição, lenha) | **feito** |
| 14 | Fechaduras (chave escondida, gazua ou forçar), personagem mirando no mouse, vestir e construir imediatos, ação com tempo fecha o menu, barra rápida no inventário | **feito** |
| 15 | Combate com preparo do golpe, cambalear, empurrão, golpe furtivo, agarrado; seis tipos de infectado (com o raro chamador) | **feito** |
| 16 | Quebrar janela, barricadas em janelas/portas/vãos, infectados arrombando, prédio fechado vira abrigo | **feito** |
| 17 | Sono e cama, temperatura do corpo, roupa que aquece, chuva que molha | **feito** |
| 18 | Saqueadores: acampamentos, patrulhas, assaltos a vilas (reais e simulados) | **feito** |
| 19 | Prédios de 2 e 3 andares iluminados, escadas, andares de cima, pulo da janela | **feito** |
| 20 | Sons provisórios com tabela central | **feito** |
| 21 | Menu pequeno do [E] para tudo no mundo, tempos das ações, comum lento que agarra | **feito** |
| 22 | Interior escondido de fora (espiar pela janela volta), infectados em casas abandonadas, vilas com cerca incompleta e mais guardas, espetos em volta da vila que ferem e deixam lento | **feito** |
| 23 | Tema steampunk: nomes, textos, próteses no lugar de implantes, eletricidade rudimentar, paleta de latão e cobre, luzes quentes | **feito** |
| 24 | Menu de pausa no ESC (pausa no solo; continuar, controles, salvar e voltar ao menu, salvar e sair) e troca de teclas salva em user://controles.cfg; avisos e teclas do HUD mostram a tecla atual | **feito** |
| 9 | Construção em bordas (estilo The Sims) com 3 abas, utilidades e decoração, rede de energia (eólico, combustão, baterias), mesa de reparos, dia/noite, clima e iluminação | **feito** |
