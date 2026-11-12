extends Node
## Teste do mundo (precisa dos autoloads, então roda como cena):
##   godot --headless --path . res://tools/test_world.tscn

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FALHA ", what)


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	# fase 7: geração planejada (determinística) e vilas
	var w1 := World.new()
	w1.generate(12345)
	var w2 := World.new()
	w2.generate(12345)
	check(w1.container_data.size() == w2.container_data.size() and w1.plan.size() == w2.plan.size(),
		"mesma seed, mesmo plano (%d caixas, %d chunks)" % [w1.container_data.size(), w1.plan.size()])
	check(w1.planned_buildings.size() == w2.planned_buildings.size() and w1.road_cells.size() == w2.road_cells.size(),
		"mesmos prédios e estradas")
	var same_items := true
	for i in w1.container_data.size():
		if str(w1.container_data[i]["items"]) != str(w2.container_data[i]["items"]):
			same_items = false
	check(same_items, "mesmo loot em todas as caixas")
	check(w1.villages.size() == World.N_VILLAGES, "%d vilas" % w1.villages.size())
	# poucos lugares e longe uns dos outros; no meio, floresta, rios, lagos, vaus e pontes
	var min_gap := 1e9
	for i in w1.places.size():
		for j in i:
			min_gap = minf(min_gap, Vector2(w1.places[i]["cell"] - w1.places[j]["cell"]).length() - float(w1.places[i]["r"]) - float(w1.places[j]["r"]))
	check(w1.places.size() >= 10 and w1.places.size() <= 14 and min_gap >= MapGen.PLACE_GAP, "%d lugares, o mais perto a %d tiles do vizinho" % [w1.places.size(), int(min_gap)])
	var wet_bad := 0
	for c: Vector2i in w1.water_cells:
		if w1.road_cells.has(c) or w1.house_cells.has(c) or w1.occupied.has(c) or w1.ground_cells.has(c):
			wet_bad += 1
	check(w1.water_cells.size() > 800 and wet_bad == 0, "%d células de água, nenhuma em estrada, prédio ou objeto" % w1.water_cells.size())
	var bridge_ok := not w1.bridge_cells.is_empty()
	for c: Vector2i in w1.bridge_cells:
		if not int(w1.road_cells.get(c, -1)) in [World.T.PONTE_X, World.T.PONTE_Y] or w1.water_cells.has(c) or w1._terrain(c) == World.T.AGUA:
			bridge_ok = false
	check(bridge_ok, "%d células de ponte onde estrada cruza rio (continuam estrada)" % w1.bridge_cells.size())
	check(w1.ford_cells.size() >= 8, "%d células de vau (rio raso)" % w1.ford_cells.size())
	check(w1.tree_count > 2500, "%d árvores no mapa" % w1.tree_count)
	# saqueadores: a maioria com arma branca; animais de caça dão carne
	var wr := RandomNumberGenerator.new()
	wr.seed = 11
	var ranged_n := 0
	for i in 400:
		var wname := Raider.roll_weapon(wr)
		if not Raider.WEAPONS.has(wname) or not DB.ITEMS.has(wname):
			ranged_n = 9999
		elif float(Raider.WEAPONS[wname]["alcance"]) > 60.0:
			ranged_n += 1
	check(ranged_n > 30 and ranged_n < 110, "saqueadores: %d de 400 com arma de fogo (a maioria luta corpo a corpo)" % ranged_n)
	var meat_ok := true
	for ak: String in Animal.KINDS:
		if int(Animal.KINDS[ak]["carne"][0]) < 1:
			meat_ok = false
	check(meat_ok and Animal.KINDS.size() == 3, "veado, javali e coelho dão carne")
	check(not w1._free_cell(w1.water_cells.keys()[0]) and not w1.can_place_at("fogareiro", w1.water_cells.keys()[0]), "não dá para construir na água")
	var far := 0.0
	for v in w1.villages:
		far = maxf(far, Vector2(v.cell).length())
	check(far <= World.RADIUS * 0.72 + 1.0, "vilas fora da zona letal (mais distante: %d tiles)" % int(far))
	var vd := w1.villages[1]
	vd.request_cd = 0.0
	vd.stock["comida"] = 1.0
	check(vd.maybe_request(r, 0.0, 6.0) and not vd.request.is_empty(), "vila abre pedido de socorro")
	var lv0 := vd.level()
	vd.succeed()
	check(vd.level() >= lv0 and vd.rep > 0.0, "pedido atendido: prosperidade e reputação sobem")
	vd.request = {"tipo": "comida", "need": {"comida": 1}, "kills": 0, "prazo": 0.0, "texto": "x"}
	vd.infestation = 95.0
	vd.fail()
	check(vd.infested, "pedido ignorado com infestação alta derruba a vila")
	check(VillageData.item_category("feijao") == "comida" and VillageData.item_category("fios") == "eletronico"
		and VillageData.item_category("pregos") == "", "categorias de entrega")
	# cidades pequenas e aldeias com prédios exploráveis
	var towns := 0
	for pl in w1.places:
		if pl["tipo"] == "cidade":
			towns += 1
	check(towns >= 4 and towns <= 7, "cidades pequenas (%d), sem metrópole" % towns)
	var states := {}
	for pl in w1.places:
		states[pl["estado"]] = true
	check(states.has("viva") and states.has("abandonada") and states.has("esporos"), "lugares vivos, abandonados e tomados por esporos")
	var doors := {}
	for k in w1.map_walls:
		if String(w1.map_walls[k]["kind"]).ends_with("_porta") and int(w1.map_walls[k]["h"]) >= 0:
			doors[int(w1.map_walls[k]["h"])] = true
	var ground_houses := 0
	var towers := 0
	var floors_ok := true
	for hid3 in w1.houses:
		if w1.houses[hid3].has("tower"):
			continue
		ground_houses += 1
		if int(w1.houses[hid3].get("andares", 0)) > 1:
			towers += 1
			if (w1.houses[hid3].get("floors", []) as Array).size() != int(w1.houses[hid3]["andares"]) - 1:
				floors_ok = false
	check(w1.houses.size() > 60 and doors.size() == ground_houses, "%d prédios exploráveis no chão, todos com porta" % ground_houses)
	check(towers >= 2 and floors_ok, "%d prédios de 2-3 andares, com todos os andares" % towers)
	check(w1.stairs.size() >= towers * 2, "%d escadas" % w1.stairs.size())
	var fenced := 0
	for v in w1.villages:
		if v.infested or w1.in_safe_zone(w1.ground.map_to_local(v.cell)):
			fenced += 1
	check(fenced == w1.villages.size() and not w1.villages[0].safe, "todas as %d vilas com cerca (sem Abrigo Alfa)" % fenced)
	var partial := 0
	var extra_ok := true
	for pl2 in w1.places:
		if pl2.get("cerca_parcial", false):
			partial += 1
			if w1.villages[int(pl2["vid"])].guardas_extra < 2:
				extra_ok = false
	check(partial >= 1 and partial < w1.villages.size() and extra_ok, "%d vilas com cerca incompleta e mais guardas" % partial)
	var traps_gate := 0
	var traps := 0
	for tc2: Vector2i in w1.built:
		if String(w1.built[tc2]["kind"]) == "armadilha":
			traps += 1
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if w1.road_cells.has(tc2 + Vector2i(dx, dy)):
						traps_gate += 1
	check(traps > w1.villages.size() * 4 and traps_gate == 0, "%d espetos em volta das vilas, nenhum na rua/portão" % traps)
	# hordas simuladas longe dos jogadores: cerca melhor segura mais
	var fallen := [0, 0]
	for trial in 40:
		for t2 in 2:
			var vt := VillageData.new()
			var rr := RandomNumberGenerator.new()
			rr.seed = trial * 7 + 1
			vt.setup(0, "Teste", Vector2i(60, 0), false, rr)
			vt.wall_tier = 1 if t2 == 0 else 3
			vt.prosperity = 30.0 if t2 == 0 else 80.0
			vt.stock["comida"] = 999.0
			for st in 400:
				vt.step(rr, 0.6, false)
				if vt.infested:
					fallen[t2] += 1
					break
	check(fallen[1] < fallen[0], "cerca de nível 3 resiste mais às hordas (caíram %d x %d)" % [fallen[0], fallen[1]])
	var gates := 0
	for k in w1.map_walls:
		if w1.map_walls[k]["kind"] == "w_muro_porta":
			gates += 1
	check(gates >= w1.villages.size(), "portões nas cercas (%d)" % gates)
	# móveis guardam os itens das casas (geladeira, armário, pia...), às vezes vazios
	var furn := 0
	var furn_full := 0
	var tabs := {}
	var boxes := 0
	for cd in w1.container_data:
		if String(cd.get("art", "")) != "":
			furn += 1
			tabs[cd["table"]] = true
			if not cd["items"].is_empty():
				furn_full += 1
		else:
			boxes += 1
	check(furn > w1.houses.size() and furn_full > furn / 4 and furn_full < furn, "%d móveis com itens (%d cheios), %d caixas soltas" % [furn, furn_full, boxes])
	check(tabs.has("geladeira") and tabs.has("armario") and tabs.has("pia"), "geladeira, armário e pia têm saque próprio")
	# fechaduras: móveis e prédios trancados; a maioria com a chave escondida por perto
	var locked_c := 0
	var keys := {}
	for cd in w1.container_data:
		if int(cd.get("lock", 0)) > 0:
			locked_c += 1
		for it in cd["items"]:
			if it["id"] == "chave":
				keys[str(it["tranca"])] = true
	var locked_h := 0
	var house_keys := 0
	for hid in w1.houses:
		if int(w1.houses[hid].get("lock", 0)) > 0:
			locked_h += 1
			if keys.has("h:%d" % hid):
				house_keys += 1
	var cont_keys := 0
	for i in w1.container_data.size():
		if int(w1.container_data[i].get("lock", 0)) > 0 and keys.has("c:%d" % i):
			cont_keys += 1
	check(locked_c >= 3 and cont_keys >= locked_c / 2, "%d móveis/caixas trancados, %d com chave escondida" % [locked_c, cont_keys])
	check(locked_h >= 2 and house_keys > 0, "%d prédios trancados, %d com chave num vizinho" % [locked_h, house_keys])
	var camps := 0
	for hid2 in w1.houses:
		if int(w1.houses[hid2].get("camp", 0)) > 0:
			camps += 1
	check(camps >= 3, "%d acampamentos de saqueadores" % camps)
	var sh := w1.random_spawn_house()
	check(int(w1.houses[sh].get("lock", 0)) == 0, "o prédio de começo nunca está trancado")
	check(w1.lock_level("c:%d" % w1.container_data.size()) == 0, "fechadura inexistente conta como aberta")
	var lk_id := -1
	for i in w1.container_data.size():
		if int(w1.container_data[i].get("lock", 0)) > 0:
			lk_id = i
			break
	w1.unlocked["c:%d" % lk_id] = true
	var dl := w1.world_deltas()
	var w3 := World.new()
	w3.generate(12345)
	w3.apply_deltas(dl)
	check(w3.lock_level("c:%d" % lk_id) == 0, "fechadura aberta vai para o save")
	w3.free()
	# espiar: só de frente para a janela, não ao lado dela
	var wk := Vector3i(0, 0, -1)
	for hid3 in w1.houses:
		if not w1.houses[hid3].get("windows", []).is_empty():
			wk = w1.houses[hid3]["windows"][0]
			break
	var wmid := w1.tile_pos(w1.edge_pos(wk))
	var tc := func(c: Vector2i) -> Vector2: return w1.tile_pos(w1.ground.map_to_local(c))
	var front := Vector2i(wk.x, wk.y)
	var along_v := Vector2i(0, 1) if wk.z == 0 else Vector2i(1, 0)
	var out_front := front + (Vector2i(1, 0) if wk.z == 0 else Vector2i(0, 1))
	check(House.facing_window(tc.call(front), wmid, wk.z) and House.facing_window(tc.call(out_front), wmid, wk.z),
		"de frente para a janela (dos dois lados) dá para espiar")
	check(not House.facing_window(tc.call(front + along_v), wmid, wk.z) and not House.facing_window(tc.call(out_front - along_v), wmid, wk.z),
		"ao lado da janela, encostado na parede, não espia")
	w1.free()
	w2.free()

	print("FALHAS: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
