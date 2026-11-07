class_name PauseMenu
extends CanvasLayer
## Menu de pausa (ESC sem nada aberto): continuar, controles (ver e trocar as teclas),
## voltar ao menu principal e sair do jogo. No modo solo o jogo pausa; em co-op continua
## rodando para os outros.

const S := UITheme.FONT_S
const L := UITheme.FONT_L

var ui: Control
var _box: VBoxContainer
var _page := ""
var _status: Label
## Esperando uma tecla para [ação, espaço].
var _capture: Array = []
var _list_scroll := 0


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	ui = Control.new()
	ui.scale = Vector2.ONE / UITheme.UI_SCALE
	ui.theme = UITheme.build_theme()
	ui.size = get_viewport().get_visible_rect().size * UITheme.UI_SCALE
	add_child(ui)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box("panel", 16, Vector4(28, 22, 28, 22)))
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)
	visible = false
	get_viewport().size_changed.connect(func() -> void:
		ui.size = get_viewport().get_visible_rect().size * UITheme.UI_SCALE)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_capture = []
	get_tree().paused = Net.is_solo()
	_show_main()


func close() -> void:
	visible = false
	_capture = []
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _capture.is_empty():
		_try_capture(event)
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		if _page == "controles":
			_show_main()
		else:
			close()


func _try_capture(event: InputEvent) -> void:
	var e: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE or (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_capture = []
			_status.text = "Troca cancelada."
			_show_controls()
			return
		e = event
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		# o clique esquerdo é do ataque e da interface; a rodinha rola a lista
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		e = event
	if e == null:
		return
	get_viewport().set_input_as_handled()
	var action: String = _capture[0]
	var slot: int = _capture[1]
	_capture = []
	var swapped := InputSetup.rebind(action, slot, e)
	var nm := _name_of(action)
	if swapped.begins_with("!"):
		_status.text = "%s é fixa (%s) e não pode ser usada." % [InputSetup.event_text(e), _name_of(swapped.substr(1))]
	elif swapped != "":
		_status.text = "%s agora é %s. \"%s\" ficou com a tecla antiga." % [nm, InputSetup.event_text(e), _name_of(swapped)]
	else:
		_status.text = "%s agora é %s." % [nm, InputSetup.event_text(e)]
	Sfx.play("ui_clique")
	_show_controls()


func _name_of(action: String) -> String:
	for row in InputSetup.LIST:
		if row[0] == action:
			return String(row[1])
	return action


# ------------------------------------------------------------------ páginas
func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _label(text: String, size := S, color := UITheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(parent: Control, text: String, cb: Callable, size := L, min_w := 520) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_w, 64 if size == L else 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void: Sfx.play("ui_clique"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _show_main() -> void:
	_page = "main"
	_clear()
	var t := _label("PAUSA" if Net.is_solo() else "MENU", UITheme.FONT_S * 4, UITheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	var sub := _label("O jogo está pausado." if Net.is_solo() else "Em co-op o jogo continua rodando para os outros.", S, UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_box.add_child(gap)
	_button(_box, "CONTINUAR", close)
	_button(_box, "CONTROLES", func() -> void:
		_status = null
		_show_controls())
	var back_txt := "SAIR DA SESSÃO" if Net.mode == "client" else "SALVAR E VOLTAR AO MENU"
	_button(_box, back_txt, _back_to_title)
	_button(_box, "SALVAR E SAIR DO JOGO" if Net.is_server() else "SAIR DO JOGO", _quit)
	if Net.mode == "host":
		var w := _label("Se você sair, a sessão acaba para todos.", S, UITheme.WARN)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(w)


func _show_controls() -> void:
	_page = "controles"
	var old_scroll := _list_scroll
	_clear()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_box.add_child(head)
	var t := _label("CONTROLES", L, UITheme.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("Clique numa tecla para trocar · ESC volta", S, UITheme.MUTED))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1240, 600)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for row in InputSetup.LIST:
		var action: String = row[0]
		if action == "":
			var g := _label(String(row[1]).to_upper(), S, UITheme.ACCENT)
			list.add_child(g)
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		list.add_child(line)
		var nm := _label(String(row[1]), S, UITheme.TEXT)
		nm.custom_minimum_size = Vector2(300, 0)
		line.add_child(nm)
		var binds := InputSetup.binds(action)
		for slot in 2:
			var txt := "—"
			if slot < binds.size():
				txt = InputSetup.event_text(binds[slot])
			if not _capture.is_empty() and _capture[0] == action and _capture[1] == slot:
				txt = "APERTE..."
			var b := Button.new()
			b.text = txt
			b.add_theme_font_size_override("font_size", S)
			b.custom_minimum_size = Vector2(190, 0)
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if action in InputSetup.FIXED:
				b.disabled = true
			else:
				var a2 := action
				var s2 := slot
				b.pressed.connect(func() -> void:
					Sfx.play("ui_clique")
					_list_scroll = sc.scroll_vertical
					_capture = [a2, s2]
					_status.text = "Aperte a nova tecla para \"%s\" (ESC cancela)." % _name_of(a2)
					_show_controls())
				if slot == 1 and slot < binds.size():
					b.tooltip_text = "Botão direito: tirar esta tecla"
					b.gui_input.connect(func(ev: InputEvent) -> void:
						if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and _capture.is_empty():
							_list_scroll = sc.scroll_vertical
							InputSetup.unbind(a2, s2)
							_status.text = "Tecla alternativa de \"%s\" removida." % _name_of(a2)
							_show_controls())
			line.add_child(b)
		var extra := String(row[2])
		if action == "attack":
			extra = extra if extra != "" else "Clique esquerdo também ataca."
		var d := _label(extra, S, UITheme.MUTED)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(d)
	var fixed := _label("Fixas: F1 abre o console de testes · botão direito do mouse abre opções de item no inventário.", S, UITheme.MUTED)
	list.add_child(fixed)
	var prev_status := _status.text if _status != null else "A segunda coluna é a tecla alternativa (botão direito tira)."
	_status = _label(prev_status, S, UITheme.WARN)
	_box.add_child(_status)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(foot)
	_button(foot, "RESTAURAR PADRÃO", func() -> void:
		_capture = []
		InputSetup.reset_defaults()
		_status.text = "Teclas voltaram ao padrão."
		_list_scroll = sc.scroll_vertical
		_show_controls(), S, 300)
	_button(foot, "VOLTAR", func() -> void:
		_capture = []
		_show_main(), S, 300)
	# mantém a rolagem depois de redesenhar
	_list_scroll = old_scroll
	sc.set_deferred("scroll_vertical", old_scroll)


func _back_to_title() -> void:
	close()
	if Net.is_server():
		Game.save_game()
	Net.end_session("")


func _quit() -> void:
	if Net.is_server():
		Game.save_game()
	get_tree().quit()
