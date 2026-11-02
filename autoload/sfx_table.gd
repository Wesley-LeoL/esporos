class_name SfxTable
extends RefCounted
## ===================================================================================
##  TABELA DE SONS — é aqui que se troca qualquer som do jogo.
## ===================================================================================
##  Cada evento tem:
##    arquivo  caminho do áudio (.wav ou .ogg) em assets/audio/
##    vol      volume em dB (0 = normal, -6 = metade, +3 = mais alto)
##    var      variação aleatória de tom a cada vez (0 = sempre igual, 0.1 = ±10%)
##    dist     até onde se ouve, em pixels do mundo (só sons que acontecem num lugar)
##  Para trocar um som: ponha o arquivo novo em assets/audio/ e mude "arquivo" aqui (ou
##  substitua o arquivo com o mesmo nome). Lista explicada em docs/SONS.md.
##  Os provisórios foram gerados por tools/gen_sfx.py.

const SOUNDS := {
	# ---- personagem
	"passo": {"arquivo": "res://assets/audio/passo.wav", "vol": -14.0, "var": 0.15, "dist": 420.0},
	"golpe_ar": {"arquivo": "res://assets/audio/golpe_ar.wav", "vol": -8.0, "var": 0.12, "dist": 500.0},
	"golpe_acerto": {"arquivo": "res://assets/audio/golpe_acerto.wav", "vol": -3.0, "var": 0.12, "dist": 600.0},
	"empurrao": {"arquivo": "res://assets/audio/empurrao.wav", "vol": -4.0, "var": 0.1, "dist": 500.0},
	"dor": {"arquivo": "res://assets/audio/dor.wav", "vol": -4.0, "var": 0.1, "dist": 600.0},
	"queda": {"arquivo": "res://assets/audio/queda.wav", "vol": -2.0, "var": 0.05, "dist": 700.0},
	"comer": {"arquivo": "res://assets/audio/comer.wav", "vol": -6.0, "var": 0.1},
	"beber": {"arquivo": "res://assets/audio/beber.wav", "vol": -6.0, "var": 0.1},
	"curativo": {"arquivo": "res://assets/audio/curativo.wav", "vol": -8.0, "var": 0.1},
	# ---- armas
	"tiro_pistola": {"arquivo": "res://assets/audio/tiro_pistola.wav", "vol": 0.0, "var": 0.06, "dist": 1600.0},
	"tiro_espingarda": {"arquivo": "res://assets/audio/tiro_espingarda.wav", "vol": 1.0, "var": 0.05, "dist": 1800.0},
	"torre_tiro": {"arquivo": "res://assets/audio/torre_tiro.wav", "vol": -3.0, "var": 0.08, "dist": 1200.0},
	"recarregar": {"arquivo": "res://assets/audio/recarregar.wav", "vol": -6.0, "var": 0.05},
	"sem_municao": {"arquivo": "res://assets/audio/sem_municao.wav", "vol": -6.0, "var": 0.05, "dist": 400.0},
	# ---- infectados e saqueadores
	"infectado_gemido": {"arquivo": "res://assets/audio/infectado_gemido.wav", "vol": -10.0, "var": 0.2, "dist": 650.0},
	"infectado_ataque": {"arquivo": "res://assets/audio/infectado_ataque.wav", "vol": -4.0, "var": 0.15, "dist": 600.0},
	"infectado_morre": {"arquivo": "res://assets/audio/infectado_morre.wav", "vol": -4.0, "var": 0.15, "dist": 700.0},
	"chamador_grito": {"arquivo": "res://assets/audio/chamador_grito.wav", "vol": 2.0, "var": 0.05, "dist": 2000.0},
	"explosao_esporos": {"arquivo": "res://assets/audio/explosao_esporos.wav", "vol": 0.0, "var": 0.08, "dist": 900.0},
	"saqueador_grito": {"arquivo": "res://assets/audio/saqueador_grito.wav", "vol": -3.0, "var": 0.12, "dist": 900.0},
	# ---- casa, portas, janelas, barricadas
	"porta_abre": {"arquivo": "res://assets/audio/porta_abre.wav", "vol": -6.0, "var": 0.1, "dist": 600.0},
	"porta_fecha": {"arquivo": "res://assets/audio/porta_fecha.wav", "vol": -5.0, "var": 0.1, "dist": 600.0},
	"porta_golpe": {"arquivo": "res://assets/audio/porta_golpe.wav", "vol": -3.0, "var": 0.12, "dist": 900.0},
	"porta_arrombada": {"arquivo": "res://assets/audio/porta_arrombada.wav", "vol": 0.0, "var": 0.05, "dist": 1100.0},
	"vidro_quebra": {"arquivo": "res://assets/audio/vidro_quebra.wav", "vol": 0.0, "var": 0.08, "dist": 1300.0},
	"barricada_golpe": {"arquivo": "res://assets/audio/barricada_golpe.wav", "vol": -3.0, "var": 0.12, "dist": 900.0},
	"barricada_quebra": {"arquivo": "res://assets/audio/barricada_quebra.wav", "vol": 0.0, "var": 0.05, "dist": 1100.0},
	"construir": {"arquivo": "res://assets/audio/construir.wav", "vol": -4.0, "var": 0.1, "dist": 800.0},
	"escada": {"arquivo": "res://assets/audio/escada.wav", "vol": -6.0, "var": 0.1, "dist": 400.0},
	"abrir_gaveta": {"arquivo": "res://assets/audio/abrir_gaveta.wav", "vol": -6.0, "var": 0.15},
	"pegar_item": {"arquivo": "res://assets/audio/pegar_item.wav", "vol": -8.0, "var": 0.15},
	"fechadura_tenta": {"arquivo": "res://assets/audio/fechadura_tenta.wav", "vol": -6.0, "var": 0.1, "dist": 500.0},
	"fechadura_abre": {"arquivo": "res://assets/audio/fechadura_abre.wav", "vol": -4.0, "var": 0.05, "dist": 500.0},
	"fabricar": {"arquivo": "res://assets/audio/fabricar.wav", "vol": -6.0, "var": 0.1, "dist": 500.0},
	# ---- interface
	"ui_clique": {"arquivo": "res://assets/audio/ui_clique.wav", "vol": -12.0, "var": 0.05},
	"ui_alerta": {"arquivo": "res://assets/audio/ui_alerta.wav", "vol": -6.0, "var": 0.0},
	# ---- ambiente e máquinas (tocam em laço enquanto acontecem)
	"chuva": {"arquivo": "res://assets/audio/chuva.wav", "vol": -10.0, "var": 0.0},
	"vento": {"arquivo": "res://assets/audio/vento.wav", "vol": -12.0, "var": 0.0},
	"trovao": {"arquivo": "res://assets/audio/trovao.wav", "vol": -2.0, "var": 0.15},
	"gerador_loop": {"arquivo": "res://assets/audio/gerador_loop.wav", "vol": -8.0, "var": 0.0, "dist": 420.0},
	"purificador_loop": {"arquivo": "res://assets/audio/purificador_loop.wav", "vol": -12.0, "var": 0.0, "dist": 300.0},
	"motor_loop": {"arquivo": "res://assets/audio/motor_loop.wav", "vol": -6.0, "var": 0.0, "dist": 700.0},
	"sirene": {"arquivo": "res://assets/audio/sirene.wav", "vol": -2.0, "var": 0.0, "dist": 2400.0},
}
