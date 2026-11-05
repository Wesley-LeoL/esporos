class_name Raider
extends CharacterBody2D
## Saqueador humano. Acampa em prédios abandonados, patrulha e ataca vilas prósperas
## (rouba o estoque e mata moradores). Com arma de fogo, atira de longe e mantém distância;
## com arma branca, chega perto e prepara o golpe como os infectados. Foge quando está muito
## ferido. Luta com jogadores, moradores e infectados (que também o caçam). O servidor move;
## os clientes interpolam.

const WEAPONS := {
	"pistola": {"alcance": 320.0, "dano": 13.0, "cadencia": 1.1, "mira": 0.55, "ruido": 800.0},
	"espingarda": {"alcance": 200.0, "dano": 22.0, "cadencia": 1.8, "mira": 0.6, "ruido": 900.0},
	"faca": {"alcance": 28.0, "dano": 11.0, "cadencia": 1.2, "mira": 1.0, "ruido": 0.0},
	"taco": {"alcance": 30.0, "dano": 14.0, "cadencia": 1.5, "mira": 1.0, "ruido": 0.0},
}

var weapon := "pistola"
var home := Vector2.ZERO
## Vila que este bando está assaltando (-1 = nenhuma) e acampamento (prédio; -1 = nenhum).
var raid_vid := -1
var camp := -1
var world: World

# ---- replicado pelo servidor
var net_pos := Vector2.ZERO
var facing := 2
var moving := false
var atk_seq := 0
var hp := 70.0
var max_hp := 70.0
var phase := 0

var _cd := 0.0
var _prep_t := 0.0
var _target: Node2D
var _goal := Vector2.ZERO
var _wander_t := 0.0
var _anim_t := 0.0
var _atk_anim := 0.0
var _seen_atk := 0
var _flash := 0.0
var _seen_hp := 70.0
var _loot_t := 0.0
var _fleeing := false
var _wall_k := Vector3i(0, 0, -1)
var _path_t := 0.0


func setup_net() -> void:
	net_pos = position
	Net.make_sync(self, [".:net_pos", ".:facing", ".:moving", ".:atk_seq", ".:hp", ".:phase"], 0.08)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("raiders")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	if home == Vector2.ZERO:
		home = position
	_goal = position
	net_pos = position
	_seen_hp = hp


func ranged() -> bool:
	return float(WEAPONS[weapon]["alcance"]) > 60.0


func _physics_process(delta: float) -> void:
	_atk_anim = maxf(0.0, _atk_anim - delta)
	_flash = maxf(0.0, _flash - delta)
	if atk_seq != _seen_atk:
		_seen_atk = atk_seq
		_atk_anim = 0.4
	if hp < _seen_hp - 0.01:
		_flash = 0.15
	_seen_hp = hp
	visible = not world.hidden_inside(position)
	if not Net.is_server():
		var before := position
		position = position.lerp(net_pos, clampf(delta * 10.0, 0.0, 1.0))
		if (position - before).length() > 0.05:
			_anim_t += (position - before).length() / 9.0
		queue_redraw()
		return
	_server_ai(delta)
	queue_redraw()


## Servidor: dano (de jogador, morador, torre ou infectado).
func take_hit(amount: float, from: Node2D) -> void:
	if not Net.is_server() or hp <= 0.0:
		return
	hp -= amount
	if from != null and is_instance_valid(from) and not from is Structure:
		_target = from
	_prep_t = 0.0
	phase = 0
	if hp <= 0.0:
		_die(from)
	elif hp < max_hp * 0.25 and not _fleeing and randf() < 0.6:
		_fleeing = true
		world.sfx_at("saqueador_grito", position)


## Mesmo formato do Infected (guardas e torres chamam take_damage).
func take_damage(amount: float, from: Node2D, _stagger := 0.35) -> void:
	take_hit(amount, from)


func _die(from: Node2D) -> void:
	var drops: Array = []
	Items.add(drops, Items.make(weapon, 1, -1.0, world.rng)[0])
	if weapon == "pistola":
		Items.add(drops, {"id": "municao_9mm", "n": world.rng.randi_range(2, 9)})
	elif weapon == "espingarda":
		Items.add(drops, {"id": "cartucho_12", "n": world.rng.randi_range(1, 4)})
	Items.add_all(drops, DB.roll_loot("comum", world.rng.randi_range(1, 3), world.rng))
	if world.rng.randf() < 0.25:
		Items.add_all(drops, DB.roll_loot("armario", 1, world.rng))
	world.spawn_net({"t": "corpse", "pos": [position.x, position.y], "nome": "Saqueador", "items": drops})
	world.raider_died(self, from)
	queue_free()


func _pos_of(n: Node2D) -> Vector2:
	return (n as Player).net_pos if n is Player else n.position


func _dist(n: Node2D) -> float:
	var off := _pos_of(n) - position
	return Vector2(off.x, off.y * 2.0).length()


## Quem atacar: jogador à vista, morador (num assalto) ou infectado perto demais.
func _pick_target() -> Node2D:
	var best: Node2D = null
	var bd := 1e9
	for p in world.alive_players():
		if p.data == null:
			continue
		var sight := 300.0 * p.data.visibility(p.sprinting, p.sneaking) * world.sight_factor(p)
		var d := _dist(p)
		if (d < sight or p == _target) and d < bd and d < 480.0:
			bd = d
			best = p
	if raid_vid >= 0:
		for n in get_tree().get_nodes_in_group("npcs"):
			var npc := n as Npc
			if npc.village_id == raid_vid and npc.hp > 0.0 and _dist(npc) < bd and _dist(npc) < 360.0:
				bd = _dist(npc)
				best = npc
	for n in get_tree().get_nodes_in_group("infected"):
		var d2 := _dist(n as Node2D)
		if d2 < 200.0 and d2 < bd * 0.8:
			bd = d2
			best = n as Node2D
	return best


func _server_ai(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	_path_t = maxf(0.0, _path_t - delta)
	if _target != null and (not is_instance_valid(_target) or float(_target.get("hp") if not _target is Player else 1.0) <= 0.0):
		_target = null
	var target := _pick_target()
	if target != null:
		_target = target
	var speed := 58.0
	var goal := _goal
	# fugindo: corre para longe de quem está batendo
	if _fleeing and _target != null:
		var away := position - _pos_of(_target)
		goal = position + Vector2(away.x, away.y * 2.0).normalized() * Vector2(1, 0.5) * 120.0
		speed = 82.0
		if _dist(_target) > 700.0:
			queue_free()  # sumiu de vez
			return
	elif _target != null:
		var d := _dist(_target)
		var w: Dictionary = WEAPONS[weapon]
		facing = GenArt.facing_of(_pos_of(_target) - position)
		if _prep_t > 0.0:
			# golpe preparado (arma branca)
			_prep_t -= delta
			velocity = Vector2.ZERO
			if _prep_t <= 0.0:
				phase = 0
				atk_seq += 1
				_cd = float(w["cadencia"])
				if d < float(w["alcance"]) + 8.0:
					_hit(_target, float(w["dano"]))
			moving = false
			net_pos = position
			return
		if ranged():
			if d < float(w["alcance"]) and _cd <= 0.0:
				_shoot(_target, w)
			# mantém distância: recua se o alvo chega perto, avança se está longe
			if d < 90.0:
				var back := position - _pos_of(_target)
				goal = position + Vector2(back.x, back.y * 2.0).normalized() * Vector2(1, 0.5) * 60.0
			elif d > float(w["alcance"]) * 0.8:
				goal = _pos_of(_target)
			else:
				goal = position
		else:
			goal = _pos_of(_target)
			speed = 70.0
			if d < float(w["alcance"]) and _cd <= 0.0:
				_prep_t = 0.5
				phase = 1
	elif raid_vid >= 0:
		goal = _raid_goal(delta)
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(3.0, 7.0)
			_goal = home + Vector2(randf_range(-160, 160), randf_range(-80, 80))
		goal = _goal
		speed = 34.0
	var to := goal - position
	var iso := Vector2(to.x, to.y * 2.0)
	moving = iso.length() > 8.0
	if moving:
		var dir := iso.normalized()
		velocity = Vector2(dir.x, dir.y * 0.5) * speed
		move_and_slide()
		if _target == null or _fleeing:
			facing = GenArt.facing_of(velocity)
		_anim_t += delta * speed / 9.0
		if get_slide_collision_count() > 0 and _target == null and raid_vid < 0:
			_goal = position
	net_pos = position


## Assalto: atravessa a cerca (portão aberto, brecha ou derrubando um trecho), vai ao centro
## e rouba o estoque; depois foge.
func _raid_goal(delta: float) -> Vector2:
	var v: VillageData = world.villages[raid_vid]
	var center := world.ground.map_to_local(v.cell)
	if v.infested:
		raid_vid = -1
		return home
	if world.village_at(position) != raid_vid:
		if _path_t <= 0.0:
			_path_t = 1.0
			_wall_k = world.fence_goal(raid_vid, position)
		if _wall_k.z >= 0:
			var wp := world.edge_pos(_wall_k)
			if world.fence_open(_wall_k):
				return wp if position.distance_to(wp) > 14.0 else center
			if world.edge_dist(_wall_k, position) < 26.0:
				if _cd <= 0.0:
					_cd = 1.2
					atk_seq += 1
					world.damage_fence(_wall_k, 12.0, "saqueadores")
				return position
			return wp
		return center
	if position.distance_to(center) < 90.0:
		_loot_t += delta
		if _loot_t > 8.0:
			world.village_robbed(raid_vid)
			raid_vid = -1
			_fleeing = true
			_target = world.nearest_player(position, 2000.0)
			if _target == null:
				queue_free()
	return center


func _hit(t: Node2D, dmg: float) -> void:
	if t is Player:
		var limbs: Array = ["torso", "torso", "braco_e", "braco_d", "perna_e", "perna_d", "cabeca"]
		(t as Player).server_hurt(limbs[randi() % limbs.size()], dmg * randf_range(0.8, 1.2), 0.0)
	elif t.has_method("take_damage") and t is Infected:
		(t as Infected).take_damage(dmg, self, 0.3)
	elif t.has_method("take_hit"):
		t.take_hit(dmg, self)


func _shoot(t: Node2D, w: Dictionary) -> void:
	_cd = float(w["cadencia"]) * randf_range(0.9, 1.3)
	atk_seq += 1
	var d := _dist(t)
	var chance := float(w["mira"]) * (1.0 - 0.5 * d / float(w["alcance"]))
	if t is Player and (t as Player).sneaking:
		chance *= 0.8
	var tp := _pos_of(t)
	var hit := randf() < chance
	var end := tp + (Vector2.ZERO if hit else Vector2(randf_range(-30, 30), randf_range(-15, 15)))
	world.shot_fx.rpc(position + Vector2(0, -16), PackedVector2Array([end + Vector2(0, -14)]))
	world.make_noise(position, float(w["ruido"]))
	world.sfx_at("tiro_pistola" if weapon == "pistola" else "tiro_espingarda", position)
	if hit:
		_hit(t, float(w["dano"]))


func _frame() -> int:
	var anims := GenCatalog.SURVIVOR_ANIMS
	if _atk_anim > 0.0 or phase == 1:
		var a: Array = anims["attack"]
		return a[clampi(int((1.0 - _atk_anim / 0.4) * a.size()), 0, a.size() - 1)]
	if moving:
		var wk: Array = anims["walk"]
		return wk[int(_anim_t) % wk.size()]
	var idle: Array = anims["idle"]
	return idle[int(Time.get_ticks_msec() / 600) % idle.size()]


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tint := Color(0.85, 0.5, 0.45)
	if phase == 1:
		tint = Color(1.4, 0.45, 0.4)
	if _flash > 0.0:
		tint = Color(2.0, 2.0, 2.0)
	GenArt.draw_frame(self, "survivor_m1_a0_e0", facing, _frame(), Vector2.ZERO, tint)
	if hp < max_hp and hp > 0.0:
		draw_rect(Rect2(-9, -44, 18, 3), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(-9, -44, 18.0 * clampf(hp / max_hp, 0.0, 1.0), 3), Color("#ff5a5f"))
	draw_set_transform(Vector2(0, -50), 0.0, Vector2(0.5, 0.5))
	var f := UITheme.font()
	var label := "SAQUEADOR"
	var sw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S).x
	draw_string(f, Vector2(-sw / 2.0 + 2, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(-sw / 2.0, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, UITheme.DANGER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
