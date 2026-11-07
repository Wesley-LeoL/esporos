extends Node
## Registra as ações de input por código, para o mapeamento ficar versionado
## de forma legível (em vez de serializado no project.godot).
## O jogador pode trocar as teclas no menu de pausa (ESC > Controles); as trocas ficam
## salvas em user://controles.cfg e são carregadas ao abrir o jogo.

signal keys_changed

const CFG_PATH := "user://controles.cfg"

## Teclas padrão. A primeira é a principal; a segunda, a alternativa.
const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"attack": [KEY_SPACE, KEY_J],
	"interact": [KEY_E],
	"menu": [KEY_TAB],
	"inventory": [KEY_I],
	"map": [KEY_M],
	"build_menu": [KEY_B],
	"vehicle_status": [KEY_V],
	"cancel": [KEY_ESCAPE],
	"demolish": [KEY_X],
	"save": [KEY_F5],
	"sprint": [KEY_SHIFT],
	"sneak": [KEY_C],
	"reload": [KEY_R],
	"shove": [KEY_F],
	"hot_1": [KEY_1],
	"hot_2": [KEY_2],
	"hot_3": [KEY_3],
	"hot_4": [KEY_4],
	"hot_5": [KEY_5],
}

## O que cada ação faz, na ordem em que aparece na tela de controles.
## [ação, nome, descrição]. "" como ação = título de grupo.
const LIST := [
	["", "Movimento", ""],
	["move_up", "Andar para cima", ""],
	["move_down", "Andar para baixo", ""],
	["move_left", "Andar para a esquerda", ""],
	["move_right", "Andar para a direita", ""],
	["sprint", "Correr", "Segure. Gasta estamina."],
	["sneak", "Agachar", "Passos sem barulho; os infectados demoram a notar."],
	["", "Combate", ""],
	["attack", "Atacar / atirar", "Na direção do mouse. O clique esquerdo também ataca."],
	["shove", "Empurrar", "Afasta o inimigo e solta você quando estiver agarrado."],
	["reload", "Recarregar", "Arma de fogo na mão."],
	["", "Interação", ""],
	["interact", "Interagir", "Abre o menu do objeto perto (porta, janela, móvel, carro...)."],
	["hot_1", "Barra rápida 1", "Seleciona o espaço; o clique usa o item."],
	["hot_2", "Barra rápida 2", ""],
	["hot_3", "Barra rápida 3", ""],
	["hot_4", "Barra rápida 4", ""],
	["hot_5", "Barra rápida 5", ""],
	["", "Menus", ""],
	["menu", "Diário de campo", "Inventário, corpo, habilidades, próteses e mapa."],
	["inventory", "Inventário", ""],
	["map", "Mapa", ""],
	["build_menu", "Modo construção", ""],
	["demolish", "Demolir", "No modo construção."],
	["vehicle_status", "Estado do veículo", "Dentro de um veículo."],
	["save", "Salvar", "O jogo também salva sozinho a cada 25 segundos."],
	["cancel", "Pausa / fechar", "Fecha janelas; sem nada aberto, abre o menu de pausa."],
]

## Ações que não podem ser trocadas.
const FIXED := ["cancel"]


func _ready() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_apply_defaults()
	load_keys()


func _apply_defaults() -> void:
	for action: String in ACTIONS:
		InputMap.action_erase_events(action)
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	_add_click()


func _add_click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", click)


## Teclas (sem o clique fixo do ataque) de uma ação, na ordem: principal, alternativa.
func binds(action: String) -> Array:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		if _is_fixed_click(action, e):
			continue
		out.append(e)
	return out


func _is_fixed_click(action: String, e: InputEvent) -> bool:
	return action == "attack" and e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT


## Nome curto de uma tecla, como aparece nas teclas desenhadas do HUD.
static func event_text(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		match code:
			KEY_SPACE: return "ESPAÇO"
			KEY_ESCAPE: return "ESC"
			KEY_SHIFT: return "SHIFT"
			KEY_CTRL: return "CTRL"
			KEY_ALT: return "ALT"
			KEY_TAB: return "TAB"
			KEY_ENTER: return "ENTER"
			KEY_BACKSPACE: return "APAGAR"
			KEY_UP: return "↑"
			KEY_DOWN: return "↓"
			KEY_LEFT: return "←"
			KEY_RIGHT: return "→"
			KEY_CAPSLOCK: return "CAPS"
		# no layout do teclado do jogador (ex.: AZERTY), quando o sistema informa
		var shown := code
		if DisplayServer.get_name() != "headless":
			var mapped := DisplayServer.keyboard_get_keycode_from_physical(code)
			if mapped != KEY_NONE:
				shown = mapped
		return OS.get_keycode_string(shown).to_upper()
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "CLIQUE"
			MOUSE_BUTTON_RIGHT: return "BOTÃO DIR."
			MOUSE_BUTTON_MIDDLE: return "BOTÃO DO MEIO"
			MOUSE_BUTTON_XBUTTON1: return "MOUSE 4"
			MOUSE_BUTTON_XBUTTON2: return "MOUSE 5"
		return "MOUSE %d" % (e as InputEventMouseButton).button_index
	return "?"


## Tecla principal de uma ação (texto curto), para os avisos do HUD.
func key_text(action: String) -> String:
	var b := binds(action)
	return event_text(b[0]) if not b.is_empty() else "—"


## Troca o texto "[E]" (e outras teclas padrão entre colchetes) pela tecla atual.
func fix_text(s: String) -> String:
	if not "[" in s:
		return s
	# troca em duas etapas para uma tecla nova não ser trocada de novo (ex.: E→F e F→E)
	var pairs := [["[E]", "interact"], ["[F]", "shove"], ["[R]", "reload"], ["[B]", "build_menu"],
			["[X]", "demolish"], ["[C]", "sneak"], ["[V]", "vehicle_status"], ["[M]", "map"], ["[I]", "inventory"]]
	for i in pairs.size():
		s = s.replace(pairs[i][0], "\u0001%d\u0002" % i)
	for i in pairs.size():
		s = s.replace("\u0001%d\u0002" % i, "[" + key_text(pairs[i][1]) + "]")
	return s


func same_event(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## Ação que já usa essa tecla (ou "").
func action_using(e: InputEvent) -> String:
	for action: String in ACTIONS:
		for b in binds(action):
			if same_event(b, e):
				return action
	return ""


## Põe a tecla e no espaço slot (0 principal, 1 alternativa) da ação. Se outra ação já
## usava essa tecla, ela recebe a tecla antiga desta (as duas trocam). Devolve o nome da
## ação que trocou, ou "".
func rebind(action: String, slot: int, e: InputEvent) -> String:
	if action in FIXED:
		return ""
	var mine := binds(action)
	var old: InputEvent = mine[slot] if slot < mine.size() else null
	if old != null and same_event(old, e):
		return ""
	var other := action_using(e)
	if other in FIXED:
		return "!" + other
	var swapped := ""
	if other != "" and other != action:
		var theirs := binds(other)
		for i in theirs.size():
			if same_event(theirs[i], e):
				if old != null:
					theirs[i] = old
				else:
					theirs.remove_at(i)
				break
		_set_binds(other, theirs)
		swapped = other
	elif other == action:
		# a tecla já era a outra posição desta ação: as duas posições trocam
		for i in mine.size():
			if same_event(mine[i], e):
				if old != null:
					mine[i] = old
				else:
					mine.remove_at(i)
				break
		if slot > mine.size():
			slot = mine.size()
	var clean := _clean(e)
	if slot < mine.size():
		mine[slot] = clean
	else:
		mine.append(clean)
	_set_binds(action, mine)
	save_keys()
	keys_changed.emit()
	return swapped


## Tira a tecla do espaço slot da ação (para deixar só uma).
func unbind(action: String, slot: int) -> void:
	if action in FIXED:
		return
	var mine := binds(action)
	if slot < mine.size() and mine.size() > 1:
		mine.remove_at(slot)
		_set_binds(action, mine)
		save_keys()
		keys_changed.emit()


func reset_defaults() -> void:
	_apply_defaults()
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG_PATH))
	keys_changed.emit()


func _clean(e: InputEvent) -> InputEvent:
	if e is InputEventKey:
		var k := InputEventKey.new()
		var src := e as InputEventKey
		k.physical_keycode = src.physical_keycode if src.physical_keycode != KEY_NONE else src.keycode
		return k
	var m := InputEventMouseButton.new()
	m.button_index = (e as InputEventMouseButton).button_index
	return m


func _set_binds(action: String, list: Array) -> void:
	InputMap.action_erase_events(action)
	for e in list:
		InputMap.action_add_event(action, e)
	if action == "attack":
		_add_click()


func save_keys() -> void:
	var cfg := ConfigFile.new()
	for action: String in ACTIONS:
		var arr: Array = []
		for e in binds(action):
			if e is InputEventKey:
				arr.append(["k", int((e as InputEventKey).physical_keycode)])
			elif e is InputEventMouseButton:
				arr.append(["m", int((e as InputEventMouseButton).button_index)])
		cfg.set_value("controles", action, arr)
	cfg.save(CFG_PATH)


func load_keys() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	for action: String in ACTIONS:
		if action in FIXED or not cfg.has_section_key("controles", action):
			continue
		var list: Array = []
		for d in cfg.get_value("controles", action, []):
			if not (d is Array) or (d as Array).size() < 2:
				continue
			if d[0] == "k":
				var k := InputEventKey.new()
				k.physical_keycode = int(d[1]) as Key
				list.append(k)
			elif d[0] == "m":
				var m := InputEventMouseButton.new()
				m.button_index = int(d[1]) as MouseButton
				list.append(m)
		if not list.is_empty():
			_set_binds(action, list)
