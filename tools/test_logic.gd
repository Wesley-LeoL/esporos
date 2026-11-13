extends SceneTree
## Teste da lógica de sobrevivência (inventário, criação, estamina...). Rodar:
##   godot --headless --path . -s res://tools/test_logic.gd

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FALHA ", what)


func _initialize() -> void:
	var game: Node = root.get_node("Game")
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var d := SurvivorData.random_survivor(r)
	var dropped: Array = []
	d.overflow.connect(func(l: Array) -> void: dropped.append_array(l))
	print("inicial: %.1f kg, mochila %.1f/%.0f L" % [d.carried_weight(), d.used_volume("mochila"), d.capacity("mochila")])
	check(d.has_mask() and d.filter_pct() == 100.0, "começa com máscara e filtro")
	check(d.capacity("mochila") == 14.0, "mochila escolar 14 L")

	# capacidade: madeira 1 L cada, cabe o que sobra e o resto cai no chão
	var free := d.capacity("mochila") - d.used_volume("mochila") + d.capacity("bolsos") - d.used_volume("bolsos")
	d.give("madeira", 30)
	check(dropped.size() == 1 and Items.count(dropped, "madeira") == 30 - floori(free + 0.001), "excedente cai no chão (%d)" % Items.count(dropped, "madeira"))
	check(d.load_ratio() > 0.0, "peso conta")

	# coldre só aceita arma
	d.wear(Items.make("coldre")[0])
	check(d.fits("coldre", Items.make("feijao")[0]) == 0, "coldre recusa comida")
	var fac: Dictionary = Items.make("faca")[0]
	check(d.fits("coldre", fac) == 1, "coldre aceita faca")
	d.store(fac)
	check(Items.count(d.bags["coldre"], "faca") == 1, "faca vai pro coldre primeiro")

	# troca de mochila: conteúdo migra para a nova
	var before := d.count("madeira")
	d.wear(Items.make("mochila_militar")[0])
	check(d.capacity("mochila") == 34.0, "mochila militar vestida")
	check(d.count("madeira") == before, "conteúdo passou para a nova mochila")
	check(d.count("mochila_escolar") == 1, "mochila antiga guardada")

	# arma: empunhar, desgastar, quebrar
	var fu := int(d.first_of("faca")["u"])
	d.use_item(fu)
	check(d.weapon_id() == "faca", "faca na mão")
	var dmg_full := d.melee_damage()
	d.weapon_inst()["dur"] = 0.5
	d.wear_weapon()
	check(d.weapon_id() == "" and d.count("faca") == 0, "faca quebrou e sumiu")
	check(d.melee_damage() < dmg_full, "sem arma, menos dano")

	# conserto com fita
	d.give("taco")
	d.give("fita")
	var tu := int(d.first_of("taco")["u"])
	d.find(tu)[1]["dur"] = 40.0
	d.repair(tu)
	check(float(d.find(tu)[1]["dur"]) >= 70.0, "fita conserta (+30)")
	check(float(d.first_of("fita")["carga"]) == 80.0, "fita gasta 1 uso")
	# arma de fogo só na mesa de reparos (fita + sucata)
	d.give("pistola")
	d.give("sucata")
	var pu := int(d.first_of("pistola")["u"])
	d.find(pu)[1]["dur"] = 30.0
	d.repair(pu)
	check(float(d.find(pu)[1]["dur"]) == 30.0, "pistola não conserta fora da mesa")
	d.repair(pu, true)
	check(float(d.find(pu)[1]["dur"]) >= 75.0, "pistola conserta na mesa (+45)")

	# apodrecimento
	game.play_time = 0.0
	d.give("maca", 1)
	var m := d.first_of("maca")
	check(Items.fresh_label(m) == "Fresco", "maçã fresca")
	game.play_time = 700.0
	check(Items.fresh_label(m) == "Passado", "maçã passada depois de 700 s")
	game.play_time = 950.0
	check(Items.spoiled(m), "maçã estragada depois de 950 s")
	var p0 := d.pathogen
	var nm0 := d.count("maca")
	d.use_item(int(m["u"]))
	check(d.pathogen > p0 and d.count("maca") == nm0 - 1, "comer estragado dá patógeno")

	# carga: bateria e combustível
	d.give("bateria")
	d.battery = 70.0
	d.use_item("bateria")
	check(is_equal_approx(d.battery, 100.0) and d.count("bateria") == 1, "bateria recarrega 30 e sobra carga")
	check(is_equal_approx(float(d.first_of("bateria")["carga"]), 50.0), "bateria fica com 50%")
	d.give("combustivel", 1)
	var w0 := d.carried_weight()
	var got := d.pour_fuel(30.0)
	check(is_equal_approx(got, 30.0) and is_equal_approx(float(d.first_of("combustivel")["carga"]), 40.0), "galão abastece 30 (usa 60% da carga)")
	check(d.carried_weight() < w0, "galão mais vazio pesa menos")

	# antisséptico com usos
	d.give("antisseptico")
	for i in 4:
		d.spend("antisseptico")
	check(d.count("antisseptico") == 0, "antisséptico acaba em 4 usos")

	# sobrecarga deixa lento
	d.give("metal", 20)
	check(d.load_ratio() > 1.0 and d.speed_mult() < 1.0, "sobrecarga reduz velocidade (%.2f)" % d.speed_mult())

	# ida e volta pelo dicionário (rede/save)
	var dd := d.to_dict()
	var d2 := SurvivorData.from_dict(JSON.parse_string(JSON.stringify(dd)))
	check(d2.count("metal") == d.count("metal") and d2.capacity("mochila") == 34.0, "to_dict/from_dict (JSON) preserva")
	check(d2.hand_u == d.hand_u and d2.weapon_id() == d.weapon_id(), "arma na mão preservada")

	# migração do save v3
	var old := {"nome": "Velho", "inventory": {"feijao": 2, "mascara": 1, "machete": 1, "sucata": 4}, "mask_on": true,
		"filter": 42.0, "weapon": "machete"}
	var d3 := SurvivorData.from_dict(old)
	check(d3.has_mask() and is_equal_approx(d3.filter_pct(), 42.0), "v3: máscara vestida com filtro 42%")
	check(d3.weapon_id() == "machete" and d3.count("feijao") == 2, "v3: arma e itens convertidos")
	check(Items.sanitize({"feijao": 3}).size() == 1, "sanitize converte dicionário antigo")

	# loot: o estado usa outro gerador (o mapa gerado não muda)
	var a := RandomNumberGenerator.new()
	a.seed = 1
	var b := RandomNumberGenerator.new()
	b.seed = 1
	var sr := RandomNumberGenerator.new()
	sr.seed = 99
	var l1 := DB.roll_loot("tecnico", 6, a, sr, 0.0)
	var l2 := DB.roll_loot("tecnico", 6, b, RandomNumberGenerator.new(), 0.0)
	check(a.state == b.state, "sorteio de loot não gasta o gerador do mapa com o estado dos itens")
	check(Items.total_units(l1) == Items.total_units(l2), "mesmos itens nos dois sorteios")

	# fase 3: criação por pontos, atributos, traços e estamina
	for pn in DB.PRESETS:
		check(DB.creation_error(DB.PRESETS[pn]) == "", "modelo '%s' é válido (%d pts)" % [pn, DB.creation_cost(DB.PRESETS[pn])])
	check(DB.creation_error({"forca": 9, "resist": 9, "skills": {"combate": 3}, "traits": []}) != "", "ficha cara demais é recusada")
	check(DB.creation_error({"forca": 5, "resist": 5, "skills": {}, "traits": ["atleta", "asmatico"]}) != "", "traços em conflito são recusados")
	check(DB.creation_error({"forca": 5, "resist": 5, "skills": {"hackear": 1}, "traits": []}) != "", "habilidade inexistente é recusada")
	var many_neg := {"forca": 5, "resist": 5, "skills": {}, "traits": ["pulmao_fraco", "glutao", "asmatico", "sangue_fino", "lento"]}
	check(DB.creation_cost(many_neg) == -DB.TRAIT_REFUND_MAX, "defeitos devolvem no máximo %d" % DB.TRAIT_REFUND_MAX)
	var brute := SurvivorData.from_spec({"nome": "Teste", "forca": 8, "resist": 6, "skills": {"combate": 3}, "traits": ["lento"]}, r)
	check(brute.nome == "Teste" and brute.level("combate") == 3, "ficha aplicada")
	check(brute.carry_max() > 19.0, "força 8 carrega mais (%.1f kg)" % brute.carry_max())
	check(brute.speed_mult() < 1.0, "traço lento reduz velocidade")
	var st0 := brute.stamina
	brute.tick(1.0, {"moving": true, "sprinting": true})
	check(brute.stamina < st0, "correr gasta estamina")
	brute.stamina = 0.0
	brute.tick(1.0, {"moving": false})
	check(brute.stamina > 0.0, "parado recupera estamina")
	var old_sk := SurvivorData.from_dict({"skills": {"engenharia": {"lv": 4, "xp": 0}, "logica": {"lv": 2, "xp": 0}}})
	check(old_sk.level("eletronica") == 4 and old_sk.level("metalurgia") == 2, "habilidades antigas convertidas")
	check(Items.sanitize([{"id": "manual_logica", "n": 1}])[0]["id"] == "manual_metalurgia", "manual antigo renomeado")

	# fase 4: núcleo neural e sobrecarga sináptica
	var cy := SurvivorData.from_spec({"nome": "Ciber", "forca": 5, "resist": 5, "skills": {"medicina": 3, "cibernetica": 3}, "traits": []}, r)
	cy.skills["medicina"]["lv"] = 6
	cy.skills["cibernetica"]["lv"] = 6
	cy.battery = 100.0
	check(cy.neural_capacity() == 1, "sem processador: 1 implante geral")
	cy.give("kit_cirurgico", 4)
	cy.give("implante_pulmao")
	cy.give("implante_braco")
	cy.install_implant("implante_pulmao")
	check(cy.implants.has("pulmao"), "primeiro implante instalado")
	cy.install_implant("implante_braco")
	check(not cy.implants.has("braco_d") and cy.count("implante_braco") == 0, "segundo implante sem processador é rejeitado")
	cy.synaptic = 0.0
	cy.give("proc_neural_mk1")
	cy.install_implant("proc_neural_mk1")
	check(cy.neural_capacity() == 2, "processador Mk1: 2 implantes")
	cy.give("implante_braco")
	cy.install_implant("implante_braco")
	check(cy.implants.has("braco_d") and not cy.overloaded(), "com processador cabe o segundo, sem sobrecarga")
	cy.battery = 0.0
	check(cy.overloaded(), "bateria vazia desliga o processador: sobrecarga")
	cy.battery = 100.0
	check(not cy.overloaded() or cy.synaptic >= 80.0, "bateria de volta: sem sobrecarga por excesso")
	check(cy.complex_block() == "" or cy.overloaded(), "ações complexas liberadas sem sobrecarga")
	cy.give("kit_cirurgico")
	cy.remove_implant("cerebro")
	check(cy.overloaded() and cy.complex_block() != "", "tirar o processador com 2 implantes causa sobrecarga e bloqueia ações")
	for i in 30:
		cy.tick(1.0, {"moving": false})
	check(cy.synaptic > 50.0, "estresse sináptico sobe na sobrecarga (%d)" % int(cy.synaptic))

	# fase 5: ferramentas, armas de fogo, som e furtividade
	var g := SurvivorData.from_spec({"nome": "Gun", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	check(g.missing_tools(["martelo"]) != "", "sem martelo: falta ferramenta")
	g.give("martelo")
	check(g.missing_tools(["martelo"]) == "", "com martelo: ok")
	g.skills["metalurgia"]["lv"] = 1
	g.give("sucata", 1)
	g.craft("pregos")
	check(g.count("pregos") == 12, "fabricar pregos rende 12")
	g.give("pistola")
	g.use_item("pistola")
	check(not g.firearm().is_empty(), "pistola na mão")
	g.give("municao_9mm", 20)
	check(g.reload() == 12 and g.count("municao_9mm") == 8, "recarga põe 12 e sobram 8")
	check(g.fits("coldre", Items.make("pistola")[0]) == 0 or g.capacity("coldre") == 0.0, "sem coldre, não cabe no coldre")
	check(g.step_noise(false, true) < g.step_noise(false, false) and g.step_noise(true, false) > g.step_noise(false, false),
		"agachado faz menos barulho, correndo mais")
	var v0 := g.visibility(false, false)
	g.give("lanterna")
	g.use_item("lanterna")
	check(g.lantern_on() and g.visibility(false, false) > v0, "lanterna acesa deixa mais visível")
	check(g.visibility(false, true) < v0 * 1.4, "agachado é menos visível")
	g.give("cantil")
	var c := g.first_of("cantil")
	c["carga"] = 0.0
	g.give("agua_limpa")
	g.use_item(int(c["u"]))
	check(float(c["carga"]) == 100.0, "cantil enche com água limpa")
	g.water = 10.0
	g.use_item(int(c["u"]))
	check(g.water > 35.0 and float(c["carga"]) < 100.0, "cantil dá água")
	g.injure_leg(1)
	var slow := g.speed_mult()
	g.give("analgesico")
	g.use_item("analgesico")
	check(g.speed_mult() > slow, "analgésico alivia a lentidão da perna machucada")

	# saúde: vida única, sangramento que piora, bandagem estanca e cura, perna e tala
	var bl := SurvivorData.from_spec({"nome": "Alvo", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	for slot: String in DB.ROUPA_SLOTS:
		bl.equip[slot] = {}
	bl.rng.seed = 7
	var plain_hits := 0
	for i in 40:
		var was := bl.bleed
		bl.hp = 100.0
		bl.damage(10.0)
		if bl.bleed <= 0.0:
			plain_hits += 1
		if was > 0.0:
			break
	check(plain_hits > 0, "golpe às vezes só dá dano, sem sangrar")
	check(bl.bleed > 0.0 and bl.hp < 100.0, "um golpe acaba abrindo sangramento e tira vida")
	var bleed0 := bl.bleed
	for i in 60:
		bl.hp = 100.0
		bl.damage(14.0)
	check(bl.bleed > bleed0, "sangrando, novos cortes aumentam o sangramento")
	bl.hp = 60.0
	bl.bleed = 0.3
	bl.calories = 1500.0
	bl.water = 80.0
	bl._tick_health(10.0)
	check(bl.hp < 60.0 - 2.0, "sangramento tira vida por segundo (%.1f)" % bl.hp)
	var hp_b := bl.hp
	bl.give("bandagem", 1)
	bl.use_item("bandagem")
	check(bl.bleed == 0.0 and bl.hp >= hp_b + 11.0, "bandagem estanca o sangramento e cura na hora")
	bl.give("bandagem", 1)
	bl.hp = SurvivorData.MAX_HP
	var nb0 := bl.count("bandagem")
	bl.use_item("bandagem")
	check(bl.count("bandagem") == nb0, "bandagem sem necessidade não é gasta")
	bl.hp = 50.0
	bl.give("antibiotico", 1)
	bl.use_item("antibiotico")
	bl._tick_health(20.0)
	check(bl.hp >= 59.0 and bl.regen_t > 0.0, "antibiótico cura aos poucos (%.1f)" % bl.hp)
	bl.bleed = 0.4
	bl.give("analgesico", 1)
	bl.use_item("analgesico")
	check(bl.bleed < 0.25 and bl.bleed > 0.0, "analgésico diminui o sangramento sem estancar")
	bl.give("hemostatico", 1)
	bl.use_item("hemostatico")
	check(bl.bleed < 0.06, "pó hemostático corta quase todo o sangramento")
	bl.bleed = 0.05
	for i in 120:
		bl._tick_health(1.0)
	check(bl.bleed == 0.0, "sangramento leve estanca sozinho")
	# estimulantes
	var st := SurvivorData.from_spec({"nome": "Corredor", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	st.stamina = 0.0
	st._tick_stamina(1.0, false)
	var base_regen := st.stamina
	st.stamina = 0.0
	st.give("tonico_energetico", 1)
	st.use_item("tonico_energetico")
	st._tick_stamina(1.0, false)
	check(st.stamina > base_regen * 1.7 and st.stam_t > 0.0, "tônico revigorante acelera a estamina")
	st.stamina = 0.0
	st.give("adrenalina", 1)
	st.use_item("adrenalina")
	check(st.stamina >= 50.0 and st.stam_mult >= 3.0, "adrenalina devolve estamina na hora e acelera 3x")
	# perna: queda, torção/fratura, tala
	var fa := SurvivorData.from_spec({"nome": "Queda", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	var sp0 := fa.speed_mult()
	fa.fall_injury(2.0)
	check(fa.perna == 0 and fa.hp == SurvivorData.MAX_HP, "pulo baixo não machuca")
	fa.fall_injury(9.0)
	check(fa.perna == 2 and fa.hp < 70.0, "queda de 9 m quebra a perna e tira vida")
	var sp_broken := fa.speed_mult()
	check(sp_broken < sp0 - 0.3, "perna quebrada deixa lento (%.2f < %.2f)" % [sp_broken, sp0])
	fa.give("tala", 1)
	var hp_t := fa.hp
	fa.use_item("tala")
	check(fa.tala and fa.speed_mult() > sp_broken and fa.hp > hp_t, "tala imobiliza, alivia a lentidão e cura um pouco")
	fa.calories = 1500.0
	fa.water = 80.0
	for i in 700:
		fa._tick_bone(1.0, true)
	check(fa.perna == 0 and not fa.tala, "fratura imobilizada sara com o tempo")
	var nt := SurvivorData.from_spec({"nome": "SemTala", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	nt.injure_leg(2)
	for i in 1200:
		nt._tick_bone(1.0, true)
	check(nt.perna == 2, "fratura sem tala não sara")
	var nt2 := SurvivorData.from_spec({"nome": "Torcido", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	nt2.injure_leg(1)
	for i in 260:
		nt2._tick_bone(1.0, true)
	check(nt2.perna == 0, "torção sara sozinha")
	var old_save := nt2.to_dict()
	old_save.erase("hp")
	old_save["blood"] = 70.0
	old_save["limbs"] = {"torso": {"hp": 55.0, "wound": 2, "bleed": 0.2, "bandaged": false}, "perna_e": {"hp": 80.0, "osso": 2, "tala": true}}
	var mig := SurvivorData.from_dict(old_save)
	check(mig.hp == 55.0 and mig.bleed > 0.19 and mig.perna == 2 and mig.tala, "save antigo com membros vira vida, sangramento e perna")
	check(DB.CRAFTS.has("curativo_iodo") and DB.CRAFTS.has("curativo_campo") and float(DB.ITEMS["curativo_campo"]["cura"]) > float(DB.ITEMS["bandagem"]["cura"]),
		"dá para fabricar curativos melhores")
	check(not DB.ITEMS.has("kit_sutura") and Items.sanitize([{"id": "kit_sutura", "n": 1}])[0]["id"] == "tala", "sutura saiu (saves antigos viram tala)")

	# chaves não empilham e guardam a fechadura no save
	var kd := SurvivorData.from_spec({"nome": "Chaveiro", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	kd.receive([{"id": "chave", "n": 1, "tranca": "c:7", "rotulo": "armário"}, {"id": "chave", "n": 1, "tranca": "h:3", "rotulo": "casa"}])
	check(kd.count("chave") == 2 and not kd.key_for("h:3").is_empty() and kd.key_for("c:9").is_empty(), "cada chave abre a sua fechadura")
	var kd2 := SurvivorData.from_dict(kd.to_dict())
	check(not kd2.key_for("c:7").is_empty() and Items.label(kd2.key_for("c:7")) == "Chave (armário)", "chave vai para o save com o rótulo")

	# roupas: defesa, desgaste e conjuntos
	var nu := SurvivorData.from_spec({"nome": "Nu", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	for slot: String in DB.ROUPA_SLOTS:
		nu.equip[slot] = {}
	nu.god = false
	nu.damage(20.0)
	var bare := 100.0 - nu.hp
	var arm := SurvivorData.from_spec({"nome": "Blindado", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	for id: String in ["calca_tatica", "botas_militares"]:
		var it: Dictionary = Items.make(id)[0]
		it["dur"] = 100.0
		arm.wear(it)
	for id: String in ["colete_tatico", "capacete_militar"]:
		var it2: Dictionary = Items.make(id)[0]
		it2["dur"] = 100.0
		arm.wear(it2)
	arm.damage(20.0)
	var taken := 100.0 - arm.hp
	check(taken < bare * 0.8, "roupa do regimento reduz o dano (%.1f < %.1f)" % [taken, bare])
	check(float(arm.equip["pernas"]["dur"]) < 100.0, "roupa gasta ao absorver golpes")
	var mec := SurvivorData.from_spec({"nome": "Mecanico", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	for id: String in ["macacao_mecanico", "luvas_mecanico"]:
		mec.wear(Items.make(id)[0])
	var partial := mec.gear_bonus("reparo")
	check(not mec.set_complete("mecanico"), "conjunto incompleto não ativa")
	mec.wear(Items.make("botas_trabalho")[0])
	check(mec.set_complete("mecanico") and mec.gear_bonus("reparo") > partial + 0.15, "conjunto de mecânico completo acelera consertos")
	mec.use_item(int(mec.equip["pes"]["u"]))
	check(mec.equip["pes"].is_empty() and mec.count("botas_trabalho") == 1, "tirar roupa volta para o inventário")
	var dmec := SurvivorData.from_dict(mec.to_dict())
	check(not dmec.equip["torso"].is_empty() and String(dmec.equip["torso"]["id"]) == "macacao_mecanico", "roupa vestida vai para o save")

	# fase 6: medicina cooperativa (o curativo usa os suprimentos e a Medicina de quem trata)
	var medic := SurvivorData.from_spec({"nome": "Medica", "forca": 5, "resist": 5, "skills": {"medicina": 3}, "traits": []}, r)
	var hurt := SurvivorData.from_spec({"nome": "Ferido", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	hurt.bleed = 0.3
	hurt.hp = 50.0
	medic.give("bandagem", 1)
	var med_band := medic.count("bandagem")
	var xp0 := float(medic.skills["medicina"]["xp"])
	var own_band := hurt.count("bandagem")
	hurt.apply_med("bandagem", medic)
	check(hurt.bleed == 0.0 and hurt.hp > 62.0 and medic.count("bandagem") == med_band - 1 and hurt.count("bandagem") == own_band,
		"aliado usa a bandagem dele, e a Medicina dele cura mais (%.1f)" % hurt.hp)
	check(float(medic.skills["medicina"]["xp"]) > xp0, "quem trata ganha experiência")
	medic.skills["medicina"]["lv"] = 6
	medic.skills["cibernetica"]["lv"] = 6
	medic.give("kit_cirurgico", 1)
	medic.give("implante_derme", 1)
	hurt.battery = 100.0
	hurt.install_implant("implante_derme", medic)
	check(hurt.implants.has("pele") and float(hurt.implants["pele"]["integ"]) == 100.0, "aliado opera com encaixe perfeito")
	var self_op := SurvivorData.from_spec({"nome": "Solo", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	self_op.skills["medicina"]["lv"] = 6
	self_op.skills["cibernetica"]["lv"] = 6
	self_op.give("kit_cirurgico", 1)
	self_op.give("implante_derme", 1)
	self_op.install_implant("implante_derme")
	check(float(self_op.implants["pele"]["integ"]) == 80.0, "operar a si mesmo deixa o encaixe a 80%")

	# interface: reordenar e organizar o inventário
	var o := SurvivorData.from_spec({"nome": "Org", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	o.wear(Items.make("mochila_militar")[0])
	o.give("pregos", 5)
	o.give("faca")
	o.give("feijao", 2)
	var list: Array = o.bags["mochila"]
	var last_u := int(list[list.size() - 1]["u"])
	o.reorder(last_u, 0)
	check(int(o.bags["mochila"][0]["u"]) == last_u, "reordenar põe o item na posição escolhida")
	o.use_item("faca")
	var hand := o.hand_u
	o.sort_bags()
	check(o.hand_u == hand and o.weapon_id() == "faca", "organizar mantém a arma na mão")
	var first_tipo := String(Items.def(o.bags["mochila"][0]["id"])["tipo"])
	check(first_tipo == "arma", "organizar põe as armas primeiro (%s)" % first_tipo)

	# aparência (criação de personagem): vai na ficha, no save e na rede (inteiro)
	var vr := RandomNumberGenerator.new()
	vr.seed = 5
	var all_ok := true
	for i in 200:
		var vv := CharArt.random_visual(vr)
		if CharArt.decode(CharArt.encode(vv)) != CharArt.clean(vv):
			all_ok = false
	check(all_ok, "aparência sobrevive à ida e volta pela rede")
	check(CharArt.clean({"sexo": 1, "barba": 3})["barba"] == 0 and CharArt.clean({"cabelo": 99})["cabelo"] < CharArt.CABELOS.size(),
		"aparência inválida é corrigida (mulher sem barba, índices no limite)")
	var vspec := SurvivorData.random_spec(vr)
	vspec["visual"] = {"sexo": 0, "pele": 2, "cabelo": 4, "cor": 6, "barba": 3}
	var vd := SurvivorData.from_spec(vspec, vr)
	var vd2 := SurvivorData.from_dict(vd.to_dict())
	check(vd2.visual == CharArt.clean(vspec["visual"]), "aparência escolhida vai para o sobrevivente e para o save")
	var old_d := vd.to_dict()
	old_d.erase("visual")
	check(SurvivorData.from_dict(old_d).visual == SurvivorData.from_dict(old_d).visual, "save antigo ganha sempre a mesma aparência")

	# caça: carne crua, couro e receitas
	var hunter := SurvivorData.from_spec({"nome": "Caçador", "forca": 5, "resist": 5, "skills": {}, "traits": []}, r)
	hunter.calories = 800.0
	hunter.give("carne_crua", 1)
	var hp_raw := hunter.hp
	hunter.use_item("carne_crua")
	check(hunter.hp < hp_raw and hunter.calories > 800.0, "carne crua alimenta, mas faz mal")
	hunter.give("couro", 5)
	hunter.give("faca", 1)
	hunter.skills["carpintaria"]["lv"] = 1
	check(hunter.craft("jaqueta_couro") and hunter.count("jaqueta_couro") >= 1 and hunter.count("couro") == 0, "5 couros e uma faca viram um sobretudo de couro")
	check(DB.CRAFTS.has("carne_assada") and DB.ITEMS["carne_assada"].get("cozido", false) and DB.CRAFTS["carne_assada"]["estacao"] == "fogareiro",
		"carne assada se faz no fogareiro")

	# troca de teclas (menu de pausa > controles)
	var inp: Node = root.get_node("InputSetup")
	if not InputMap.has_action("interact"):
		inp._ready()  # no modo -s o _ready dos autoloads ainda não rodou aqui
	inp.reset_defaults()
	var ev_f := InputEventKey.new()
	ev_f.physical_keycode = KEY_F
	var swapped: String = inp.rebind("interact", 0, ev_f)
	check(swapped == "shove" and inp.key_text("interact") == "F" and inp.key_text("shove") == "E",
		"trocar Interagir para F passa o E para Empurrar")
	check(inp.fix_text("[E] Abrir · [F] empurrar") == "[F] Abrir · [E] empurrar", "avisos mostram a tecla atual")
	var ev_esc := InputEventKey.new()
	ev_esc.physical_keycode = KEY_ESCAPE
	check(inp.rebind("interact", 0, ev_esc) == "!cancel" and inp.key_text("interact") == "F", "ESC é fixo e não pode ser usado")
	var ev_up := InputEventKey.new()
	ev_up.physical_keycode = KEY_UP
	inp.rebind("move_up", 0, ev_up)
	check(inp.binds("move_up").size() == 2 and inp.key_text("move_up") == "↑", "trocar pela tecla alternativa inverte as duas")
	inp.reset_defaults()
	check(inp.key_text("interact") == "E" and not FileAccess.file_exists("user://controles.cfg"), "restaurar padrão volta as teclas e apaga o arquivo")

	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
