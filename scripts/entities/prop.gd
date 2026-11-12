class_name Prop
extends Node2D
## Objeto de cenário. O nó fica no ponto de apoio no chão (chave de ordenação em profundidade).
## Fontes: "fs" = pacote FreeSample (4 vistas, ArtDB); "gen" = kit gerado no mesmo padrão
## (folha c_<nome> no GenCatalog; grupo, raio e quadros no CityCatalog.PROPS).
## Objetos com raio > 0 bloqueiam a passagem. Postes e letreiros acendem à noite.

var art := ""
var variant := 0
var source := "gen"

var _light: PointLight2D
var _lit_t := 0.0
## Árvores ficam translúcidas quando o jogador passa por trás delas (para não sumir na floresta).
const TREES := ["arvore", "pinheiro", "arvore_morta", "arvore_rua"]
var _tree := false
var _fade_t := 0.0
const LAMPS := {"poste_rua": [Color(1.0, 0.95, 0.85), 2.0, -80.0], "poste_neon": [Color(1.0, 0.72, 0.38), 1.6, -60.0],
	"tambor_fogo": [Color(1.0, 0.6, 0.3), 1.3, -24.0]}


func _ready() -> void:
	if source == "fs":
		add_child(ArtDB.sprite(art, variant, "base"))
		return
	var meta: Dictionary = CityCatalog.PROPS.get(art, {})
	_add_collision(int(meta.get("raio", 0)))
	if art == "cama":
		add_to_group("interactable")
		add_to_group("beds")
	elif art == "tambor_fogo":
		add_to_group("heat")
	if LAMPS.has(art) and variant == 0:
		var l: Array = LAMPS[art]
		_light = PointLight2D.new()
		_light.texture = World.light_texture()
		_light.color = l[0]
		_light.texture_scale = float(l[1])
		_light.position = Vector2(0, float(l[2]))
		_light.enabled = false
		add_child(_light)
		set_process(true)
	elif art in TREES:
		_tree = true
		_fade_t = randf() * 0.2
		set_process(true)
	else:
		set_process(false)


func prompt() -> String:
	return "[E] Dormir" if art == "cama" else ""


func options(_p: Player) -> Array:
	return [{"id": "dormir", "txt": "Dormir", "ok": true}] if art == "cama" else []


## Dormir é pedido pelo jogador (Player); aqui não há o que fazer.
func interact(_p: Player) -> void:
	pass


func _process(delta: float) -> void:
	if _tree:
		_fade_t -= delta
		if _fade_t <= 0.0:
			_fade_t = 0.12
			var want := 1.0
			var lp: Player = Game.world.local_player() if Game.world != null else null
			if lp != null:
				var off := lp.position - position
				# o jogador está atrás do tronco/copa: acima do pé da árvore e dentro da largura dela
				if off.y < 2.0 and off.y > -70.0 and absf(off.x) < 22.0:
					want = 0.4
			if not is_equal_approx(modulate.a, want):
				modulate.a = move_toward(modulate.a, want, 0.2)
		return
	if _light == null:
		set_process(false)
		return
	_lit_t -= delta
	if _lit_t > 0.0:
		return
	_lit_t = 1.0
	var w := Game.world
	if w == null:
		return
	var dk := w.darkness()
	_light.enabled = dk > 0.05
	_light.energy = 0.75 * dk


func _draw() -> void:
	if source != "gen":
		return
	var sheet := "c_" + art
	if GenCatalog.SHEETS.has(sheet):
		GenArt.draw_frame(self, sheet, 0, variant)


func _add_collision(radius: int) -> void:
	if radius <= 0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	body.add_child(shape)
	add_child(body)
