class_name CharArt
extends RefCounted
## Personagem do jogador montado por camadas (arte do PixelLab): corpo no tom de pele,
## barba, cabelo e máscara. As folhas ficam em assets/art/characters/ (geradas por
## tools/bake_char_layers.py): 64x64, coluna 0 = parado, 1-8 = andar, linhas na ordem do
## enum Facing do jogador (E, SE, S, SW, W, NW, N, NE). Cabelo e pelos da barba são cinza e
## são tingidos com a cor do cabelo (modulate).
##
## A aparência é um dicionário {sexo, pele, cabelo, cor, barba} (índices nas listas abaixo)
## e viaja na rede como um inteiro (encode/decode).

const DIR := "res://assets/art/characters/"
const CELL := 64
const FOOT := Vector2(32, 62)
const WALK_FRAMES := 8

const SEXOS := ["homem", "mulher"]
const SEXO_NOMES := ["Homem", "Mulher"]
const PELES := ["clara", "media", "morena", "escura"]
const PELE_NOMES := ["Clara", "Média", "Morena", "Escura"]
## "" = careca
const CABELOS := ["curto", "medio", "longo", "coque", "moicano", "raspado", ""]
const CABELO_NOMES := ["Curto", "Médio", "Longo", "Coque", "Moicano", "Raspado", "Careca"]
## "" = barba por fazer (do próprio corpo); "sem" = barbeado
const BARBAS := ["", "sem", "cheia", "bigode", "cavanhaque"]
const BARBA_NOMES := ["Por fazer", "Barbeado", "Cheia", "Bigode", "Cavanhaque"]
const CORES := [Color("#2a2024"), Color("#4a3022"), Color("#6e4428"), Color("#9a6a3a"), Color("#c89a52"),
	Color("#e2c88a"), Color("#9a3a24"), Color("#c25a2a"), Color("#8a8a90"), Color("#e8e6e2"),
	Color("#3a5a6a"), Color("#6a3a6a")]
const COR_NOMES := ["Preto", "Castanho-escuro", "Castanho", "Castanho-claro", "Loiro-escuro", "Loiro",
	"Ruivo-escuro", "Ruivo", "Grisalho", "Branco", "Azul (tinta)", "Roxo (tinta)"]

static var _tex := {}


static func default_visual() -> Dictionary:
	return {"sexo": 0, "pele": 0, "cabelo": 0, "cor": 1, "barba": 0}


static func random_visual(r: RandomNumberGenerator) -> Dictionary:
	var sexo := r.randi() % 2
	return {"sexo": sexo, "pele": r.randi() % PELES.size(),
		"cabelo": r.randi() % (CABELOS.size() - 1) if sexo == 1 else r.randi() % CABELOS.size(),
		"cor": r.randi() % 10, "barba": 0 if sexo == 1 else r.randi() % BARBAS.size()}


## Aparência válida (índices dentro das listas; mulher sem barba).
static func clean(v: Variant) -> Dictionary:
	var d := default_visual()
	if v is Dictionary:
		for k in d:
			d[k] = int((v as Dictionary).get(k, d[k]))
	d["sexo"] = clampi(d["sexo"], 0, SEXOS.size() - 1)
	d["pele"] = clampi(d["pele"], 0, PELES.size() - 1)
	d["cabelo"] = clampi(d["cabelo"], 0, CABELOS.size() - 1)
	d["cor"] = clampi(d["cor"], 0, CORES.size() - 1)
	d["barba"] = 0 if d["sexo"] == 1 else clampi(d["barba"], 0, BARBAS.size() - 1)
	return d


static func encode(v: Dictionary) -> int:
	var d := clean(v)
	return 1 + int(d["sexo"]) + (int(d["pele"]) << 1) + (int(d["cabelo"]) << 3) + (int(d["barba"]) << 6) + (int(d["cor"]) << 9)


static func decode(code: int) -> Dictionary:
	if code <= 0:
		return default_visual()
	code -= 1
	return clean({"sexo": code & 1, "pele": (code >> 1) & 3, "cabelo": (code >> 3) & 7,
		"barba": (code >> 6) & 7, "cor": (code >> 9) & 15})


static func _t(file: String) -> Texture2D:
	if not _tex.has(file):
		var path := DIR + file + ".png"
		_tex[file] = load(path) if ResourceLoader.exists(path) else null
	return _tex[file]


## Camadas na ordem de desenho: [textura, cor].
static func layers(v: Dictionary, masked: bool) -> Array:
	var d := clean(v)
	var sexo: String = SEXOS[d["sexo"]]
	var pele: String = PELES[d["pele"]]
	var cor: Color = CORES[d["cor"]]
	var out: Array = [[_t("corpo_%s_%s" % [sexo, pele]), Color.WHITE]]
	var barba: String = BARBAS[d["barba"]]
	if barba != "":
		out.append([_t("barba_%s_%s" % [barba, pele]), Color.WHITE])
		if barba != "sem":
			out.append([_t("barba_%s" % barba), cor])
	if masked:
		out.append([_t("mascara_%s" % sexo), Color.WHITE])
	var cabelo: String = CABELOS[d["cabelo"]]
	if cabelo != "":
		out.append([_t("cabelo_%s_%s" % [sexo, cabelo]), cor])
	return out


## Desenha o personagem com o pé em 'at'. col: 0 = parado, 1-8 = quadro do andar.
static func draw(ci: CanvasItem, v: Dictionary, facing: int, col: int, at := Vector2.ZERO,
		tint := Color.WHITE, masked := false) -> void:
	var src := Rect2(col * CELL, facing * CELL, CELL, CELL)
	var dst := Rect2(at - FOOT, Vector2(CELL, CELL))
	for l in layers(v, masked):
		if l[0] != null:
			ci.draw_texture_rect_region(l[0], dst, src, (l[1] as Color) * tint)


## Coluna da folha para o estado: andando (tempo da animação) ou parado.
static func frame_col(moving: bool, anim_t: float) -> int:
	if moving:
		return 1 + int(anim_t * 10.0) % WALK_FRAMES
	return 0


## Prévia da criação de personagem: um Control que desenha a aparência girando.
class Preview extends Control:
	var visual := {}
	var zoom := 3.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2(size.x / 2.0, size.y - 10.0), 0.0, Vector2(zoom, zoom))
		var turn := [2, 1, 0, 7, 6, 5, 4, 3]
		var facing: int = turn[int(_t / 1.2) % 8]
		CharArt.draw(self, visual, facing, CharArt.frame_col(true, _t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
