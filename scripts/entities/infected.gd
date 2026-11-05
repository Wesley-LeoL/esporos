class_name Infected
extends CharacterBody2D
## Infectado. Tipos (kind): comum, corredor, brutamonte, explosivo, rastejante e o raro
## chamador. "elite" é a variante forte das zonas de esporos; elites "legado" são
## ex-sobreviventes mortos por infecção: guardam inventário e implantes e rondam o local da
## morte.
##
## Ritmo da luta: ao chegar no alvo ele PARA, prepara o golpe (o corpo avermelha), bate e
## fica um instante se recuperando. Apanhar faz cambalear (perde o golpe preparado), e o
## empurrão do jogador o derruba por um tempo. Nessa janela dá para bater e fugir.

## Atributos de cada tipo: vida, velocidade, dano, preparo do golpe (s), recuperação (s),
## resistência a cambalear (0-1), peso na escolha (raridade), escala e cor do desenho.
const KINDS := {
	"comum": {"hp": 40.0, "vel": 40.0, "dano": 8.0, "prep": 0.6, "rec": 0.8, "firme": 0.0, "peso": 80.0, "agarra": 0.35,
		"esc": Vector2(1, 1), "cor": Color(1, 1, 1)},
	"corredor": {"hp": 26.0, "vel": 112.0, "dano": 7.0, "prep": 0.35, "rec": 0.55, "firme": 0.0, "peso": 6.0,
		"esc": Vector2(0.9, 1.0), "cor": Color(0.85, 1.0, 0.85)},
	"brutamonte": {"hp": 150.0, "vel": 42.0, "dano": 21.0, "prep": 0.9, "rec": 1.1, "firme": 0.75, "peso": 3.0,
		"esc": Vector2(1.35, 1.3), "cor": Color(0.75, 0.68, 0.72)},
	"explosivo": {"hp": 34.0, "vel": 50.0, "dano": 6.0, "prep": 0.6, "rec": 0.8, "firme": 0.0, "peso": 4.0,
		"esc": Vector2(1.12, 1.0), "cor": Color(1.0, 1.0, 0.55)},
	"rastejante": {"hp": 30.0, "vel": 36.0, "dano": 11.0, "prep": 0.45, "rec": 0.7, "firme": 0.2, "peso": 4.0,
		"esc": Vector2(1.1, 0.55), "cor": Color(0.8, 0.85, 0.75)},
	"chamador": {"hp": 60.0, "vel": 66.0, "dano": 8.0, "prep": 0.6, "rec": 0.8, "firme": 0.1, "peso": 1.5,
		"esc": Vector2(0.95, 1.05), "cor": Color(1.0, 0.72, 0.9)},
}
const KIND_NAMES := {"comum": "infectado", "corredor": "corredor", "brutamonte": "brutamonte", "explosivo": "bolha de esporos",
	"rastejante": "rastejante", "chamador": "chamador"}

var kind := "comum"
var hp := 40.0
var max_hp := 40.0
var speed := 60.0
var dmg := 9.0
var elite := false
var legacy := false
var legacy_name := ""
var home := Vector2.ZERO
var loot: Array = []
var implants := {}
var world: World

# ---- replicado pelo servidor (os clientes só desenham)
var net_pos := Vector2.ZERO
var facing := 2
var atk_seq := 0
## 0 = normal, 1 = preparando o golpe, 2 = cambaleando/derrubado, 3 = encolhido gritando.
var phase := 0

var _cd := 0.0
var _prep_t := 0.0
var _stun_t := 0.0
var _wander_t := 0.0
var _wander_dir := Vector2.ZERO
var _flash := 0.0
var _avoid_t := 0.0
var _avoid_sign := 1.0
var _anim_t := 0.0
var _atk_anim := 0.0
var _seen_atk := 0
var _seen_hp := -1.0
var _screamed := false
var _groan_t := randf_range(2.0, 12.0)
## Barulho ouvido (vai investigar) e memória do último alvo visto.
var _heard_pos := Vector2.ZERO
var _heard_t := 0.0
var _target: Node2D
var _chase_t := 0.0
## Horda: vila que este infectado foi atacar (-1 = nenhuma).
var siege_vid := -1
## Muro que está batendo agora (chave da borda) e o tempo até repensar o caminho.
var _wall_k := Vector3i(0, 0, -1)
var _path_t := 0.0
## Abertura do prédio onde está o alvo (janela, vão, porta) e o tempo até repensar.
var _house_k := Vector3i(0, 0, -1)
var _hpath_t := 0.0


## Escolhe um tipo pela raridade. 'edge' (0-1) = quão perto da borda: tipos perigosos
## aparecem mais longe do centro.
static func roll_kind(r: RandomNumberGenerator, edge := 0.0) -> String:
	var total := 0.0
	var w := {}
	for k: String in KINDS:
		var p := float(KINDS[k]["peso"])
		if k in ["brutamonte", "explosivo", "chamador"]:
			p *= 0.6 + edge * 1.2
		w[k] = p
		total += p
	var x := r.randf() * total
	for k: String in w:
		x -= float(w[k])
		if x <= 0.0:
			return k
	return "comum"


func setup(is_elite: bool, k := "comum") -> void:
	elite = is_elite
	kind = k if KINDS.has(k) else "comum"
	var d: Dictionary = KINDS[kind]
	max_hp = float(d["hp"])
	speed = float(d["vel"])
	dmg = float(d["dano"])
	if elite:
		max_hp = maxf(110.0, max_hp * 2.2)
		speed = maxf(92.0, speed * 1.2)
		dmg = maxf(17.0, dmg * 1.6)
	hp = max_hp


func stat(key: String) -> float:
	return float(KINDS[kind][key])


## Sincronizador (autoridade: servidor). Chamado antes de entrar na árvore.
func setup_net() -> void:
	net_pos = position
	Net.make_sync(self, [".:net_pos", ".:facing", ".:atk_seq", ".:hp", ".:phase"], 0.05)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("infected")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0 if kind == "brutamonte" else 7.0
	shape.shape = circle
	add_child(shape)
	if home == Vector2.ZERO:
		home = position
	net_pos = position
	_seen_hp = hp
	_wander_dir = Vector2.from_angle(randf() * TAU)


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_atk_anim = maxf(0.0, _atk_anim - delta)
	if atk_seq != _seen_atk:
		_seen_atk = atk_seq
		_atk_anim = 0.4
		Sfx.play_at("infectado_ataque", position)
	# gemido de vez em quando
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(6.0, 16.0)
		if phase != 3:
			Sfx.play_at("infectado_gemido", position)
	if hp < _seen_hp - 0.01:
		_flash = 0.15
	_seen_hp = hp
	if not Net.is_server():
		var before := position
		if position.distance_to(net_pos) > 160.0:
			position = net_pos
		else:
			position = position.lerp(net_pos, clampf(delta * 12.0, 0.0, 1.0))
		var moved := position - before
		if moved.length() > 0.05:
			_anim_t += moved.length() / 9.0
		return
	_server_ai(delta)


## Servidor: ouviu um barulho (passos, tiro, construção, grito) e vai investigar.
func hear(pos: Vector2) -> void:
	if _target != null and _chase_t > 0.0:
		return
	_heard_pos = pos
	_heard_t = 10.0


## Ainda não percebeu ninguém (para o golpe furtivo).
func unaware() -> bool:
	return _target == null and _chase_t <= 0.0 and phase != 3


## O golpe vem pelas costas? (de onde vem 'src' em relação para onde ele olha)
func from_behind(src: Vector2) -> bool:
	var look := Vector2.from_angle(float(facing) * PI / 4.0)
	var to_src := src - position
	return Vector2(to_src.x, to_src.y * 2.0).normalized().dot(look) < -0.3


## Quem este infectado enxerga agora (jogador, morador de vila ou saqueador). A distância de
## visão do jogador depende de quanto ele se expõe (agachado, correndo, lanterna,
## Furtividade). Gente atrás da cerca de uma vila também é vista: aí o infectado tenta entrar.
func _pick_target(aggro: float) -> Node2D:
	var best: Node2D = null
	var best_d := 1e9
	for p in world.alive_players():
		if p.data == null:
			continue
		var off := p.net_pos - position
		var d := Vector2(off.x, off.y * 2.0).length()
		var sight := aggro * p.data.visibility(p.sprinting, p.sneaking) * world.sight_factor(p)
		if p == _target and _chase_t > 0.0:
			sight *= 1.6
		if d < sight and d < best_d:
			best_d = d
			best = p
	for group in ["npcs", "raiders"]:
		for n in get_tree().get_nodes_in_group(group):
			if float(n.get("hp")) <= 0.0:
				continue
			var off2 := (n as Node2D).position - position
			var d2 := Vector2(off2.x, off2.y * 2.0).length()
			if d2 < aggro * 0.9 and d2 < best_d:
				best_d = d2
				best = n
	return best


static func _pos_of(n: Node2D) -> Vector2:
	return (n as Player).net_pos if n is Player else n.position


## IA (só no servidor): persegue quem enxerga, investiga barulhos ou vaga. Se o alvo está
## atrás da cerca de uma vila, vai até uma brecha ou um portão aberto; sem passagem, bate
## no trecho de muro mais perto até derrubar. Barricadas no caminho também apanham.
func _server_ai(delta: float) -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
	_cd = maxf(0.0, _cd - delta)
	_avoid_t = maxf(0.0, _avoid_t - delta)
	_chase_t = maxf(0.0, _chase_t - delta)
	_heard_t = maxf(0.0, _heard_t - delta)
	_path_t = maxf(0.0, _path_t - delta)
	_hpath_t = maxf(0.0, _hpath_t - delta)
	# derrubado, cambaleando ou encolhido: não anda nem ataca
	if _stun_t > 0.0:
		_stun_t -= delta
		velocity = Vector2.ZERO
		if _stun_t <= 0.0:
			phase = 0
		return
	var aggro := 340.0 if elite else (200.0 if kind == "rastejante" else 240.0)
	var target: Node2D = _pick_target(aggro)
	if target != null:
		_target = target
		_chase_t = 4.0
	elif _target != null and is_instance_valid(_target) and _chase_t <= 0.0:
		# perdeu de vista: vai até onde viu por último
		_heard_pos = _pos_of(_target)
		_heard_t = 6.0
		_target = null
	# preparando o golpe: fica parado olhando o alvo; no fim, bate se ainda alcançar
	if _prep_t > 0.0:
		_prep_t -= delta
		velocity = Vector2.ZERO
		if target != null:
			facing = GenArt.facing_of(_pos_of(target) - position)
		if _prep_t <= 0.0:
			phase = 0
			_cd = stat("rec") * (0.8 if elite else 1.0)
			atk_seq += 1
			if target != null:
				var tp := _pos_of(target) - position
				if Vector2(tp.x, tp.y * 2.0).length() < 34.0:
					_attack(target)
		return
	var goal := Vector2.INF
	var mult := 1.0
	if target != null:
		goal = _pos_of(target)
	elif _heard_t > 0.0:
		goal = _heard_pos
		mult = 0.75
	elif siege_vid >= 0:
		goal = world.ground.map_to_local(world.villages[siege_vid].cell)
		mult = 0.85
	# cerca no caminho?
	var hit_wall := false
	if goal != Vector2.INF:
		var vid := world.village_at(goal)
		if vid >= 0 and world.village_at(position) != vid:
			if _path_t <= 0.0:
				_path_t = 1.0
				_wall_k = world.fence_goal(vid, position)
			if _wall_k.z >= 0:
				var wp := world.edge_pos(_wall_k)
				if world.fence_open(_wall_k):
					# brecha ou portão aberto: passa por ela
					var into := world.ground.map_to_local(world.villages[vid].cell)
					goal = wp if position.distance_to(wp) > 14.0 else into
				else:
					goal = wp
					if world.edge_dist(_wall_k, position) < 26.0:
						hit_wall = true
	# alvo dentro de um prédio: vai até a abertura mais perto; fechada, bate nela
	var hit_house := false
	if goal != Vector2.INF and not hit_wall and target != null:
		var th := world.house_at(goal)
		if th >= 0 and world.house_at(position) != th:
			if _hpath_t <= 0.0:
				_hpath_t = 1.0
				_house_k = world.house_goal(th, position)
			if _house_k.z >= 0:
				var hpos := world.edge_pos(_house_k)
				if world.edge_passable(_house_k):
					if position.distance_to(hpos) > 12.0:
						goal = hpos
				else:
					goal = hpos
					if world.edge_dist(_house_k, position) < 24.0:
						hit_house = true
	if hit_house:
		velocity = Vector2.ZERO
		if _cd <= 0.0:
			_cd = 1.2
			atk_seq += 1
			facing = GenArt.facing_of(world.edge_pos(_house_k) - position)
			world.bash_edge(_house_k, dmg * (2.5 if kind == "brutamonte" else 1.0))
		return
	var dir := Vector2.ZERO
	if goal != Vector2.INF:
		var to := goal - position
		var iso := Vector2(to.x, to.y * 2.0)
		if iso.length() < 6.0 and target == null:
			_heard_t = 0.0
		dir = iso.normalized()
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.5, 4.0)
			_wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
			if legacy:
				var back := Vector2(home.x - position.x, (home.y - position.y) * 2.0)
				if back.length() > 90.0:
					_wander_dir = back.normalized()
		dir = _wander_dir
		mult = 0.35
	if hit_wall:
		dir = Vector2.ZERO
		if _cd <= 0.0:
			_cd = 1.0 if elite else 1.3
			atk_seq += 1
			facing = GenArt.facing_of(world.edge_pos(_wall_k) - position)
			world.damage_fence(_wall_k, dmg * (1.0 if elite else 0.6) * (2.5 if kind == "brutamonte" else 1.0))
	if _avoid_t > 0.0:
		dir = dir.rotated(_avoid_sign * 1.1)
	velocity = Vector2(dir.x, dir.y * 0.5) * speed * mult
	move_and_slide()
	net_pos = position
	if velocity.length() > 4.0:
		facing = GenArt.facing_of(velocity)
		_anim_t += delta * velocity.length() / 9.0
	if get_slide_collision_count() > 0 and dir != Vector2.ZERO and not hit_wall:
		# bateu numa barricada perseguindo alguém: soca a barricada
		var bar := _barricade_hit()
		if bar != null and (target != null or _heard_t > 0.0) and _cd <= 0.0:
			_cd = 1.2
			atk_seq += 1
			facing = GenArt.facing_of(bar.position - position)
			world.damage_barricade(bar.key(), dmg * (2.5 if kind == "brutamonte" else 1.0))
		elif _avoid_t <= 0.0:
			_avoid_t = 0.6
			_avoid_sign = 1.0 if randf() < 0.5 else -1.0
	if target != null and _cd <= 0.0:
		var tp2 := _pos_of(target) - position
		if Vector2(tp2.x, tp2.y * 2.0).length() < 28.0:
			# chegou: para e prepara o golpe
			_prep_t = stat("prep") * (0.75 if elite else 1.0)
			phase = 1
			velocity = Vector2.ZERO


## Parede com barricada contra a qual ele está batendo (ou null).
func _barricade_hit() -> WallEdge:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c is WallEdge and (c as WallEdge).barricade > 0.0:
			return c as WallEdge
	return null


func _attack(target: Node2D) -> void:
	var amount := dmg * randf_range(0.8, 1.25)
	if target is Player:
		var pl := target as Player
		var limbs: Array = ["torso", "torso", "braco_e", "braco_d", "perna_e", "perna_d", "cabeca"]
		if kind == "rastejante":
			limbs = ["perna_e", "perna_d"]
		pl.server_hurt(limbs[randi() % limbs.size()], amount, 4.0 if elite else 2.5)
		# o comum pode agarrar no golpe: o jogador fica preso até se soltar (F empurra)
		if randf() < float(KINDS[kind].get("agarra", 0.0)) and pl.data.grab_t <= 0.0:
			pl.data.grab_t = 2.2
			pl._sync_t = 0.0
			_prep_t = 0.0
			_cd = 0.9  # segurando, morde de novo mais rápido
			Game.tell(pl.peer, "Um infectado te agarrou! [F] empurra para se soltar.")
			world.sfx_at("infectado_ataque", position)
		return
	if target.has_method("take_hit"):
		target.take_hit(amount, self)


## Servidor: dano de um jogador, torre ou saqueador. 'stagger' = quanto o golpe faz
## cambalear (0 = nada; o corpo a corpo cambaleia, o tiro quase não).
func take_damage(amount: float, from: Node2D, stagger := 0.35) -> void:
	if not Net.is_server():
		return
	hp -= amount
	var src := from.position if from != null else position
	if from is Player and not (from as Player).is_local():
		src = (from as Player).net_pos
	if from != null and (from is Player or from.is_in_group("raiders")):
		# quem bateu passa a ser o alvo
		_target = from
		_chase_t = 4.0
	var off := position - src
	var push := 5.0 + 9.0 * stagger * (1.0 - stat("firme"))
	position += Vector2(off.x, off.y * 0.5).normalized() * push
	net_pos = position
	if hp <= 0.0:
		_die()
		return
	if kind == "chamador" and not _screamed and hp < max_hp * 0.3:
		_scream()
		return
	var st := stagger * (1.0 - stat("firme"))
	if st > 0.05:
		# cambaleia: perde o golpe que estava preparando
		_prep_t = 0.0
		_stun_t = maxf(_stun_t, st)
		phase = 2


## Empurrão do jogador: afasta e derruba por um tempo, sem dano.
func shove(from_pos: Vector2) -> void:
	var off := position - from_pos
	var k := 1.0 - stat("firme")
	position += Vector2(off.x, off.y * 0.5).normalized() * 26.0 * k
	net_pos = position
	_prep_t = 0.0
	if k > 0.3:
		_stun_t = maxf(_stun_t, 1.1 * k)
		phase = 2


## Chamador quase morto: se encolhe e grita; todo infectado por perto vem, e mais alguns
## aparecem nas redondezas.
func _scream() -> void:
	_screamed = true
	_prep_t = 0.0
	_stun_t = 3.0
	phase = 3
	world.infected_scream(self)


func _die() -> void:
	var drops: Array = loot.duplicate(true)
	for slot in implants:
		Items.add(drops, {"id": String(implants[slot]["id"]), "n": 1})
	if not elite and randf() < (0.4 if kind == "brutamonte" else 0.18):
		drops = DB.roll_loot("comum", 1, world.rng)
	world.drop_loot(position, drops)
	world.on_infected_killed(position)
	if kind == "explosivo":
		world.spore_burst(position)
	world.sfx_at("infectado_morre" if kind != "explosivo" else "explosao_esporos", position)
	if legacy:
		Game.say_all("O infectado de elite que era %s foi abatido." % legacy_name)
	queue_free()


func _process(_delta: float) -> void:
	visible = world == null or not world.hidden_inside(position)
	queue_redraw()


func _draw() -> void:
	var sc: Vector2 = KINDS[kind]["esc"]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, (11.0 if not elite else 13.0) * sc.x, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var anims := GenCatalog.INFECTED_ANIMS
	var col := 0
	if _atk_anim > 0.0 or phase == 1:
		var a: Array = anims["attack"]
		col = a[0] if (_atk_anim > 0.2 or phase == 1) else a[1]
	else:
		var w: Array = anims["walk"]
		col = w[int(_anim_t) % w.size()] if phase == 0 else w[0]
	var tint: Color = KINDS[kind]["cor"]
	if kind == "explosivo":
		var pul := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		tint = tint.lerp(Color(0.8, 1.0, 0.3), pul * 0.4)
	match phase:
		1:
			tint = tint.lerp(Color(1.6, 0.45, 0.4), 0.55)  # preparando o golpe: avermelha
		2:
			tint = tint.darkened(0.25)
		3:
			tint = tint.lerp(Color(1.6, 0.6, 1.4), 0.5 + 0.3 * sin(Time.get_ticks_msec() / 60.0))
	if _flash > 0.0:
		tint = Color(2.2, 2.2, 2.2)
	var lean := 0.0
	if phase == 2:
		lean = 0.25 * (1.0 if facing < 4 else -1.0)
	var ysc := sc.y * (0.7 if phase == 3 else 1.0)
	draw_set_transform(Vector2.ZERO, lean, Vector2(sc.x, ysc))
	GenArt.draw_frame(self, "elite" if elite else "infected", facing, col, Vector2.ZERO, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if phase == 1:
		# aviso do golpe
		draw_rect(Rect2(-2, -54 * ysc - 8, 4, 6), Color("#ff5a5f"))
	if hp < max_hp:
		var top := (-50.0 if elite else -42.0) * ysc - 2.0
		draw_rect(Rect2(-9, top, 18, 3), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(-9, top, 18.0 * clampf(hp / max_hp, 0.0, 1.0), 3), Color("#ff5a5f"))
