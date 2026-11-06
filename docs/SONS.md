# Sons do Esporos

Todos os sons do jogo passam por uma tabela só: **`autoload/sfx_table.gd`**. Para trocar
qualquer som, siga um destes caminhos:

1. Substitua o arquivo em `assets/audio/` por outro com **o mesmo nome**. Pode ser `.wav`;
   se for `.ogg`, mude também a extensão na tabela.
2. Ou ponha o arquivo novo em `assets/audio/` e mude o campo `arquivo` do evento na tabela.

Na tabela, cada evento tem quatro campos:

| Campo | O que faz |
|---|---|
| `arquivo` | Caminho do áudio (`res://assets/audio/...`). |
| `vol` | Volume em dB: 0 é normal, -6 é metade, +3 é mais alto. |
| `var` | Variação aleatória de tom a cada vez (0,1 = ±10%), para não soar repetido. |
| `dist` | Até onde se ouve, em pixels do mundo. Só vale para sons que acontecem num lugar. |

Os sons atuais são **provisórios**: foram gerados por síntese em `tools/gen_sfx.py`. Rodar
esse script de novo **sobrescreve** os arquivos de `assets/audio/` com os nomes abaixo.
Depois de trocar por sons definitivos, não rode mais o script, ou apague dele os sons que já
foram trocados. Evento sem arquivo fica mudo, sem erro.

O código toca os sons de três formas:
- `Sfx.play_at("nome", posição)`: som num lugar. O volume cai com a distância.
- `Sfx.play("nome")`: som sem posição, como a interface e as coisas do próprio jogador.
- `Sfx.loop("nome", nó, ligado)`: som contínuo, como a chuva, o dínamo e o motor.

O servidor espalha os sons do mundo com `World.sfx_at()`, então todos os jogadores ouvem.

## Lista de eventos

### Personagem
| Evento | Quando toca |
|---|---|
| `passo` | Andando ou correndo (agachado não faz som). |
| `golpe_ar` | Ataque corpo a corpo (o movimento). |
| `golpe_acerto` | O golpe corpo a corpo acertou. |
| `empurrao` | Empurrão (tecla F) acertou alguém. |
| `dor` | O personagem levou um golpe. |
| `queda` | Pulou da janela de um andar alto. |
| `comer`, `beber` | Comeu ou bebeu. |
| `curativo` | Usou um item médico ou tratou um membro. |

### Armas
| Evento | Quando toca |
|---|---|
| `tiro_pistola`, `tiro_espingarda` | Tiro do jogador ou de um saqueador. |
| `torre_tiro` | Tiro da torre automatizada. |
| `recarregar` | Recarregando. |
| `sem_municao` | Tentou atirar sem munição. |

### Infectados e saqueadores
| Evento | Quando toca |
|---|---|
| `infectado_gemido` | De tempos em tempos, de cada infectado. |
| `infectado_ataque` | O infectado bateu (em gente, muro ou barricada). |
| `infectado_morre` | O infectado morreu. |
| `chamador_grito` | O chamador se encolheu e gritou chamando os outros. |
| `explosao_esporos` | A bolha de esporos estourou. |
| `saqueador_grito` | O saqueador ferido começa a fugir. |

### Casas, portas, janelas e barricadas
| Evento | Quando toca |
|---|---|
| `porta_abre`, `porta_fecha` | Abriu ou fechou uma porta. |
| `porta_golpe` | Infectado batendo numa porta fechada. |
| `porta_arrombada` | A porta cedeu. |
| `vidro_quebra` | Quebrou uma janela. |
| `barricada_golpe` | Infectado batendo na barricada. |
| `barricada_quebra` | A barricada caiu. |
| `construir` | Construiu algo, inclusive a barricada. |
| `escada` | Subiu ou desceu uma escada. |
| `abrir_gaveta` | Abriu um móvel, caixa ou baú. |
| `pegar_item` | Pegou itens de um recipiente. |
| `fechadura_tenta` | Começou a forçar uma fechadura. |
| `fechadura_abre` | A fechadura abriu (com a chave ou forçando). |
| `fabricar` | Terminou uma receita. |

### Interface
| Evento | Quando toca |
|---|---|
| `ui_clique` | Clicou num botão do menu ou de uma janela. |
| `ui_alerta` | Reservado para avisos importantes. |

### Ambiente e máquinas (contínuos)
| Evento | Quando toca |
|---|---|
| `chuva` | Enquanto chove. Fica mais baixo dentro de prédio e não toca nos andares de cima. |
| `vento` | Na tempestade ou com vento forte. |
| `trovao` | De vez em quando, na tempestade. |
| `gerador_loop` | Dínamo a vapor funcionando (caldeira acesa). |
| `purificador_loop` | Purificador ligado. |
| `motor_loop` | Veículo com motorista; o volume sobe com a velocidade. |
| `sirene` | Uma horda ou um bando de saqueadores começou a atacar uma vila. |
