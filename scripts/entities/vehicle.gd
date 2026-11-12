class_name Vehicle
extends Node2D
## Veículo (fase 8): picape blindada ou moto elétrica (DB.VEHICLES).
##
## Quem dirige move o próprio personagem em "modo veículo" (movimento do dono, como a pé,
## só que mais rápido) e o veículo acompanha: no cliente do motorista segue o personagem
## local; no anfitrião segue a posição recebida do motorista; nos outros, interpola.
## Passageiros copiam a posição do veículo. O anfitrião gasta energia, atropela
## infectados, faz barulho e cuida de quem entra e sai.

var kind := "picape"
var world: World

# ---- replicado pelo servidor
var net_pos := Vector2.ZERO
var facing := 1
var locked := true
var fuel := 0.0
var cond := 50.0
var driver := 0
var passengers: Array = []
## Porta-malas (lista de itens; abre na janela de saque).
var items: Array = []

var _last_pos := Vector2.ZERO
var _noise_t := 0.0
var _hit_cd := {}


func setup_net() -> void:
	net_pos = position
	Net.make_sync(self, [".:net_pos", ".:facing", ".:locked", ".:fuel", ".:cond", ".:driver", ".:passengers",
		".:items"], 0.08)


func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("interactable")
	_last_pos = position
	if net_pos == Vector2.ZERO:
		net_pos = position


func def() -> Dictionary:
	return DB.VEHICLES[kind]


func title() -> String:
	return "Porta-malas: " + String(def()["nome"])


func prompt() -> String:
	var st := "trancado" if locked else ("sem energia" if fuel <= 0.0 else ("quebrado" if cond <= 0.0 else "pronto"))
	return "[E] %s · %s · energia %d%% · estado %d%%" % [def()["nome"], st, int(fuel), int(cond)]


## Opções do [E] no veículo (menu pequeno perto do personagem).
func options(p: Player) -> Array:
	var d := p.data
	var out: Array = []
	if locked:
		out.append({"id": "veh:hotwire", "txt": "Ligação direta (Mecânica 2)", "ok": d.level("mecanica") >= 2})
	else:
		out.append({"id": "veh:drive", "txt": "Dirigir", "ok": driver == 0 and seats_free() > 0})
		out.append({"id": "veh:ride", "txt": "Entrar como passageiro", "ok": seats_free() > 0})
	if fuel < 99.5:
		var gas := String(def()["energia"]) == "combustivel"
		var have := d.count("combustivel") > 0 if gas else d.count("bateria") > 0
		out.append({"id": "veh:refuel", "txt": "Abastecer (%s)" % ("querosene" if gas else "célula galvânica"), "ok": have})
	if cond < 99.0:
		out.append({"id": "veh:repair", "txt": "Consertar (1 metal, 2 sucatas)", "ok": d.can_afford({"metal": 1, "sucata": 2})})
	out.append({"id": "ui:loot", "txt": "Porta-malas", "ok": not locked})
	out.append({"id": "ui:veiculo", "txt": "Painel do veículo", "ok": true})
	return out


func interact(_p: Player) -> void:
	pass


## Pode andar? (destrancado, com energia e não quebrado)
func can_run() -> bool:
	return not locked and fuel > 0.0 and cond > 0.0


## Velocidade como multiplicador da velocidade a pé.
func speed_mult() -> float:
	var k := float(def()["vel"])
	if cond < 30.0:
		k *= 0.7
	return k


func occupants() -> Array:
	var out: Array = passengers.duplicate()
	if driver != 0:
		out.push_front(driver)
	return out


func seats_free() -> int:
	return int(def()["lugares"]) - occupants().size()


func trunk_volume() -> float:
	return Items.list_volume(items)


func _process(delta: float) -> void:
	var before := position
	var drv: Player = world.players.get(driver) if world != null and driver != 0 else null
	if drv != null and drv.is_local():
		position = drv.position
	elif drv != null and Net.is_server():
		position = drv.net_pos
	elif not Net.is_server():
		position = position.lerp(net_pos, clampf(delta * 12.0, 0.0, 1.0))
	var moved := position - before
	Sfx.loop("motor_loop", self, driver != 0, clampf(0.5 + moved.length() / maxf(delta, 0.001) / 300.0, 0.5, 1.3))
	if moved.length() > 0.3:
		facing = GenArt.facing_of(moved)
	if Net.is_server():
		net_pos = position
		_server_tick(delta)
	queue_redraw()


func _server_tick(delta: float) -> void:
	if driver != 0 and not world.players.has(driver):
		driver = 0
	for p in passengers.duplicate():
		if not world.players.has(int(p)):
			passengers.erase(p)
	var dist := position.distance_to(_last_pos)
	_last_pos = position
	if driver == 0 or dist <= 0.01:
		return
	fuel = maxf(0.0, fuel - dist / 100.0 * float(def()["gasto"]))
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = 0.6
		world.make_noise(position, float(def()["ruido"]))
	var spd := dist / maxf(delta, 0.001)
	if spd < 80.0:
		return
	for k in _hit_cd.keys():
		_hit_cd[k] = float(_hit_cd[k]) - delta
		if _hit_cd[k] <= 0.0:
			_hit_cd.erase(k)
	for n in get_tree().get_nodes_in_group("infected"):
		var e := n as Infected
		var off := e.position - position
		if Vector2(off.x, off.y * 2.0).length() < 26.0 and not _hit_cd.has(e.get_instance_id()):
			_hit_cd[e.get_instance_id()] = 0.6
			e.take_damage(float(def()["atropelo"]) * clampf(spd / 200.0, 0.5, 1.5), self, 1.0)
			cond = maxf(0.0, cond - 1.5)
	for n2 in get_tree().get_nodes_in_group("animals"):
		var an := n2 as Animal
		var off2 := an.position - position
		if Vector2(off2.x, off2.y * 2.0).length() < 26.0 and not _hit_cd.has(an.get_instance_id()):
			_hit_cd[an.get_instance_id()] = 0.6
			an.take_damage(float(def()["atropelo"]) * clampf(spd / 200.0, 0.5, 1.5), self)
			cond = maxf(0.0, cond - 0.8)


func to_dict() -> Dictionary:
	return {"kind": kind, "pos": [position.x, position.y], "fuel": fuel, "cond": cond, "locked": locked,
		"items": items.duplicate(true)}


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 26.0 if kind == "picape" else 14.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	GenArt.draw_frame(self, kind, 0, facing)
