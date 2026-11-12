class_name Animal
extends CharacterBody2D
## Animal de caça: veado, javali e coelho. Pasta e anda pelo campo; foge de gente, de
## infectados e de barulho (tiros). Chegar agachado ou atirar de longe é o jeito de caçar.
## O javali ferido investe contra quem o atacou. Ao morrer deixa uma carcaça com carne crua
## e couro. O servidor move; os clientes interpolam.
## (No futuro: animais infectados e hostis — basta um KINDS com "hostil".)

const SHEET := "res://assets/art/generated/animals/animals.png"
const CELL := Vector2(48, 44)
const FOOT := Vector2(24, 40)
## vida; velocidades andando e fugindo; "ve": distância (px iso) em que nota alguém andando;
## carne e couro: [mín, máx]; "ataque": dano da investida (0 = nunca ataca).
const KINDS := {
	"veado": {"linha": 0, "nome": "Veado", "vida": 30.0, "vel": 26.0, "fuga": 150.0, "ve": 200.0, "carne": [2, 3], "couro": [2, 2], "ataque": 0.0},
	"javali": {"linha": 1, "nome": "Javali", "vida": 48.0, "vel": 24.0, "fuga": 112.0, "ve": 150.0, "carne": [3, 4], "couro": [1, 2], "ataque": 9.0},
	"coelho": {"linha": 2, "nome": "Coelho", "vida": 8.0, "vel": 30.0, "fuga": 135.0, "ve": 130.0, "carne": [1, 1], "couro": [0, 1], "ataque": 0.0},
}
## Sorteio do animal ao nascer: [tipo, peso, tamanho mínimo e máximo do grupo].
const ODDS := [["coelho", 40, 1, 2], ["veado", 38, 1, 3], ["javali", 22, 1, 2]]

var kind := "veado"
var world: World
var hp := 30.0
var max_hp := 30.0

# ---- replicado pelo servidor
var net_pos := Vector2.ZERO
var flip := false
var moving := false
## 0 pastando/andando, 1 fugindo, 2 investindo (javali).
var state := 0

var _goal := Vector2.ZERO
var _wander_t := 0.0
var _flee_t := 0.0
var _flee_from := Vector2.ZERO
var _look_t := 0.0
var _target: Node2D
var _cd := 0.0
var _anim_t := 0.0
var _flash := 0.0
var _seen_hp := -1.0
var _stuck_t := 0.0

static var _tex: Texture2D


func setup_net() -> void:
	net_pos = position
	Net.make_sync(self, [".:net_pos", ".:flip", ".:moving", ".:state", ".:hp"], 0.08)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("animals")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0 if kind != "coelho" else 3.0
	shape.shape = circle
	add_child(shape)
	max_hp = float(KINDS[kind]["vida"])
	if _seen_hp < 0.0:
		_seen_hp = hp
	_goal = position
	net_pos = position
	_wander_t = randf_range(0.5, 4.0)
	if _tex == null:
		_tex = load(SHEET)


func def() -> Dictionary:
	return KINDS[kind]


static func roll(r: RandomNumberGenerator) -> Array:
	var total := 0
	for e in ODDS:
		total += int(e[1])
	var roll_ := r.randi() % total
	for e in ODDS:
		roll_ -= int(e[1])
		if roll_ < 0:
			return [String(e[0]), r.randi_range(int(e[2]), int(e[3]))]
	return ["coelho", 1]


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if hp < _seen_hp - 0.01:
		_flash = 0.15
	_seen_hp = hp
	visible = world == null or not world.hidden_inside(position)
	if not Net.is_server():
		var before := position
		position = position.lerp(net_pos, clampf(delta * 10.0, 0.0, 1.0))
		if (position - before).length() > 0.05:
			_anim_t += (position - before).length() / 7.0
		queue_redraw()
		return
	_server_ai(delta)
	queue_redraw()


## Servidor: barulho por perto (tiro, golpe) assusta.
func hear(pos: Vector2) -> void:
	if state != 2:
		_scare(pos, 5.0)


func _scare(from: Vector2, time: float) -> void:
	state = 1
	_flee_t = maxf(_flee_t, time)
	_flee_from = from


func _iso(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * 2.0)


## Quem está perto o bastante para assustar (jogador, saqueador ou infectado).
func _threat() -> Vector2:
	var see := float(def()["ve"])
	for p in world.alive_players():
		var d := _iso(p.net_pos - position).length()
		var lim := see * (0.25 if p.sneaking else (1.3 if p.sprinting else 1.0))
		if world.vehicle_of(p.peer) != null:
			lim = see * 1.6
		if d < lim:
			return p.net_pos
	for g in ["infected", "raiders"]:
		for n in get_tree().get_nodes_in_group(g):
			var nd := n as Node2D
			if _iso(nd.position - position).length() < see * 0.6:
				return nd.position
	return Vector2.INF


func _server_ai(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = 0.3
		if state != 2:
			var th := _threat()
			if th != Vector2.INF:
				_scare(th, 3.0)
	var speed := float(def()["vel"])
	var goal := _goal
	if state == 2:
		# javali investindo: vai para cima de quem bateu; desiste se o alvo sumir ou se apanhar muito
		if _target == null or not is_instance_valid(_target) or hp < max_hp * 0.35 \
				or (_target is Player and not (_target as Player).alive):
			_target = null
			_scare(position + Vector2.from_angle(randf() * TAU) * 40.0, 6.0)
		else:
			var tp := (_target as Player).net_pos if _target is Player else _target.position
			goal = tp if _iso(tp - position).length() > 20.0 else position
			speed = float(def()["fuga"])
			if _iso(tp - position).length() < 26.0 and _cd <= 0.0:
				_cd = 1.4
				if _target is Player:
					(_target as Player).server_hurt(float(def()["ataque"]), 0.0)
				elif _target.has_method("take_hit"):
					_target.call("take_hit", float(def()["ataque"]), self)
				world.sfx_at("infectado_ataque", position)
	if state == 1:
		_flee_t -= delta
		if _flee_t <= 0.0:
			state = 0
			_goal = position
			_wander_t = randf_range(2.0, 5.0)
		else:
			var away := _iso(position - _flee_from)
			if away.length() < 1.0:
				away = Vector2.from_angle(randf() * TAU)
			away = away.normalized().rotated(sin(Time.get_ticks_msec() * 0.002 + float(get_instance_id() % 7)) * 0.5)
			goal = position + Vector2(away.x, away.y * 0.5) * 120.0
			speed = float(def()["fuga"])
	elif state == 0:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(3.0, 9.0)
			# metade do tempo fica parado pastando
			_goal = position if randf() < 0.5 else position + Vector2(randf_range(-110, 110), randf_range(-55, 55))
		goal = _goal
	var to := goal - position
	var iso := _iso(to)
	moving = iso.length() > 6.0
	if moving:
		var dir := iso.normalized()
		velocity = Vector2(dir.x, dir.y * 0.5) * speed
		var before := position
		move_and_slide()
		if absf(velocity.x) > 2.0:
			flip = velocity.x < 0.0
		_anim_t += delta * speed / 7.0
		# preso num obstáculo (árvore, margem do rio, cerca): muda de rumo
		if position.distance_to(before) < speed * delta * 0.3:
			_stuck_t += delta
			if _stuck_t > 0.25:
				_stuck_t = 0.0
				if state == 1:
					_flee_from = position + Vector2(velocity.y, -velocity.x).normalized() * 30.0 * (1.0 if randf() < 0.5 else -1.0)
				else:
					_goal = position
		else:
			_stuck_t = 0.0
	net_pos = position


## Servidor: dano (golpe, tiro, atropelamento). Mesmo formato dos infectados.
func take_damage(amount: float, from: Node2D, _stagger := 0.0) -> void:
	if not Net.is_server() or hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		_die()
		return
	var src := position
	if from != null and is_instance_valid(from):
		src = (from as Player).net_pos if from is Player else from.position
	if float(def()["ataque"]) > 0.0 and hp > max_hp * 0.35 and from != null and is_instance_valid(from) \
			and _iso(src - position).length() < 260.0:
		state = 2
		_target = from
	else:
		_scare(src, 7.0)
	# o resto do bando foge junto
	for n in get_tree().get_nodes_in_group("animals"):
		var a := n as Animal
		if a != self and a.state == 0 and _iso(a.position - position).length() < 240.0:
			a._scare(src, 6.0)


func take_hit(amount: float, from: Node2D) -> void:
	take_damage(amount, from)


func _die() -> void:
	var drops: Array = []
	var d := def()
	var meat := world.rng.randi_range(int(d["carne"][0]), int(d["carne"][1]))
	var hide := world.rng.randi_range(int(d["couro"][0]), int(d["couro"][1]))
	if meat > 0:
		Items.add_all(drops, Items.make("carne_crua", meat, -1.0, world.rng))
	if hide > 0:
		Items.add(drops, {"id": "couro", "n": hide})
	world.spawn_net({"t": "corpse", "pos": [position.x, position.y], "nome": String(d["nome"]), "items": drops, "animal": kind})
	queue_free()


func _draw() -> void:
	var small := kind == "coelho"
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 5.0 if small else 11.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	var col := 0
	if moving:
		col = 1 + int(_anim_t) % 3
	var tint := Color.WHITE
	if _flash > 0.0:
		tint = Color(2.0, 2.0, 2.0)
	draw_texture_rect_region(_tex, Rect2(-FOOT, CELL), Rect2(Vector2(col, int(def()["linha"])) * CELL, CELL), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp and hp > 0.0:
		var top := -22.0 if small else -44.0
		draw_rect(Rect2(-9, top, 18, 3), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(-9, top, 18.0 * clampf(hp / max_hp, 0.0, 1.0), 3), Color("#ff5a5f"))
