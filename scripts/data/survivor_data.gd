class_name SurvivorData
extends RefCounted
## Estado completo de um sobrevivente: metabolismo, carga patogênica, saúde (vida,
## sangramento e perna machucada), próteses, habilidades e inventário. Não depende de nós da cena.

signal message(text: String)
## Itens que não couberam (o Player larga no chão num saco).
signal overflow(items: Array)

## Saúde: uma vida só (0-100). Golpes tiram vida e podem abrir sangramento (que tira vida
## por segundo e piora com novos cortes). Quedas torcem ou quebram a perna. Não há membros.
const MAX_HP := 100.0
## Partes do corpo só para a proteção das roupas: quanto de cada golpe cai em cada parte.
const ZONES := {"cabeca": 0.15, "torso": 0.35, "braco_e": 0.1, "braco_d": 0.1, "perna_e": 0.15, "perna_d": 0.15}
## Sangramento (vida por segundo): até LEVE estanca sozinho devagar.
const BLEED_LEVE := 0.12
const BLEED_GRAVE := 0.4
const PERNA_NAMES := ["", "Perna torcida", "Perna quebrada"]
const NAMES: Array[String] = ["Ayla Moreno", "Kael Ribeiro", "Dara Voss", "Mateo Quintana", "Iris Okafor",
	"Bruno Takeda", "Nina Falk", "Orion Duarte", "Lena Sato", "Teo Marques", "Zara Lindqvist", "Caio Brandt"]
const MAX_CAL := 2000.0
## Volume dos bolsos (litros) e peso confortável (kg; a fase 3 liga isso à Força).
const POCKETS_CAP := 4.0
const CARRY_MAX := 16.0
## Ordem em que os itens recebidos procuram espaço (o coldre só aceita armas).
const CONTAINERS := ["coldre", "mochila", "bolsos"]
const CONT_NAMES := {"bolsos": "Bolsos", "mochila": "Mochila", "coldre": "Coldre"}
const EQUIP_SLOTS := ["mascara", "mochila", "coldre"]

var nome: String = "Sobrevivente"
var pathogen: float = 10.0
var calories: float = 1600.0
var water: float = 80.0
var hp: float = MAX_HP
## Vida perdida por segundo pelo sangramento (0 = não sangra).
var bleed: float = 0.0
## Perna: 0 = boa, 1 = torcida, 2 = quebrada. tala = imobilizada; osso_t = cura (0-100).
var perna: int = 0
var tala: bool = false
var osso_t: float = 0.0
## Cura por segundo (antibiótico e curativos fortes) por regen_t segundos.
var regen_rate: float = 0.0
var regen_t: float = 0.0
## Estamina: a recuperação é multiplicada por stam_mult por stam_t segundos (energético, adrenalina).
var stam_mult: float = 1.0
var stam_t: float = 0.0
var skills := {}
## Atributos da criação (2 a 9, base 5) e traços escolhidos (ver DB.TRAITS).
var forca: int = 5
var resist: int = 5
var traits: Array = []
var stamina: float = 100.0
## Itens por recipiente (listas de instâncias, ver Items).
var bags := {"bolsos": [], "mochila": [], "coldre": []}
## Itens vestidos: máscara (com vedação e filtro), mochila, coldre e roupas (DB.ROUPA_SLOTS).
## {} = vazio.
var equip := {"mascara": {}, "mochila": {}, "coldre": {}, "cabeca": {}, "torso": {}, "maos": {}, "pernas": {}, "pes": {}}
## Id único ("u") da arma na mão (ela continua guardada em algum recipiente).
var hand_u: int = 0
## Barra rápida: 5 tipos de item (o item continua no inventário). "" = espaço vazio.
var hotbar: Array = ["", "", "", "", ""]
var _next_u: int = 1
var suppress_t: float = 0.0
var tainted_t: float = 0.0
var battery: float = 0.0
var heat: float = 0.0
var implants := {}
## Estresse sináptico (0-100). Ver overloaded().
var synaptic: float = 0.0
## Analgésico (segundos restantes) e lanterna acesa (id único da lanterna, 0 = apagada).
var pain_t: float = 0.0
## Agarrado por um infectado comum (segundos): não sai do lugar até soltar ou empurrar.
var grab_t: float = 0.0
## Ferido pelos espetos (fica lento) e espera até ferir de novo.
var slow_t: float = 0.0
var trap_cd: float = 0.0
## Descanso (100 = descansado; cai em ~1,5 dia do jogo), dormindo, temperatura do corpo (°C)
## e quanto está molhado (0-100).
var sono: float = 100.0
var sleeping := false
var sleep_bed := 1.0
var temp_corpo: float = 37.0
var molhado: float = 0.0
var light_u: int = 0
## Comida quente (segundos restantes): a estamina recupera mais rápido.
var well_fed_t: float = 0.0
var alive: bool = true
## Invulnerável (cheat de testes, por personagem).
var god := false
var death_cause: String = ""
var death_kind: String = ""
var time_alive: float = 0.0
var rng := RandomNumberGenerator.new()

var _warn_t := {}
var _last_hurt_cause: String = "Trauma"


func _init() -> void:
	rng.randomize()
	for s in DB.SKILLS:
		skills[s] = {"lv": 0, "xp": 0.0}


## Ficha de criação aleatória (um dos modelos prontos, com nome sorteado).
static func random_spec(r: RandomNumberGenerator) -> Dictionary:
	var keys: Array = DB.PRESETS.keys()
	var spec: Dictionary = DB.PRESETS[keys[r.randi() % keys.size()]].duplicate(true)
	spec["nome"] = NAMES[r.randi() % NAMES.size()]
	return spec


## Sobrevivente novo a partir de uma ficha já validada (DB.creation_error).
static func from_spec(spec: Dictionary, r: RandomNumberGenerator) -> SurvivorData:
	var d := random_survivor(r)
	var n := str(spec.get("nome", "")).strip_edges().substr(0, 20)
	if n != "":
		d.nome = n
	d.forca = int(spec.get("forca", 5))
	d.resist = int(spec.get("resist", 5))
	for s in d.skills:
		d.skills[s]["lv"] = 0
	var sk: Dictionary = spec.get("skills", {})
	for k in sk:
		d.skills[str(k)]["lv"] = int(sk[k])
	d.traits.assign(spec.get("traits", []))
	d.stamina = d.max_stamina()
	return d


static func random_survivor(r: RandomNumberGenerator) -> SurvivorData:
	var d := SurvivorData.new()
	d.nome = NAMES[r.randi() % NAMES.size()]
	d.pathogen = r.randf_range(5.0, 25.0)
	d.calories = r.randf_range(1200.0, 1800.0)
	d.water = r.randf_range(60.0, 90.0)
	var preset: Dictionary = DB.PRESETS.values()[r.randi() % DB.PRESETS.size()]
	for k in preset["skills"]:
		d.skills[k]["lv"] = int(preset["skills"][k])
	d.forca = int(preset["forca"])
	d.resist = int(preset["resist"])
	d.traits.assign(preset["traits"])
	d.stamina = d.max_stamina()
	d.equip["mochila"] = Items.make("mochila_escolar")[0]
	var mask: Dictionary = Items.make("mascara")[0]
	mask["filtro"] = 100.0
	d.equip["mascara"] = mask
	# roupa do corpo
	var top := "moletom" if r.randf() < 0.35 else "camiseta"
	for id: String in [top, "calca_jeans", "tenis"]:
		var c: Dictionary = Items.make(id)[0]
		c["dur"] = snappedf(r.randf_range(55.0, 100.0), 1.0)
		c["u"] = d._next_u
		d._next_u += 1
		d.equip[slot_of(id)] = c
	var start := {"feijao": 1, "abridor": 1, "agua_limpa": 2, "bandagem": 1, "filtro": 1, "sucata": 3}
	if r.randf() < 0.5:
		start["supressor"] = 1
	if r.randf() < 0.5:
		start["maca"] = 2
	d.receive(Items.from_counts(start))
	return d


# ---------------------------------------------------------------- inventário
func all_items() -> Array:
	return bags["coldre"] + bags["mochila"] + bags["bolsos"]


func count(id: String) -> int:
	return Items.count(all_items(), id)


## Capacidade (litros) de um recipiente; mochila e coldre dependem do item vestido.
func capacity(c: String) -> float:
	if c == "bolsos":
		return POCKETS_CAP + (2.0 if has_trait("organizado") else 0.0)
	var worn: Dictionary = equip.get(c, {})
	return float(Items.def(worn["id"]).get("cap", 0.0)) if not worn.is_empty() else 0.0


func used_volume(c: String) -> float:
	return Items.list_volume(bags[c])


## Quantas unidades da instância cabem no recipiente.
func fits(c: String, inst: Dictionary) -> int:
	if c == "coldre" and not String(Items.def(inst["id"])["tipo"]) in ["arma", "arma_fogo"]:
		return 0
	var unit := float(Items.def(inst["id"]).get("vol", 0.5))
	var free := capacity(c) - used_volume(c)
	if unit <= 0.0:
		return int(inst["n"])
	return clampi(floori((free + 0.001) / unit), 0, int(inst["n"]))


func _put(c: String, inst: Dictionary) -> void:
	var placed := Items.add(bags[c], inst)
	if not placed.has("u"):
		placed["u"] = _next_u
		_next_u += 1


## Guarda uma instância onde couber (ou no recipiente 'prefer'). Devolve o que sobrou ({}).
## Mantém o id único da instância quando ela já tem um (itens que só mudam de recipiente).
func store(inst: Dictionary, prefer := "") -> Dictionary:
	inst = inst.duplicate()
	var order: Array = CONTAINERS.duplicate()
	if prefer != "":
		order.erase(prefer)
		order.push_front(prefer)
	for c in order:
		var k := fits(c, inst)
		if k <= 0:
			continue
		if k >= int(inst["n"]):
			_put(c, inst)
			return {}
		var part := inst.duplicate()
		part.erase("u")
		part["n"] = k
		inst["n"] = int(inst["n"]) - k
		_put(c, part)
	inst.erase("u")
	return inst


## Recebe uma lista de itens; devolve o que não coube.
func receive(list: Array) -> Array:
	var left: Array = []
	for inst in list:
		var rest := store(inst)
		if not rest.is_empty():
			Items.add(left, rest)
	return left


## Cria itens novos e guarda; o que não couber cai no chão (sinal overflow).
func give(id: String, n: int = 1) -> void:
	var left := receive(Items.make(id, n))
	if not left.is_empty():
		message.emit("Sem espaço: %s ficou no chão." % Items.describe_list(left))
		overflow.emit(left)


## [recipiente, instância] do item com esse id único ("equip:<slot>" para itens vestidos).
func find(u: int) -> Array:
	for c in bags:
		for inst in bags[c]:
			if int(inst.get("u", 0)) == u:
				return [c, inst]
	for slot in equip:
		if not equip[slot].is_empty() and int(equip[slot].get("u", 0)) == u:
			return ["equip:" + slot, equip[slot]]
	return []


## Primeira instância com esse id (para ações por tipo, como "usar bateria").
func first_of(id: String) -> Dictionary:
	for inst in all_items():
		if inst["id"] == id:
			return inst
	return {}


func _resolve(ref: Variant) -> Dictionary:
	if ref is int or ref is float:
		var f := find(int(ref))
		return f[1] if not f.is_empty() else {}
	return first_of(str(ref))


## Tira 'n' unidades de uma instância do inventário. Devolve a parte (sem id único).
func remove_u(u: int, n: int = 1) -> Dictionary:
	var f := find(u)
	if f.is_empty() or String(f[0]).begins_with("equip:"):
		return {}
	var part := Items.split(bags[f[0]], f[1], n)
	if u == hand_u and find(u).is_empty():
		hand_u = 0
	return Items.strip(part)


func take_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	for c in ["bolsos", "mochila", "coldre"]:
		var here := Items.count(bags[c], id)
		if here <= 0 or n <= 0:
			continue
		var k := mini(here, n)
		Items.take(bags[c], id, k)
		n -= k
	if hand_u != 0 and find(hand_u).is_empty():
		hand_u = 0
	return true


## Gasta um uso de um item (unidade inteira, ou parte da carga em itens com usos).
func spend(id: String) -> bool:
	var d := Items.def(id)
	if not d.has("carga"):
		return take_item(id)
	var best: Dictionary = {}
	for inst in all_items():
		if inst["id"] == id and (best.is_empty() or float(inst["carga"]) < float(best["carga"])):
			best = inst
	if best.is_empty():
		return false
	best["carga"] = float(best["carga"]) - float(d.get("uso_carga", 100.0))
	if float(best["carga"]) <= 0.5:
		remove_u(int(best["u"]))
	return true


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if count(k) < int(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> void:
	for k in cost:
		take_item(k, int(cost[k]))


## Move um item entre os próprios recipientes (inteiro, se couber).
func move_item(u: int, dest: String) -> void:
	var f := find(u)
	if f.is_empty() or not bags.has(dest) or f[0] == dest or String(f[0]).begins_with("equip:"):
		return
	var inst: Dictionary = f[1]
	if fits(dest, inst) < int(inst["n"]):
		message.emit("Não cabe em %s." % CONT_NAMES[dest].to_lower())
		return
	var keep_hand := hand_u == u
	bags[f[0]].erase(inst)
	var placed := Items.add(bags[dest], inst)
	if keep_hand:
		hand_u = int(placed["u"])


## Reordena um item dentro do próprio recipiente (organizar com o mouse).
func reorder(u: int, to: int) -> void:
	var f := find(u)
	if f.is_empty() or String(f[0]).begins_with("equip:"):
		return
	var list: Array = bags[f[0]]
	list.erase(f[1])
	list.insert(clampi(to, 0, list.size()), f[1])


## Organiza todos os recipientes (tipo, nome, estado) e junta pilhas.
func sort_bags() -> void:
	for c in bags:
		var keep_hand := hand_u
		Items.sort_list(bags[c])
		Items.compact(bags[c])
		if keep_hand != 0 and find(keep_hand).is_empty():
			hand_u = 0
		for inst in bags[c]:
			if not inst.has("u"):
				inst["u"] = _next_u
				_next_u += 1


# ---------------------------------------------------------------- equipamento
## Espaço onde o item é vestido ("" = não se veste).
static func slot_of(id: String) -> String:
	var d := Items.def(id)
	var tipo := String(d.get("tipo", ""))
	if tipo in EQUIP_SLOTS:
		return tipo
	if tipo == "roupa":
		return String(d.get("slot", ""))
	return ""


## Peça vestida está gasta? A proteção cai até 40% com a durabilidade zerada.
static func cloth_cond(inst: Dictionary) -> float:
	return 0.4 + 0.6 * clampf(float(inst.get("dur", 100.0)) / 100.0, 0.0, 1.0)


## [dano evitado, chance de sangrar evitada] numa parte do corpo, somando as roupas que a cobrem.
func zone_armor(limb_id: String) -> Array:
	var keep_d := 1.0
	var keep_c := 1.0
	for slot: String in DB.ROUPA_SLOTS:
		var inst: Dictionary = equip[slot]
		if inst.is_empty():
			continue
		var k := float(DB.ROUPA_COBRE[slot].get(limb_id, 0.0))
		if k <= 0.0:
			continue
		var d := Items.def(inst["id"])
		var c := cloth_cond(inst) * k
		keep_d *= 1.0 - float(d.get("def", 0.0)) * c
		keep_c *= 1.0 - float(d.get("corte", 0.0)) * c
	return [minf(0.8, 1.0 - keep_d), minf(0.85, 1.0 - keep_c)]


## Proteção total da roupa: [dano evitado, chance de sangrar evitada], média das partes do
## corpo pelo quanto cada uma é atingida.
func armor() -> Array:
	var a := [0.0, 0.0]
	for z: String in ZONES:
		var za := zone_armor(z)
		a[0] += float(za[0]) * float(ZONES[z])
		a[1] += float(za[1]) * float(ZONES[z])
	return a


## Peças vestidas de um conjunto.
func set_pieces(conj: String) -> int:
	var n := 0
	for slot: String in DB.ROUPA_SLOTS:
		if not equip[slot].is_empty() and String(Items.def(equip[slot]["id"]).get("conjunto", "")) == conj:
			n += 1
	return n


func set_complete(conj: String) -> bool:
	return DB.CONJUNTOS.has(conj) and set_pieces(conj) >= (DB.CONJUNTOS[conj]["pecas"] as Array).size()


## Bônus de roupa (fração; 0.2 = 20%): soma das peças + conjunto completo.
func gear_bonus(kind: String) -> float:
	var b := 0.0
	for slot: String in DB.ROUPA_SLOTS:
		if not equip[slot].is_empty():
			b += float(Items.def(equip[slot]["id"]).get("bonus", {}).get(kind, 0.0))
	for conj: String in DB.CONJUNTOS:
		if set_complete(conj):
			b += float(DB.CONJUNTOS[conj]["bonus"].get(kind, 0.0))
	return b


## Gasta as roupas com um golpe (cada peça pelo quanto do corpo ela cobre).
func _wear_clothes(amount: float) -> void:
	for slot: String in DB.ROUPA_SLOTS:
		var inst: Dictionary = equip[slot]
		if inst.is_empty():
			continue
		var share := 0.0
		for z: String in DB.ROUPA_COBRE[slot]:
			share += float(DB.ROUPA_COBRE[slot][z]) * float(ZONES.get(z, 0.0))
		if share <= 0.0:
			continue
		var before := float(inst.get("dur", 100.0))
		inst["dur"] = maxf(0.0, before - amount * share * 2.0 * (0.25 + float(Items.def(inst["id"]).get("def", 0.0))))
		if before > 0.0 and float(inst["dur"]) <= 0.0:
			message.emit("%s está em farrapos: protege bem menos (conserte com fita)." % DB.item_name(inst["id"]))


## Sangramento em palavras ("" = não sangra).
func bleed_text() -> String:
	if bleed <= 0.0:
		return ""
	return "leve" if bleed < BLEED_LEVE else ("grave" if bleed >= BLEED_GRAVE else "moderado")


## Chave que abre a fechadura 'lock' ({} = não tem).
func key_for(lock: String) -> Dictionary:
	for c in bags:
		for inst: Dictionary in bags[c]:
			if inst["id"] == "chave" and str(inst.get("tranca", "")) == lock:
				return inst
	return {}


func has_mask() -> bool:
	return not equip["mascara"].is_empty()


func filter_pct() -> float:
	return float(equip["mascara"].get("filtro", 0.0)) if has_mask() else 0.0


func mask_seal() -> float:
	return float(equip["mascara"].get("dur", 100.0)) if has_mask() else 0.0


func weapon_inst() -> Dictionary:
	if hand_u == 0:
		return {}
	var f := find(hand_u)
	return f[1] if not f.is_empty() else {}


func weapon_id() -> String:
	var w := weapon_inst()
	return str(w["id"]) if not w.is_empty() else ""


## Veste um item (mochila, coldre ou máscara) vindo de fora do inventário ou de um recipiente.
## O que estava vestido antes volta para o inventário junto com o conteúdo dele; o que não
## couber cai no chão.
func wear(inst: Dictionary) -> void:
	var tipo := slot_of(String(inst["id"]))
	if tipo == "":
		return
	inst = Items.strip(inst)
	inst["n"] = 1
	inst["u"] = _next_u
	_next_u += 1
	var old: Dictionary = equip[tipo]
	var old_content: Array = bags[tipo] if bags.has(tipo) else []
	equip[tipo] = inst
	if bags.has(tipo):
		bags[tipo] = []
	var back: Array = []
	for it in old_content:
		back.append(it)
	if not old.is_empty():
		back.append(old)
	var left := receive(back)
	if hand_u != 0 and find(hand_u).is_empty():
		hand_u = 0
	message.emit("Você vestiu: %s." % DB.item_name(inst["id"]))
	if not left.is_empty():
		message.emit("Sem espaço: %s ficou no chão." % Items.describe_list(left))
		overflow.emit(left)


## Tira um item vestido e guarda no inventário (ou larga, se não couber).
func unwear(slot: String) -> void:
	if not equip.has(slot) or equip[slot].is_empty():
		return
	var old: Dictionary = equip[slot]
	equip[slot] = {}
	var back: Array = []
	if bags.has(slot):
		back = bags[slot]
		bags[slot] = []
	back.append(old)
	var left := receive(back)
	if hand_u != 0 and find(hand_u).is_empty():
		hand_u = 0
	message.emit("Você tirou: %s." % DB.item_name(old["id"]))
	if not left.is_empty():
		message.emit("Sem espaço: %s ficou no chão." % Items.describe_list(left))
		overflow.emit(left)


## Peso carregado (kg): conteúdo dos recipientes (a mochila alivia parte) + itens vestidos.
func carried_weight() -> float:
	var w := Items.list_weight(bags["bolsos"]) + Items.list_weight(bags["coldre"])
	var red := 0.0
	if not equip["mochila"].is_empty():
		red = float(Items.def(equip["mochila"]["id"]).get("reducao", 0.0))
	w += Items.list_weight(bags["mochila"]) * (1.0 - red)
	for slot in equip:
		if not equip[slot].is_empty():
			w += Items.weight(equip[slot])
	return w


## Peso confortável: 16 kg com Força 5 e Atletismo 0.
func carry_max() -> float:
	return CARRY_MAX + 1.2 * float(forca - 5) + 0.6 * float(level("atletismo"))


func load_ratio() -> float:
	return carried_weight() / carry_max()


## Desgasta a arma da mão após um golpe que acertou. Ela pode quebrar.
func wear_weapon() -> void:
	var w := weapon_inst()
	if w.is_empty() or not w.has("dur"):
		return
	var gasto := float(Items.def(w["id"]).get("gasto", 1.0)) * (1.0 - 0.04 * float(level("combate")))
	if has_trait("desajeitado"):
		gasto *= 1.25
	w["dur"] = maxf(0.0, float(w["dur"]) - gasto)
	if float(w["dur"]) <= 0.0:
		message.emit("Sua arma quebrou: %s!" % DB.item_name(w["id"]))
		remove_u(hand_u)
		hand_u = 0
	elif float(w["dur"]) < 15.0:
		_warn("arma_" + str(hand_u), "Sua arma está quase quebrando.", 30.0)


## Conserta a durabilidade de um item com fita adesiva.
## Itens que só se consertam na mesa de reparos (armas de fogo, mochilas e coldres).
static func needs_bench(id: String) -> bool:
	return String(Items.def(id).get("tipo", "")) in ["arma_fogo", "mochila", "coldre"]


## Conserto. Fita adesiva conserta armas brancas, ferramentas e a máscara em qualquer lugar
## (+30%); na mesa de reparos ('bench') tudo conserta mais (+45%), e armas de fogo, mochilas
## e coldres só lá (a arma de fogo gasta também 1 sucata).
func repair(u: int, bench := false) -> void:
	var f := find(u)
	if f.is_empty() or not f[1].has("dur"):
		return
	var inst: Dictionary = f[1]
	var id: String = inst["id"]
	if float(inst["dur"]) >= 100.0:
		message.emit("Não precisa de conserto.")
		return
	if needs_bench(id) and not bench:
		message.emit("%s só se conserta numa mesa de reparos." % DB.item_name(id))
		return
	var gun := String(Items.def(id).get("tipo", "")) == "arma_fogo"
	if count("fita") <= 0 or (gun and count("sucata") <= 0):
		message.emit("Você precisa de fita de lona%s." % (" e 1 sucata" if gun else ""))
		return
	spend("fita")
	if gun:
		take_item("sucata")
	var base := 45.0 if bench else 30.0
	inst["dur"] = minf(100.0, float(inst["dur"]) + base + 3.0 * float(level("mecanica")))
	add_xp("mecanica", 5.0 if bench else 3.0)
	message.emit("Consertado: %s (%d%%)." % [DB.item_name(id), int(float(inst["dur"]))])


# ---------------------------------------------------------------- habilidades
func level(skill: String) -> int:
	return int(skills[skill]["lv"])


func xp_needed(lv: int) -> float:
	return 50.0 * float(lv + 1)


func add_xp(skill: String, amount: float) -> void:
	var s: Dictionary = skills[skill]
	if int(s["lv"]) >= 10:
		return
	s["xp"] = float(s["xp"]) + amount
	while int(s["lv"]) < 10 and float(s["xp"]) >= xp_needed(int(s["lv"])):
		s["xp"] = float(s["xp"]) - xp_needed(int(s["lv"]))
		s["lv"] = int(s["lv"]) + 1
		message.emit("Habilidade %s subiu para o nível %d!" % [DB.SKILLS[skill], int(s["lv"])])


func add_xp_map(xp: Dictionary) -> void:
	for k in xp:
		add_xp(k, float(xp[k]))


func meets(req: Dictionary) -> bool:
	for k in req:
		if level(k) < int(req[k]):
			return false
	return true


# ---------------------------------------------------------------- simulação
func tick(delta: float, env: Dictionary) -> void:
	if not alive:
		return
	time_alive += delta
	var moving: bool = env.get("moving", false)
	var spore: float = env.get("spore", 0.0)
	_tick_stamina(delta, moving and env.get("sprinting", false))
	_tick_gear(delta)
	_tick_metabolism(delta, moving)
	_tick_implants(delta, moving or env.get("combat", false))
	_tick_neural(delta)
	_tick_pathogen(delta, spore, env.get("purifier", false))
	_tick_health(delta)
	_tick_body(delta, env)
	_check_death()


## Aquecimento da roupa vestida (molhada esquenta bem menos).
func clothing_warmth() -> float:
	var w := 0.0
	for slot: String in DB.ROUPA_SLOTS:
		if not equip[slot].is_empty():
			w += float(Items.def(equip[slot]["id"]).get("calor", 0.0))
	return w * (1.0 - 0.6 * molhado / 100.0)


## Sensação térmica (°C) com o ambiente que o mundo informa: temperatura do ar, abrigo
## (dentro de um prédio), fogo por perto e roupa.
func felt_temp(env: Dictionary) -> float:
	return float(env.get("temp", 20.0)) + clothing_warmth() * 1.4 + (7.0 if env.get("abrigo", false) else 0.0) \
		+ (14.0 if env.get("fogo", false) else 0.0)


## Sono, frio e chuva.
func _tick_body(delta: float, env: Dictionary) -> void:
	# sono: cai acordado (mais rápido correndo e lutando); dormindo, recupera (cama é melhor)
	if sleeping:
		sono = minf(100.0, sono + 100.0 / 240.0 * sleep_bed * delta)
		stamina = minf(max_stamina(), stamina + 6.0 * delta)
		if sono >= 99.9:
			sleeping = false
			message.emit("Você acordou descansado.")
	else:
		sono = maxf(0.0, sono - 100.0 / 2160.0 * delta * (1.4 if env.get("combat", false) else 1.0))
		if sono < 25.0:
			_warn("sono", "Você está exausto: durma numa cama ([E]).", 60.0)
	# chuva molha quem está fora de prédio; seca no abrigo e perto do fogo
	var under := bool(env.get("abrigo", false))
	if env.get("vau", false):
		# atravessando o rio a pé: molha até a cintura
		molhado = minf(100.0, maxf(molhado, minf(60.0, molhado + 25.0 * delta)))
	elif env.get("chuva", false) and not under:
		molhado = minf(100.0, molhado + 1.6 * delta)
	elif env.get("fogo", false):
		molhado = maxf(0.0, molhado - 1.6 * delta)
	elif under:
		molhado = maxf(0.0, molhado - 0.5 * delta)
	else:
		molhado = maxf(0.0, molhado - 0.15 * delta)
	# temperatura do corpo
	var feel := felt_temp(env)
	if feel < 16.0:
		temp_corpo = maxf(28.0, temp_corpo - (16.0 - feel) * 0.0035 * delta)
	elif temp_corpo < 37.0:
		temp_corpo = minf(37.0, temp_corpo + (0.02 + maxf(0.0, feel - 18.0) * 0.004) * delta)
	if temp_corpo < 34.0:
		_hurt((0.05 if temp_corpo >= 32.0 else 0.25) * delta, "Hipotermia")
		_warn("hipotermia", "HIPOTERMIA! Procure abrigo, fogo e roupa seca.", 25.0)
	elif temp_corpo < 35.5:
		_warn("frio", "Você está com frio.", 60.0)


func _warn(key: String, text: String, cooldown: float = 40.0) -> void:
	if time_alive - float(_warn_t.get(key, -999.0)) >= cooldown:
		_warn_t[key] = time_alive
		message.emit(text)


func _hurt(amount: float, cause: String) -> void:
	if god:
		return
	hp = maxf(0.0, hp - amount)
	_last_hurt_cause = cause


## Analgésico e lanterna.
func _tick_gear(delta: float) -> void:
	pain_t = maxf(0.0, pain_t - delta)
	grab_t = maxf(0.0, grab_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	trap_cd = maxf(0.0, trap_cd - delta)
	if stam_t > 0.0:
		stam_t = maxf(0.0, stam_t - delta)
		if stam_t <= 0.0:
			stam_mult = 1.0
			message.emit("O efeito do estimulante passou.")
	well_fed_t = maxf(0.0, well_fed_t - delta)
	if light_u != 0:
		var f := find(light_u)
		if f.is_empty():
			light_u = 0
			return
		var lamp: Dictionary = f[1]
		lamp["carga"] = maxf(0.0, float(lamp["carga"]) - 0.4 * delta)
		if float(lamp["carga"]) <= 0.0:
			light_u = 0
			message.emit("A lanterna apagou: pilhas gastas.")


func lantern_on() -> bool:
	return light_u != 0


## Ferramentas que faltam (vazio = tem todas).
func missing_tools(tools: Array) -> String:
	var miss: Array[String] = []
	for t in tools:
		if count(t) <= 0:
			miss.append(DB.item_name(t))
	return ", ".join(miss)


# ---------------------------------------------------------------- ruído e visibilidade
## Raio (isométrico, px) do barulho dos passos.
func step_noise(sprinting: bool, sneaking: bool) -> float:
	var r := 110.0
	if sprinting:
		r = 270.0
	elif sneaking:
		r = 35.0
	r *= 1.0 - 0.06 * float(level("furtividade"))
	if has_trait("barulhento"):
		r *= 1.4
	if load_ratio() > 1.0:
		r *= 1.25
	return r


## Multiplicador da distância em que os infectados te enxergam.
func visibility(sprinting: bool, sneaking: bool) -> float:
	var v := 1.0
	if sneaking:
		v = 0.55
	elif sprinting:
		v = 1.15
	v *= 1.0 - 0.05 * float(level("furtividade"))
	if lantern_on():
		v *= 1.4
	return v


func has_trait(t: String) -> bool:
	return t in traits


# ---------------------------------------------------------------- estamina
func max_stamina() -> float:
	var m := 100.0 + 6.0 * float(resist - 5) + 3.0 * float(level("atletismo"))
	if has_trait("atleta"):
		m *= 1.2
	return m


## Dá para correr? (o dono do personagem consulta para decidir a velocidade)
func can_sprint() -> bool:
	return stamina > 8.0 and load_ratio() < 1.35


## Gasta estamina (golpes, corrida). Devolve false se não tinha o bastante.
func spend_stamina(amount: float) -> bool:
	if has_trait("asmatico"):
		amount *= 1.3
	var ok := stamina >= amount * 0.5
	stamina = maxf(0.0, stamina - amount)
	return ok


func _tick_stamina(delta: float, sprinting: bool) -> void:
	if sprinting and can_sprint():
		var drain := 14.0 * (1.0 - 0.04 * float(level("atletismo")))
		if implant_active("pernas"):
			drain *= 0.7
		if load_ratio() > 1.0:
			drain *= 1.5
		spend_stamina(drain * delta)
		add_xp("atletismo", 0.35 * delta)
		return
	var regen := 9.0 + 0.8 * float(resist - 5)
	if calories < 400.0 or water < 15.0:
		regen *= 0.4
	if sono < 25.0:
		regen *= 0.6
	if temp_corpo < 35.5:
		regen *= 0.7
	if load_ratio() > 1.0:
		regen *= 0.5
	if pathogen > 60.0:
		regen *= 0.7
	if well_fed_t > 0.0:
		regen *= 1.5
	if stam_t > 0.0:
		regen *= stam_mult
	stamina = minf(max_stamina(), stamina + regen * delta)


func _tick_metabolism(delta: float, moving: bool) -> void:
	var k := 1.5 if moving else 1.0
	if has_trait("glutao"):
		k *= 1.3
	if has_trait("metabolismo_lento"):
		k *= 0.75
	calories = maxf(0.0, calories - 0.55 * k * delta)
	water = maxf(0.0, water - 0.11 * k * delta)
	if calories <= 0.0:
		_hurt(1.0 * delta, "Fome")
		_warn("fome", "Você está morrendo de fome!")
	elif calories < 400.0:
		_warn("fome", "Você está com muita fome.")
	if water <= 0.0:
		_hurt(1.5 * delta, "Sede")
		_warn("sede", "Você está desidratado!")
	elif water < 20.0:
		_warn("sede", "Você está com muita sede.")


func implant_active(slot: String) -> bool:
	return implants.has(slot) and battery > 0.0 and float(implants[slot]["integ"]) > 0.0


func implant_damaged(slot: String) -> bool:
	if not implants.has(slot):
		return false
	return battery <= 0.0 or float(implants[slot]["integ"]) < 30.0


func _tick_implants(delta: float, exerting: bool) -> void:
	if implants.is_empty():
		heat = move_toward(heat, 0.0, 0.5 * delta)
		return
	var target := 0.0
	var drain := 0.0
	for slot in implants:
		var imp: Dictionary = implants[slot]
		var def: Dictionary = DB.IMPLANTS[imp["id"]]
		if battery > 0.0 and float(imp["integ"]) > 0.0:
			drain += float(def["dreno"])
			var bad := 1.0 + (1.0 - float(imp["integ"]) / 100.0) * 2.0
			target += float(def["calor"]) * 30.0 * bad
			imp["integ"] = maxf(0.0, float(imp["integ"]) - 0.015 * delta)
	if exerting:
		target += 8.0
	battery = maxf(0.0, battery - drain * delta)
	heat = move_toward(heat, minf(target, 100.0), 0.6 * delta)
	if battery <= 0.0 and drain == 0.0:
		_warn("bateria", "A célula galvânica das próteses esgotou! Elas estão paradas.")
	if heat > 70.0:
		_hurt(0.4 * delta * float(implants.size()), "Superaquecimento das próteses")
		_warn("calor", "Superaquecimento! As engrenagens das próteses estão queimando sua pele.")


func immune_mult() -> float:
	var m := 1.0
	for slot in implants:
		if implant_damaged(slot):
			m += 0.5
	if heat > 70.0:
		m += 0.5
	return minf(m, 2.5)


func exposure_factor() -> float:
	var f := 1.0
	if has_mask() and filter_pct() > 0.0:
		# máscara com vedação ruim vaza: 8% com vedação perfeita, até 60% sem vedação
		f *= lerpf(0.6, 0.08, mask_seal() / 100.0)
	if implant_active("pulmao"):
		f *= 0.35
	if has_trait("pulmao_aco"):
		f *= 0.75
	elif has_trait("pulmao_fraco"):
		f *= 1.25
	return f


func _tick_pathogen(delta: float, spore: float, purifier: bool) -> void:
	var f := exposure_factor()
	var hz := clampf(gear_bonus("esporos"), 0.0, 0.8)
	var rate := 0.015 + 1.2 * pow(spore, 1.5) * f * (1.0 - hz)
	if spore >= 1.0:
		rate += 18.0 * (0.4 + 0.6 * f)
		_warn("letal", "CONCENTRAÇÃO LETAL DE ESPOROS! Volte agora!", 6.0)
	if tainted_t > 0.0:
		rate += 0.35
		tainted_t -= delta
	rate *= immune_mult()
	if has_trait("imune_forte"):
		rate *= 0.85
	if suppress_t > 0.0:
		rate *= 0.5
		pathogen -= 0.4 * delta
		suppress_t -= delta
	if purifier:
		rate *= 0.2
		pathogen -= 4.0 * delta
	pathogen = clampf(pathogen + rate * delta, 0.0, 100.0)
	if has_mask() and filter_pct() > 0.0:
		var mask: Dictionary = equip["mascara"]
		if spore >= 1.0:
			mask["filtro"] = 0.0
			message.emit("O filtro foi destruído pelos esporos!")
		else:
			mask["filtro"] = maxf(0.0, filter_pct() - (spore * spore * 1.2 + spore * 0.2) * delta * (1.0 - hz * 0.6))
			if filter_pct() <= 0.0:
				message.emit("O filtro da máscara acabou!")
			elif filter_pct() < 15.0:
				_warn("filtro", "O filtro está quase no fim.")
		if mask_seal() < 30.0:
			_warn("vedacao", "A vedação da máscara está ruim: conserte com fita de lona.", 60.0)
	if pathogen > 75.0:
		_warn("patogeno", "A carga patogênica está crítica!", 25.0)


## Vida, sangramento, cura e a perna machucada.
func _tick_health(delta: float) -> void:
	var healing_ok := calories > 300.0 and water > 15.0
	if bleed > 0.0:
		_hurt(bleed * delta, "Sangramento")
		# sangramento leve estanca sozinho, devagar
		if bleed < BLEED_LEVE:
			bleed = maxf(0.0, bleed - 0.0006 * delta)
			if bleed <= 0.0:
				message.emit("O sangramento parou sozinho.")
		elif hp < 40.0:
			_warn("sangue", "Você está perdendo muito sangue! Use uma bandagem.", 20.0)
	if regen_t > 0.0:
		hp = minf(MAX_HP, hp + regen_rate * delta)
		regen_t = maxf(0.0, regen_t - delta)
	elif bleed <= 0.0 and healing_ok and hp < MAX_HP:
		hp = minf(MAX_HP, hp + 0.04 * delta * (1.3 if well_fed_t > 0.0 else 1.0))
	_tick_bone(delta, healing_ok)


## Perna: torção sara sozinha (mais rápido com tala); fratura só sara imobilizada.
func _tick_bone(delta: float, healing_ok: bool) -> void:
	if perna == 0:
		return
	var rate := 0.0
	if perna == 1:
		rate = 100.0 / (90.0 if tala else 240.0)
	elif tala and healing_ok:
		rate = 100.0 / 600.0
	osso_t += rate * delta
	if osso_t >= 100.0:
		var was := perna
		perna = 0
		osso_t = 0.0
		tala = false
		message.emit("A perna sarou%s." % (" (a tala foi tirada)" if was == 2 else ""))
	elif perna == 2 and not tala:
		_warn("fratura", "Perna quebrada: imobilize com uma tala.", 45.0)


## Lentidão pela perna: torção e fratura; a tala e o analgésico aliviam.
func leg_penalty() -> float:
	if perna == 0:
		return 0.0
	var p := 0.15 if perna == 1 else 0.35
	if tala:
		p *= 0.4 if perna == 1 else 0.55
	if pain_t > 0.0:
		p *= 0.5
	return p


## Machuca a perna: 1 = torção, 2 = fratura (não piora o que já é pior).
func injure_leg(level_: int) -> void:
	if level_ <= perna:
		return
	perna = level_
	osso_t = 0.0
	tala = false
	message.emit("Você quebrou a perna!" if level_ == 2 else "Você torceu a perna.")


## Queda ou pulo de 'h' metros (andares, janelas, telhados). Abaixo de 2,5 m não machuca.
## Atletismo amortece (0,3 m por nível); as pernas pneumáticas também.
func fall_injury(h: float) -> void:
	if god:
		return
	var told := h
	h -= 0.3 * float(level("atletismo"))
	if implant_active("pernas"):
		h -= 1.5
	if h < 2.5:
		return
	if h < 4.0:
		_hurt(6.0, "Queda")
		if rng.randf() < 0.55:
			injure_leg(1)
	elif h < 7.0:
		_hurt(rng.randf_range(15.0, 28.0), "Queda")
		injure_leg(2 if rng.randf() < 0.45 else 1)
	elif h < 11.0:
		_hurt(40.0, "Queda")
		injure_leg(2)
	else:
		_hurt(60.0 + (h - 11.0) * 9.0, "Queda")
		injure_leg(2)
	message.emit("Queda de %.0f m!" % told)


func kill(cause: String, kind: String) -> void:
	if alive:
		_die(cause, kind)


func _check_death() -> void:
	if not alive:
		return
	if god:
		pathogen = minf(pathogen, 99.0)
		hp = maxf(hp, 1.0)
		return
	if pathogen >= 100.0:
		_die("Carga patogênica em 100%", "infeccao")
	elif hp <= 0.0:
		_die(_last_hurt_cause, "fisica")


func _die(cause: String, kind: String) -> void:
	alive = false
	death_cause = cause
	death_kind = kind
	message.emit("Você morreu: %s." % cause)


# ---------------------------------------------------------------- combate
## Golpe. A roupa reduz o dano e a chance de sangrar. Nem todo golpe abre sangramento: a
## chance cresce com o dano. Se já está sangrando, um novo corte piora o sangramento.
func damage(amount: float, cause := "Trauma em combate") -> void:
	if god:
		return
	if implant_active("pele"):
		amount *= 0.75
	var arm := armor()
	var raw := amount
	amount *= 1.0 - float(arm[0])
	_wear_clothes(raw)
	_hurt(amount, cause)
	var p_bleed := 0.0
	if amount >= 4.0:
		p_bleed = clampf(0.1 + amount * 0.022, 0.0, 0.75) * (1.0 - float(arm[1]))
		if has_trait("sangue_fino"):
			p_bleed = minf(0.9, p_bleed * 1.25)
	var text := "Golpe (-%d)." % int(amount)
	if rng.randf() < p_bleed:
		var add := amount * (0.03 if amount >= 16.0 else 0.012) * (1.3 if has_trait("sangue_fino") else 1.0)
		if bleed > 0.0:
			bleed += add * 0.8
			text = "O sangramento piorou! (-%d)" % int(amount)
		else:
			bleed = add
			text = "Você está sangrando (-%d)." % int(amount)
	# próteses gastam com os golpes; a máscara perde vedação com golpes na cabeça
	for slot in implants:
		if rng.randf() < 0.3:
			implants[slot]["integ"] = maxf(0.0, float(implants[slot]["integ"]) - amount * 0.4)
	if has_mask() and rng.randf() < float(ZONES["cabeca"]):
		equip["mascara"]["dur"] = maxf(0.0, mask_seal() - amount * 0.8)
	message.emit(text)


func melee_damage() -> float:
	var dmg := 14.0 + 1.5 * float(forca - 5)
	var w := weapon_inst()
	if not w.is_empty():
		var bonus := float(Items.def(w["id"]).get("dano", 0.0))
		dmg += bonus * (0.6 if float(w.get("dur", 100.0)) < 25.0 else 1.0)
	if implant_active("braco_d"):
		dmg += 14.0
	dmg *= 1.0 + 0.04 * float(level("combate")) + gear_bonus("combate")
	if hp < 25.0 and pain_t <= 0.0:
		dmg *= 0.8
	if stamina < 8.0:
		dmg *= 0.6
	return dmg


## Estamina de um golpe (armas pesadas cansam mais; Luta reduz).
func attack_stamina() -> float:
	var w := weapon_inst()
	var weight := Items.unit_weight(w) if not w.is_empty() else 0.3
	return (6.0 + 3.0 * weight) * (1.0 - 0.05 * float(level("combate")))


## Servidor: um golpe acertou alguém.
func on_melee_hit() -> void:
	add_xp("combate", 2.5)
	wear_weapon()


func speed_mult() -> float:
	var m := 1.0
	if hp < 25.0 and pain_t <= 0.0:
		m -= 0.1
	m -= leg_penalty()
	m += 0.015 * float(level("atletismo"))
	if implant_active("pernas"):
		m += 0.12
	if has_trait("lento"):
		m -= 0.08
	if pathogen > 60.0:
		m -= 0.15 * (pathogen - 60.0) / 40.0
	var r := load_ratio()
	if r > 1.0:
		m -= minf(0.45, (r - 1.0) * 0.6)
	if temp_corpo < 34.0:
		m -= 0.15
	if sono < 8.0:
		m -= 0.1
	if slow_t > 0.0:
		m *= 0.5
	if grab_t > 0.0:
		return 0.0  # agarrado: não sai do lugar
	return maxf(0.3, m)


# ---------------------------------------------------------------- uso de itens
## Usa um item. ref: id único (int) ou id do item (String, usa a primeira unidade).
func use_item(ref: Variant) -> void:
	var inst := _resolve(ref)
	if inst.is_empty():
		return
	var id: String = inst["id"]
	var u := int(inst.get("u", 0))
	var def: Dictionary = DB.ITEMS[id]
	match String(def["tipo"]):
		"comida":
			if def.get("lata", false) and count("abridor") + count("faca") + count("machete") <= 0:
				message.emit("Você precisa de um abridor de latas, faca ou machete para abrir.")
				return
			var fl := Items.freshness(inst)
			var spoiled := Items.spoiled(inst)
			remove_u(u)
			var cal := float(def["cal"])
			water = minf(100.0, water + float(def.get("agua", 0.0)))
			if def.get("cozido", false) and not spoiled:
				well_fed_t = 180.0
			if spoiled:
				calories = minf(MAX_CAL, calories + cal * 0.4)
				# Culinária reduz a intoxicação (GDD 6.2)
				pathogen = minf(100.0, pathogen + 8.0 * (1.0 - 0.08 * float(level("culinaria"))))
				tainted_t = maxf(tainted_t, 60.0)
				message.emit("Comida estragada! Você se sente mal (%s)." % def["nome"])
			elif inst.has("venc") and fl < 0.35:
				calories = minf(MAX_CAL, calories + cal * 0.75)
				message.emit("Você comeu: %s (passado)." % def["nome"])
			elif def.get("cru", false):
				calories = minf(MAX_CAL, calories + cal)
				_hurt(6.0, "Intoxicação alimentar")
				tainted_t = maxf(tainted_t, 30.0)
				message.emit("Carne crua: mata a fome, mas você passa mal. Asse no fogareiro.")
			else:
				calories = minf(MAX_CAL, calories + cal)
				message.emit("Você comeu: %s." % def["nome"])
		"bebida":
			remove_u(u)
			water = minf(100.0, water + float(def["agua"]))
			if not def["limpa"]:
				pathogen = minf(100.0, pathogen + 6.0)
				tainted_t = 60.0
				message.emit("Água contaminada! A infecção acelera.")
			else:
				message.emit("Você bebeu água limpa.")
		"mascara", "mochila", "coldre", "roupa":
			var es := slot_of(id)
			if equip.has(es) and int(equip[es].get("u", -1)) == u:
				unwear(es)
			else:
				var part := remove_u(u)
				if not part.is_empty():
					wear(part)
		"filtro":
			if not has_mask():
				message.emit("Vista uma máscara de gás primeiro.")
				return
			remove_u(u)
			equip["mascara"]["filtro"] = 100.0
			message.emit("Filtro novo instalado (100%).")
		"supressor":
			remove_u(u)
			suppress_t = 60.0
			pathogen = maxf(0.0, pathogen - 15.0)
			message.emit("Supressor aplicado: carga -15%.")
		"bateria":
			if battery >= 99.5:
				message.emit("A célula das próteses já está cheia.")
				return
			# uma bateria cheia (carga 100) vale 60% da bateria dos implantes
			var amount := minf(100.0 - battery, float(inst["carga"]) * 0.6)
			battery += amount
			inst["carga"] = float(inst["carga"]) - amount / 0.6
			if float(inst["carga"]) <= 0.5:
				remove_u(u)
			message.emit("Próteses recarregadas (%d%%)." % int(battery))
		"manual":
			remove_u(u)
			message.emit("Você estudou: %s." % def["nome"])
			add_xp(String(def["skill"]), float(def["xp"]))
		"arma", "arma_fogo":
			hand_u = 0 if hand_u == u else u
			message.emit("Arma %s: %s." % [("na mão" if hand_u == u else "guardada"), def["nome"]])
		"lanterna":
			if light_u == u:
				light_u = 0
				message.emit("Lanterna apagada.")
			elif float(inst.get("carga", 0.0)) <= 0.0:
				message.emit("A lanterna está sem pilhas.")
			else:
				light_u = u
				message.emit("Lanterna acesa: você enxerga melhor, mas é visto de mais longe.")
		"pilha":
			var lamp: Dictionary = {}
			for it in all_items():
				if it["id"] == "lanterna" and (lamp.is_empty() or float(it["carga"]) < float(lamp["carga"])):
					lamp = it
			if lamp.is_empty():
				message.emit("Você não tem lanterna.")
				return
			remove_u(u)
			lamp["carga"] = 100.0
			message.emit("Pilhas novas na lanterna.")
		"cantil":
			if float(inst.get("carga", 0.0)) >= 1.0:
				inst["carga"] = maxf(0.0, float(inst["carga"]) - float(def["uso_carga"]))
				water = minf(100.0, water + 30.0)
				message.emit("Você bebeu do cantil.")
			elif take_item("agua_limpa"):
				inst["carga"] = 100.0
				message.emit("Cantil cheio (uma garrafa de água limpa).")
			else:
				message.emit("O cantil está vazio. Encha com água limpa.")
		"regador":
			if float(inst.get("carga", 0.0)) >= 99.0:
				message.emit("O regador está cheio. Use-o num canteiro [E].")
			elif take_item("agua_suja") or take_item("agua_limpa"):
				inst["carga"] = 100.0
				message.emit("Regador cheio.")
			else:
				message.emit("Encha o regador com uma garrafa de água (limpa ou suja).")
		"med":
			apply_med(id)
		"estimulante":
			remove_u(u)
			water = minf(100.0, water + float(def.get("agua", 0.0)))
			var st: Array = def.get("estamina", [1.5, 60.0])
			stam_mult = maxf(stam_mult if stam_t > 0.0 else 1.0, float(st[0]))
			stam_t = maxf(stam_t, float(st[1]))
			stamina = minf(max_stamina(), stamina + float(def.get("estamina_ja", 0.0)))
			message.emit("%s: sua estamina volta %d%% mais rápido por %ds." % [def["nome"], int((float(st[0]) - 1.0) * 100.0), int(st[1])])
		_:
			message.emit("Use este item em outra aba.")


## Recarrega a arma de fogo da mão com a munição do inventário. Devolve as balas postas.
func reload() -> int:
	var w := weapon_inst()
	if w.is_empty() or not Items.def(w["id"]).has("pente"):
		message.emit("Você não tem arma de fogo na mão.")
		return 0
	var def := Items.def(w["id"])
	var need := int(def["pente"]) - int(float(w.get("mun", 0.0)))
	var ammo: String = def["municao"]
	var n := mini(need, count(ammo))
	if need <= 0:
		message.emit("A arma já está carregada.")
		return 0
	if n <= 0:
		message.emit("Sem %s." % DB.item_name(ammo).to_lower())
		return 0
	take_item(ammo, n)
	w["mun"] = float(w.get("mun", 0.0)) + float(n)
	add_xp("pontaria", 1.0)
	message.emit("Recarregado: %d/%d." % [int(w["mun"]), int(def["pente"])])
	return n


func firearm() -> Dictionary:
	var w := weapon_inst()
	if not w.is_empty() and Items.def(w["id"]).has("pente"):
		return w
	return {}


## Gasta combustível dos galões para abastecer um gerador. Devolve o quanto abasteceu
## (pontos de 0-100 do gerador; um galão cheio vale 50).
func pour_fuel(need: float) -> float:
	var got := 0.0
	for inst in all_items().duplicate():
		if got >= need or inst["id"] != "combustivel":
			continue
		var amount := minf(need - got, float(inst["carga"]) * 0.5)
		got += amount
		inst["carga"] = float(inst["carga"]) - amount / 0.5
		if float(inst["carga"]) <= 0.5:
			remove_u(int(inst["u"]))
	return got


# ---------------------------------------------------------------- medicina
## Mensagem para o paciente e, se for outra pessoa, também para quem trata.
func _say_both(h: SurvivorData, text: String) -> void:
	message.emit(text)
	if h != self:
		h.message.emit(text)


## Usa um remédio ou curativo (DB.ITEMS tipo "med") neste sobrevivente. 'healer' é quem
## aplica (os suprimentos, a Medicina e a roupa de médico são dele); null = o próprio.
## Campos do item: cura (vida na hora), estanca (fração do sangramento que para), reduz
## (fração do sangramento que diminui), regen [vida/s, segundos], dor (s de analgésico),
## osso (imobiliza a perna). Tratar outra pessoa rende 50% mais experiência.
func apply_med(item_id: String, healer: SurvivorData = null) -> bool:
	var h: SurvivorData = healer if healer != null else self
	var def: Dictionary = DB.ITEMS.get(item_id, {})
	if String(def.get("tipo", "")) != "med":
		return false
	var why := med_useless(item_id)
	if why != "":
		h.message.emit(why)
		return false
	if not h.take_item(item_id):
		h.message.emit("Sem %s." % DB.item_name(item_id).to_lower())
		return false
	var skill := 1.0 + 0.06 * float(h.level("medicina")) + h.gear_bonus("medico")
	var got: Array[String] = []
	if def.get("osso", false):
		tala = true
		got.append("perna imobilizada")
	if float(def.get("estanca", 0.0)) > 0.0 and bleed > 0.0:
		bleed *= 1.0 - float(def["estanca"])
		if bleed < 0.005:
			bleed = 0.0
		got.append("sangramento estancado" if bleed <= 0.0 else "sangramento menor")
	if float(def.get("reduz", 0.0)) > 0.0 and bleed > 0.0:
		bleed *= 1.0 - minf(0.95, float(def["reduz"]) * (0.9 + 0.1 * skill))
		got.append("sangramento menor")
	var cura := float(def.get("cura", 0.0)) * skill
	if cura > 0.0:
		var before := hp
		hp = minf(MAX_HP, hp + cura)
		if hp - before >= 1.0:
			got.append("+%d de vida" % int(hp - before))
	if def.has("regen"):
		var rg: Array = def["regen"]
		regen_rate = maxf(regen_rate if regen_t > 0.0 else 0.0, float(rg[0]) * skill)
		regen_t = maxf(regen_t, float(rg[1]))
		got.append("cura %.1f/s por %ds" % [regen_rate, int(rg[1])])
	if float(def.get("dor", 0.0)) > 0.0:
		pain_t = maxf(pain_t, float(def["dor"]))
		got.append("sem dor por %ds" % int(def["dor"]))
	h.add_xp("medicina", float(def.get("xp", 3.0)) * (1.5 if h != self else 1.0))
	var who := "" if h == self else " (por %s)" % h.nome
	_say_both(h, "%s%s: %s." % [DB.item_name(item_id), who, ", ".join(got) if not got.is_empty() else "aplicado"])
	return true


## Por que esse remédio não serve agora ("" = serve).
func med_useless(item_id: String) -> String:
	var def: Dictionary = DB.ITEMS.get(item_id, {})
	if def.get("osso", false) and (perna == 0 or tala):
		return "Não há perna machucada para imobilizar." if perna == 0 else "A perna já está imobilizada."
	var helps: bool = bool(def.get("osso", false)) or float(def.get("dor", 0.0)) > 0.0
	if (float(def.get("estanca", 0.0)) > 0.0 or float(def.get("reduz", 0.0)) > 0.0) and bleed > 0.0:
		helps = true
	if (float(def.get("cura", 0.0)) > 0.0 or def.has("regen")) and hp < MAX_HP - 0.5:
		helps = true
	return "" if helps else "Você não precisa disso agora."


# ---------------------------------------------------------------- cibernética
## Implantes gerais (tudo menos o processador do cérebro).
func general_count() -> int:
	var n := 0
	for slot in implants:
		if slot != "cerebro":
			n += 1
	return n


## Quantos implantes gerais o cérebro suporta agora (o processador precisa estar ligado).
func neural_capacity() -> int:
	if implant_active("cerebro"):
		return int(DB.IMPLANTS[implants["cerebro"]["id"]].get("slots", DB.NEURAL_BASE))
	return DB.NEURAL_BASE


## Sobrecarga sináptica: mais implantes do que o cérebro suporta, ou estresse alto demais.
func overloaded() -> bool:
	return general_count() > neural_capacity() or synaptic >= 80.0


func _tick_neural(delta: float) -> void:
	var target := 0.0
	for slot in implants:
		if slot != "cerebro" and implant_active(slot):
			target += float(DB.IMPLANTS[implants[slot]["id"]].get("neuro", 10.0))
	target *= 1.0 - 0.06 * float(level("cibernetica"))
	if implant_active("cerebro"):
		target *= 0.6
	if heat > 70.0:
		target += 20.0
	var over := general_count() > neural_capacity()
	if over:
		target = 100.0
	synaptic = move_toward(synaptic, clampf(target, 0.0, 100.0), (6.0 if synaptic < target else 3.0) * delta)
	if overloaded():
		heat = minf(100.0, heat + 0.4 * delta)
		if over:
			_hurt(0.15 * delta, "Colapso nervoso")
			_warn("sobrecarga", "COLAPSO NERVOSO! Próteses demais para o seu corpo (%d/%d)." % [general_count(), neural_capacity()], 20.0)
		else:
			_warn("sobrecarga", "COLAPSO NERVOSO! A tensão nervosa está alta demais.", 20.0)
	elif synaptic > 60.0:
		_warn("neural", "Tensão nervosa alta: sua visão tremula.", 45.0)


## O sobrevivente pode fazer ações complexas (fabricar, tratar, operar, construir)?
func complex_block() -> String:
	if overloaded():
		return "Colapso nervoso: suas mãos não obedecem."
	return ""


## Cirurgia de implante. 'surgeon' opera (o implante, o kit e as habilidades são dele);
## null = o próprio sobrevivente se opera (o encaixe sai imperfeito: integridade 80%).
func install_implant(item_id: String, surgeon: SurvivorData = null) -> void:
	var h: SurvivorData = surgeon if surgeon != null else self
	if not DB.IMPLANTS.has(item_id) or h.count(item_id) <= 0:
		return
	var def: Dictionary = DB.IMPLANTS[item_id]
	var slot: String = def["slot"]
	if implants.has(slot):
		h.message.emit("Esse encaixe já tem uma prótese.")
		return
	if h.count("kit_cirurgico") <= 0:
		h.message.emit("Você precisa de um kit cirúrgico.")
		return
	h.take_item("kit_cirurgico")
	h.take_item(item_id)
	# sem suporte neural o corpo rejeita o implante na hora (GDD 4)
	if slot != "cerebro" and general_count() >= neural_capacity():
		_hurt(20.0, "Cirurgia")
		synaptic = 100.0
		h.add_xp("cibernetica", 6.0)
		if h != self:
			h.message.emit("O corpo do paciente rejeitou a prótese: ele não tem regulador craniano que aguente.")
		message.emit("REJEIÇÃO IMEDIATA: seu corpo não aguenta mais uma prótese (%d/%d). A prótese foi perdida." % [general_count(), neural_capacity()])
		return
	var deficit := 0
	for k in def["req"]:
		deficit += maxi(0, int(def["req"][k]) - h.level(k))
	if deficit == 0:
		implants[slot] = {"id": item_id, "integ": 100.0 if h != self else 80.0}
		h.add_xp("medicina", 30.0)
		h.add_xp("cibernetica", 30.0)
		_say_both(h, "Prótese instalada com sucesso: %s%s." % [DB.item_name(item_id),
			"" if h != self else " (operar a si mesmo deixou o encaixe imperfeito: 80%)"])
		return
	var r := rng.randf()
	var death_p := 0.0 if deficit < 2 else 0.30
	var crit_p := 0.35 if deficit < 2 else 0.45
	if h.has_trait("maos_firmes"):
		crit_p *= 0.6
	if r < death_p:
		_hurt(999.0, "Cirurgia fracassada")
		message.emit("A cirurgia deu errado de forma fatal...")
	elif r < death_p + crit_p:
		_hurt(35.0, "Cirurgia")
		bleed += 0.25
		message.emit("FALHA CRÍTICA na cirurgia! A prótese foi destruída.")
		add_xp("medicina", 10.0)
	else:
		implants[slot] = {"id": item_id, "integ": 55.0}
		_say_both(h, "Instalado com muita sorte, mas mal encaixado (integridade 55%).")
		h.add_xp("medicina", 12.0)
		h.add_xp("cibernetica", 12.0)


## Remove um implante (gasta um kit cirúrgico). O item volta para o inventário, a não ser
## que esteja destruído. Tirar o processador com vários implantes gerais causa sobrecarga.
func remove_implant(slot: String, surgeon: SurvivorData = null) -> void:
	var h: SurvivorData = surgeon if surgeon != null else self
	if not implants.has(slot):
		return
	if h.count("kit_cirurgico") <= 0:
		h.message.emit("Você precisa de um kit cirúrgico.")
		return
	h.take_item("kit_cirurgico")
	var imp: Dictionary = implants[slot]
	var def: Dictionary = DB.IMPLANTS[imp["id"]]
	implants.erase(slot)
	var fail := maxf(0.0, 0.35 - 0.08 * float(h.level("cibernetica")))
	if rng.randf() < fail:
		_hurt(18.0, "Cirurgia")
		_say_both(h, "A remoção foi brusca: a prótese quebrou e feriu o paciente.")
	elif float(imp["integ"]) < 15.0:
		_say_both(h, "Prótese removida, mas destruída demais para reaproveitar.")
	else:
		h.give(imp["id"])
		_say_both(h, "Prótese removida: %s." % DB.item_name(imp["id"]))
	h.add_xp("cibernetica", 8.0)
	if slot == "cerebro" and general_count() > DB.NEURAL_BASE:
		message.emit("Sem o regulador craniano, seu corpo não aguenta as próteses!")


func maintain_implant(slot: String) -> void:
	if not implants.has(slot):
		return
	if not take_item("sucata"):
		message.emit("Manutenção precisa de 1 sucata.")
		return
	var chance_fail := 0.3 if level("cibernetica") < 1 else 0.0
	if rng.randf() < chance_fail:
		message.emit("A manutenção falhou (sucata perdida).")
		return
	implants[slot]["integ"] = minf(100.0, float(implants[slot]["integ"]) + 35.0)
	add_xp("cibernetica", 10.0)
	message.emit("Manutenção feita: %s." % DB.IMPLANT_SLOTS[slot])


## Fabrica. 'paid' = os materiais já foram pagos (com recipientes próximos, pelo World).
## Fabrica. Devolve true se os materiais foram gastos (mesmo que a comida tenha queimado).
func craft(recipe: String, paid := false) -> bool:
	var def: Dictionary = DB.CRAFTS[recipe]
	if not meets(def["req"]):
		message.emit("Habilidade insuficiente: %s." % DB.req_text(def["req"]))
		return false
	if not paid and not can_afford(def["custo"]):
		message.emit("Faltam materiais: %s." % DB.cost_text(def["custo"]))
		return false
	var miss := missing_tools(def.get("ferramentas", []))
	if miss != "":
		message.emit("Falta ferramenta: %s." % miss)
		return false
	if not paid:
		pay(def["custo"])
	var out_id := String(def.get("saida", recipe))
	if def.has("estacao") and String(Items.def(out_id).get("tipo", "")) == "comida":
		# cozinhar pode queimar sem prática de Culinária
		var burn := maxf(0.0, 0.2 - 0.05 * float(level("culinaria")))
		if rng.randf() < burn:
			add_xp("culinaria", 3.0)
			message.emit("Queimou! Os ingredientes foram perdidos (%s)." % def["nome"])
			return true
	give(out_id, int(def.get("qtd", 1)))
	add_xp_map(def["xp"])
	message.emit("Fabricado: %s." % def["nome"])
	return true


# ---------------------------------------------------------------- persistência
func to_dict() -> Dictionary:
	return {"nome": nome, "pathogen": pathogen, "calories": calories,
		"water": water, "hp": hp, "bleed": bleed, "perna": perna, "tala": tala, "osso_t": osso_t,
		"regen_rate": regen_rate, "regen_t": regen_t, "stam_mult": stam_mult, "stam_t": stam_t, "skills": skills.duplicate(true),
		"bags": bags.duplicate(true), "equip": equip.duplicate(true), "hand_u": hand_u, "next_u": _next_u,
		"implants": implants.duplicate(true), "suppress_t": suppress_t, "tainted_t": tainted_t,
		"battery": battery, "heat": heat, "time_alive": time_alive,
		"forca": forca, "resist": resist, "traits": traits.duplicate(), "stamina": stamina, "synaptic": synaptic,
		"pain_t": pain_t, "grab_t": grab_t, "slow_t": slow_t, "sono": sono, "sleeping": sleeping, "temp_corpo": temp_corpo, "molhado": molhado, "light_u": light_u, "well_fed_t": well_fed_t, "hotbar": hotbar.duplicate()}


static func from_dict(src: Dictionary) -> SurvivorData:
	var d := SurvivorData.new()
	d.nome = str(src.get("nome", "Sobrevivente"))
	d.pathogen = float(src.get("pathogen", 10.0))
	d.calories = float(src.get("calories", 1600.0))
	d.water = float(src.get("water", 80.0))
	if src.has("hp"):
		d.hp = float(src["hp"])
		d.bleed = float(src.get("bleed", 0.0))
		d.perna = int(src.get("perna", 0))
		d.tala = bool(src.get("tala", false))
		d.osso_t = float(src.get("osso_t", 0.0))
	else:
		d._migrate_limbs(src)
	d.regen_rate = float(src.get("regen_rate", 0.0))
	d.regen_t = float(src.get("regen_t", 0.0))
	d.stam_mult = float(src.get("stam_mult", 1.0))
	d.stam_t = float(src.get("stam_t", 0.0))
	d.suppress_t = float(src.get("suppress_t", 0.0))
	d.tainted_t = float(src.get("tainted_t", 0.0))
	d.battery = float(src.get("battery", 0.0))
	d.heat = float(src.get("heat", 0.0))
	d.time_alive = float(src.get("time_alive", 0.0))
	var src_skills: Dictionary = src.get("skills", {}).duplicate()
	# habilidades das versões antigas: Engenharia vira Eletrônica, Lógica vira Metalurgia
	for old in [["engenharia", "eletronica"], ["logica", "metalurgia"]]:
		if src_skills.has(old[0]) and not src_skills.has(old[1]):
			src_skills[old[1]] = src_skills[old[0]]
	for s in DB.SKILLS:
		if src_skills.has(s):
			d.skills[s] = {"lv": int(src_skills[s].get("lv", 0)), "xp": float(src_skills[s].get("xp", 0.0))}
	d.forca = clampi(int(src.get("forca", 5)), DB.ATTR_MIN, DB.ATTR_MAX)
	d.resist = clampi(int(src.get("resist", 5)), DB.ATTR_MIN, DB.ATTR_MAX)
	for t in src.get("traits", []):
		if DB.TRAITS.has(str(t)):
			d.traits.append(str(t))
	d.stamina = float(src.get("stamina", d.max_stamina()))
	d.synaptic = float(src.get("synaptic", 0.0))
	d.pain_t = float(src.get("pain_t", 0.0))
	d.grab_t = float(src.get("grab_t", 0.0))
	d.slow_t = float(src.get("slow_t", 0.0))
	d.sono = float(src.get("sono", 100.0))
	d.sleeping = bool(src.get("sleeping", false))
	d.temp_corpo = float(src.get("temp_corpo", 37.0))
	d.molhado = float(src.get("molhado", 0.0))
	d.light_u = int(src.get("light_u", 0))
	d.well_fed_t = float(src.get("well_fed_t", 0.0))
	var hb: Array = src.get("hotbar", [])
	for i in mini(5, hb.size()):
		d.hotbar[i] = str(hb[i]) if DB.ITEMS.has(str(hb[i])) else ""
	if src.has("bags"):
		var sb: Dictionary = src["bags"]
		for c in d.bags:
			d.bags[c] = Items.sanitize(sb.get(c, []))
		var se: Dictionary = src.get("equip", {})
		for slot in d.equip:
			var lst := Items.sanitize([se[slot]]) if se.get(slot) is Dictionary and not se[slot].is_empty() else []
			d.equip[slot] = lst[0] if not lst.is_empty() else {}
		d.hand_u = int(src.get("hand_u", 0))
		d._next_u = int(src.get("next_u", 1))
	else:
		d._migrate_v3(src)
	var src_imp: Dictionary = src.get("implants", {})
	for k in src_imp:
		d.implants[str(k)] = {"id": str(src_imp[k]["id"]), "integ": float(src_imp[k]["integ"])}
	return d


## Save antigo com membros: a vida vira o pior entre o sangue, a cabeça e o tronco; o
## sangramento é a soma das feridas abertas; a pior perna vira a perna.
func _migrate_limbs(src: Dictionary) -> void:
	var lm: Dictionary = src.get("limbs", {})
	hp = float(src.get("blood", MAX_HP))
	for l in ["cabeca", "torso"]:
		if lm.has(l):
			hp = minf(hp, float(lm[l].get("hp", MAX_HP)))
	hp = maxf(hp, 10.0)
	for l in lm:
		var limb: Dictionary = lm[l]
		if int(limb.get("wound", 0)) > 0 and not bool(limb.get("bandaged", false)):
			bleed += float(limb.get("bleed", 0.0))
		if str(l).begins_with("perna") and int(limb.get("osso", 0)) > perna:
			perna = int(limb["osso"])
			tala = bool(limb.get("tala", false))
			osso_t = float(limb.get("osso_t", 0.0))


## Sobrevivente salvo na versão 3 (inventário {id: n}, máscara ligada/desligada e filtro):
## converte para recipientes. Ganha uma mochila escolar para não perder os itens.
func _migrate_v3(src: Dictionary) -> void:
	var inv: Dictionary = src.get("inventory", {})
	var counts := {}
	for k in inv:
		if DB.ITEMS.has(str(k)):
			counts[str(k)] = int(inv[k])
	equip["mochila"] = Items.make("mochila_escolar")[0]
	equip["mochila"]["u"] = _next_u
	_next_u += 1
	if bool(src.get("mask_on", false)) and int(counts.get("mascara", 0)) > 0:
		counts["mascara"] = int(counts["mascara"]) - 1
		var mask: Dictionary = Items.make("mascara")[0]
		mask["filtro"] = float(src.get("filter", 0.0))
		mask["u"] = _next_u
		_next_u += 1
		equip["mascara"] = mask
	var left := receive(Items.from_counts(counts))
	for inst in left:
		_put("bolsos", inst)
	var wid := str(src.get("weapon", ""))
	if wid != "":
		var w := first_of(wid)
		hand_u = int(w.get("u", 0))
