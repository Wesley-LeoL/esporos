# Esporos

Jogo de sobrevivência tático **steampunk** (vapor, latão e engrenagens, com eletricidade ainda rudimentar) em pixel art 2D isométrico, feito em **Godot 4.7** (GDScript). Design completo em [`docs/GDD.md`](docs/GDD.md).

## Rodar
Abra a pasta no Godot 4.7+ (versão padrão, não .NET) e aperte F5. O projeto já tem presets de exportação (Windows e Linux) em `export_presets.cfg`.

**Controles:** `WASD` mover · mouse mira · `Espaço`/clique atacar · `F` empurrar · `E` interagir · `Tab` ou `I` menu · `X` demolir · `F5` salvar · `Esc` cancelar · `F1` ou `` ` `` console de testes.

## Controles
WASD move · o personagem olha para o mouse · Shift corre · C agacha · Espaço/clique ataca na direção do mouse · F empurra (e solta quando agarrado) · R recarrega · E interage: abre um menu pequeno com as opções do objeto (carro, janela, porta, máquinas...; dentro do veículo, sai) · Tab abre o diário de campo (inventário, corpo, habilidades, próteses, mapa) · I inventário · M mapa · B modo construção · V status do veículo (dentro dele) · X demolição · 1 a 5 barra rápida · F5 salva · ESC pausa (no solo o jogo para) e abre o menu com Continuar, Controles (ver e trocar as teclas, salvas em `user://controles.cfg`), Salvar e voltar ao menu e Salvar e sair · F1 console.

**Inventário em grade:** botão direito abre as opções do item; arrastar com o botão esquerdo reorganiza ou move entre bolsos, mochila, coldre e o recipiente aberto; dois cliques passam o item entre o recipiente e o inventário; "Organizar" ordena por tipo. Caixas, baús, sacos, cadáveres e porta-malas abrem a grade deles ao lado da sua.

**Mapa (M):** mostra só o que você já explorou (salvo por jogador em `user://`): estradas, prédios, vilas (com pedidos de socorro), caixas por tipo, veículos e construções; o painel ao lado diz o que se acha em cada área.

## Co-op (2 a 4 jogadores)
- **Hospedar:** na tela de título, ligue **CO-OP: ABERTO** e clique em Novo jogo ou Continuar. O jogo abre a porta UDP **7777**, e o anfitrião é a autoridade da sessão: simula o mundo e guarda o save.
- **Entrar:** digite o IP do anfitrião e clique em **ENTRAR NA SESSÃO**. O mundo é gerado pela mesma seed, e só as alterações vêm pela rede.
- **Na mesma rede local:** use o IP local do anfitrião (por exemplo 192.168.0.10). O Windows pode pedir para liberar o jogo no firewall.
- **Pela internet:** o anfitrião precisa redirecionar a porta UDP 7777 no roteador para o próprio PC, ou o grupo pode usar uma rede virtual (Tailscale, ZeroTier, Radmin VPN) e entrar pelo IP dessa rede.
- **Sobreviventes:** cada um fica salvo pelo nome do jogador. Ao voltar para a sessão com o mesmo nome, o jogador continua com o mesmo personagem, se ele ainda estiver vivo.
- **Menu e console:** no co-op, o menu (Tab) não pausa o mundo. Os comandos do console (F1) rodam no anfitrião, sobre o personagem de quem digitou.

Para testar o co-op numa máquina só: `godot --path . -- --autostart=host --name=A` em uma janela e `godot --path . -- --autostart=join:127.0.0.1 --name=B` em outra.

## Sistemas implementados (protótipo jogável)
- **Carga patogênica (0–100%)**: todos nascem infectados; máscara + filtro, supressor químico e purificador controlam a carga. Água contaminada acelera a infecção.
- **Mar de Esporos**: concentração sobe perto da borda do mapa; na zona letal o filtro é destruído e hordas de elite surgem sem parar.
- **Inventário por peso e volume**: bolsos, mochilas e coldre com capacidade em litros, sobrecarga que deixa lento, itens com durabilidade (armas e máscara), validade (perecíveis estragam) e carga (bateria, combustível, antisséptico, fita). Janela de saque com o recipiente e o inventário lado a lado; baú para guardar.
- **Armas de fogo, som e furtividade**: pistola e espingarda com munição, mira no mouse e dispersão; passos, tiros e construções fazem barulho que os infectados investigam; [C] agacha. Ferramentas (martelo, chave de fenda, alicate, serra) e materiais (pregos, fios, peças elétricas) para construir.
- **Combate com ritmo**: o infectado para, prepara o golpe (avermelha), bate e se recupera; apanhar faz cambalear; empurrão (F), golpe furtivo pelas costas, agarrado quando cercado. Tipos: corredor, brutamonte, bolha de esporos, rastejante e o raro chamador, que grita por ajuda quando quase morto.
- **Janelas e barricadas**: quebre janelas (barulho), pregue barricadas em janelas, portas e vãos; infectados batem nelas e arrombam portas; prédio todo fechado vira o abrigo da equipe.
- **Sono, frio e chuva**: durma numa cama; o frio da noite e da chuva esfria o corpo (roupa aquece, molhada aquece menos; abrigo e fogo ajudam).
- **Saqueadores**: bandos armados em acampamentos e patrulhas, que também assaltam vilas prósperas.
- **Prédios altos**: 2 e 3 andares iluminados nas cidades, com escadas, andares para saquear e janelas para pular.
- **Sons**: 43 efeitos provisórios numa tabela central (`autoload/sfx_table.gd`, ver `docs/SONS.md`).
- **Fechaduras e mira**: prédios e móveis trancados (ache a chave ou force com gazua); o personagem olha, bate e atira na direção do mouse.
- **Móveis, estações e máquinas**: os itens das casas ficam em geladeiras, armários, pias e estantes; bancada, fogareiro, fornalha e mesa de reparos abrem a própria janela; purificador, selagem e torre só funcionam com insumo (filtro, munição) além de energia.
- **Saúde e roupas**: uma barra de vida só (sem membros). Nem todo golpe sangra; sangrando, novos cortes pioram o sangramento, que tira vida por segundo. Quedas torcem ou quebram a perna (tala). Roupas e armaduras (5 espaços, no topo do inventário) reduzem o dano e a chance de sangrar, gastam com o uso e formam conjuntos com bônus (mecânico, médico, regimento, anti-esporos).
- **Ações com tempo e medicina cooperativa**: curativos, cirurgias, recarga e consumo levam tempo e são interrompidos por movimento ou dano; botão direito num curativo ou remédio: "Usar em <aliado>"; cirurgia em aliado na aba Próteses.
- **Agricultura, culinária e veículos**: canteiros com sementes, rega e colheita (esporos densos matam a plantação); fogareiro e panela para cozinhar e ferver água; locomóvel blindado a vapor e triciclo elétrico abandonados, com ligação direta, energia, conserto, porta-malas e passageiros.
- **Metabolismo**: fome (calorias) e sede (água limpa vs. suja); carboidratos e proteínas foram removidos do protótipo.
- **Curativos e remédios**: bandagem, gaze, curativo com iodo e curativo de campo estancam o sangramento e curam vida na hora (os melhores se fabricam); antibiótico cura aos poucos; analgésico e pó hemostático diminuem o sangramento; tala imobiliza a perna. Tônico revigorante e adrenalina aceleram a estamina por um tempo.
- **Próteses**: fole pulmonar de latão, monóculo analítico, braço de pistão, pernas pneumáticas e placas subcutâneas, com célula galvânica, superaquecimento, integridade e manutenção. O **regulador craniano** limita as próteses (1 sem regulador; Mk I e Mk II ampliam); passar do limite dá rejeição ou **colapso nervoso** (controle atrasado, espasmos, visão turva, sem ações complexas).
- **Criação de personagem por pontos**: Força, Resistência, habilidades iniciais e traços (qualidades e defeitos), com modelos prontos; refeita a cada morte.
- **12 habilidades por uso** (Luta, Pontaria, Atletismo, Furtividade, Mecânica, Eletricidade, Carpintaria, Metalurgia, Medicina, Próteses, Agricultura, Culinária) e manuais; "parede de conhecimento" para construções e cirurgias.
- **Estamina**: Shift corre; golpes cansam; fome e sobrecarga atrasam a recuperação.
- **Perma-death com legado**: morte por infecção vira infectado de elite com inventário e próteses; morte física deixa cadáver que decompõe, atrai moscas/hordas e serve de baú.
- **Caça**: veados, javalis e coelhos pelo campo. Fogem de gente, de infectados e de tiros (chegue agachado ou atire de longe); o javali ferido investe. A carcaça dá carne crua (asse ou defume no fogareiro) e couro (luvas, coldre, bolsa e sobretudo).
- **Começo aleatório**: o primeiro sobrevivente acorda dentro de um prédio sorteado (vivo ou abandonado, longe dos esporos); quem entra depois acorda no mesmo prédio; depois de morrer, numa cama da equipe ou num prédio novo. As 16 vilas vivas são cercadas e têm NPCs. A cerca tem vida e sobe de nível conforme a vila prospera. Infectados que veem gente lá dentro batem no muro até abrir brecha; hordas atacam de tempos em tempos; guardas, armadilhas e torres defendem. Sem ajuda, a vila pode cair e virar zona morta.
- **HUD enxuta**: vitais só com ícone e barra, sem a faixa de comandos; **barra rápida** de 5 espaços na direita (arraste itens do inventário; teclas 1 a 5 ou clique usam: empunhar, comer, beber, enfaixar...). **Modo construção** [B]: faixa embaixo com as abas, moldura na tela, câmera deslocada e HUD escondida.
- **Cidades pequenas e aldeias** ligadas por estradas no meio do campo, cada uma viva, abandonada ou tomada por esporos. **Prédios exploráveis**: piso, paredes nas bordas com portas e janelas, cômodos com móveis e caixas de saque. Ao entrar (ou passar logo atrás), o telhado some e as paredes da frente descem, como no The Sims.
- **Mundo procedural por seed em chunks** (raio 150 tiles; 7 vilas vivas e mais umas 6 abandonadas ou tomadas por esporos, longe umas das outras, no meio de florestas, rios com vaus e pontes, e lagos): só os chunks perto dos jogadores existem como nós. Estradas, caravanas e **vilas vivas** com NPCs (comerciante, guardas, moradores), prosperidade, reputação, comércio e **pedidos de socorro** com prazo; vilas ignoradas caem e viram zonas mortas.
- **Construção estilo The Sims** ([B], 3 abas): pisos nas células e paredes, janelas e portas nas bordas; Utilidades (bancada, mesa de reparos, dínamo a vapor e cata-vento com mastro de 1 a 5 módulos, acumuladores, exaustor purificador, torre de engrenagens, vedação pneumática, coletor de chuva, canteiro, baú, cama) e Decoração (luzes e móveis).
- **Rede elétrica experimental** por produção e consumo, com prioridade e acumuladores.
- **Dia/noite e clima**: chuva, tempestade, névoa de esporos e vento, que afetam a visão dos infectados, o barulho, os eólicos, a agricultura e a iluminação.
- **Persistência de deltas**: só construções, terreno, caixas saqueadas, baús, cadáveres, elites, vilas e legado vão para o save (saves da versão anterior são convertidos).

## Console de testes (cheats)
`F1` ou `` ` `` abre o terminal (pausa o jogo). Digite `ajuda`. Comandos: `dar <item> [qtd]`, `dano <n>` (ou `dano perna 1|2`), `spawn [normal|elite] [n]`, `tp <x> <y>` (ou `abrigo`, `vila <n>`, `borda`, `cadaver`, `elite`), `set` (patogeno, vida, sangramento, calorias, agua, bateria, filtro, calor, estamina), `skill`, `curar`, `restaurar`, `implante`, `god`, `matar`, `infectar`, `limpar`, `pos`, `salvar`. Códigos prontos: `kit`, `kit_medico`, `kit_build`, `kit_cyber`. Tab completa, ↑↓ navega no histórico.

## Arte
O pacote FreeSample define o padrão visual ([`assets/art/STYLE.md`](assets/art/STYLE.md)). Todo o resto é gerado por código no mesmo padrão: personagens, construções, caixas, paredes de prédio (5 materiais x 7 variações, inteiras e baixas), telhados, móveis, objetos de cenário, 22 tipos de chão e os ícones. A prancha com todas as texturas fica em [`docs/texturas.png`](docs/texturas.png). A interface (HUD, menu, título, tela de morte) é pixel art steampunk (madeira, latão e cobre) gerada por `tools/gen_ui.py`, com a fonte Jersey 10 (OFL). Detalhes e como regerar em [`assets/art/README.md`](assets/art/README.md).

## Estrutura
```
autoload/   input_setup.gd (ações) · net.gd (sessão co-op, ENet, replicação) · game.gd (mensagens, save, legado, debug)
scripts/data/      db.gd (itens, próteses, construções) · items.gd (instâncias e listas de itens) · survivor_data.gd (toda a lógica de sobrevivência)
scripts/world/     world.gd (mundo, spawn, vilas, construção, morte) · map_gen.gd (cidades, aldeias, prédios exploráveis) · village_data.gd
scripts/entities/  structure · infected · npc · vehicle · corpse · loot_container · caravan · build_ghost · shot_fx
scripts/player/    player.gd
scripts/ui/        hud.gd (layout) · ui_theme.gd (cores, fonte, tema) · pixel_bar.gd · scan_overlay.gd · dev_console.gd
tools/             setup.sh · screenshot.sh/.gd (prints headless) · gen_art.py, art_models.py, art_render.py (arte gerada) · build_art_catalog.py
scripts/art/       art_db.gd + art_catalog.gd (pacote) · gen_art.gd + gen_catalog.gd (arte gerada)
```

## Ferramentas de desenvolvimento (Linux sem monitor)
```bash
tools/setup.sh
tools/screenshot.sh saida.png --frames=90 --debug="5:give:metal,10;20:tab:3"
godot --headless --path . -s res://tools/test_logic.gd   # lógica do sobrevivente (inventário, criação, próteses...)
godot --headless --path . res://tools/test_world.tscn    # geração do mundo e vilas
```
