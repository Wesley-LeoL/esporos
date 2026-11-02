extends Node
## Sons do jogo. A tabela SOUNDS (em sfx_table.gd) liga cada evento a um arquivo; trocar um som
## é só trocar o arquivo ou o caminho lá (ver docs/SONS.md). Evento sem arquivo fica mudo.

const MAX_VOICES := 24

var _cache := {}
var _voices: Array[AudioStreamPlayer2D] = []
var _ui: AudioStreamPlayer
var _loops := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = AudioStreamPlayer.new()
	_ui.bus = "Master"
	add_child(_ui)


func _stream(name: String) -> AudioStream:
	if not SfxTable.SOUNDS.has(name):
		return null
	if _cache.has(name):
		return _cache[name]
	var path: String = SfxTable.SOUNDS[name]["arquivo"]
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = st
	return st


func _def(name: String, key: String, fallback: Variant) -> Variant:
	return SfxTable.SOUNDS.get(name, {}).get(key, fallback)


## Som num ponto do mundo (some com a distância).
func play_at(name: String, pos: Vector2) -> void:
	var st := _stream(name)
	if st == null or DisplayServer.get_name() == "headless":
		return
	var v := _free_voice()
	if v == null:
		return
	v.stream = st
	v.global_position = pos
	v.max_distance = float(_def(name, "dist", 900.0))
	v.volume_db = float(_def(name, "vol", 0.0))
	var var_ := float(_def(name, "var", 0.08))
	v.pitch_scale = randf_range(1.0 - var_, 1.0 + var_)
	v.play()


## Som sem posição (interface, coisas do próprio jogador).
func play(name: String) -> void:
	var st := _stream(name)
	if st == null or DisplayServer.get_name() == "headless":
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = float(_def(name, "vol", 0.0))
	var var_ := float(_def(name, "var", 0.05))
	p.pitch_scale = randf_range(1.0 - var_, 1.0 + var_)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Som contínuo ligado a um nó (chuva, gerador). 'on' liga ou desliga.
func loop(name: String, owner_node: Node, on: bool, vol_k := 1.0) -> void:
	var key := "%s:%d" % [name, owner_node.get_instance_id()]
	if not on:
		if _loops.has(key):
			var old: Node = _loops[key]
			if is_instance_valid(old):
				old.queue_free()
			_loops.erase(key)
		return
	if _loops.has(key) and is_instance_valid(_loops[key]):
		var cur: Node = _loops[key]
		if cur is AudioStreamPlayer2D:
			(cur as AudioStreamPlayer2D).volume_db = float(_def(name, "vol", 0.0)) + linear_to_db(maxf(0.01, vol_k))
		elif cur is AudioStreamPlayer:
			(cur as AudioStreamPlayer).volume_db = float(_def(name, "vol", 0.0)) + linear_to_db(maxf(0.01, vol_k))
		return
	var st := _stream(name)
	if st == null or DisplayServer.get_name() == "headless":
		return
	if st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(st as AudioStreamWAV).loop_end = int((st as AudioStreamWAV).get_length() * (st as AudioStreamWAV).mix_rate)
	var pl: Node
	if owner_node is Node2D:
		var p2 := AudioStreamPlayer2D.new()
		p2.stream = st
		p2.max_distance = float(_def(name, "dist", 600.0))
		p2.volume_db = float(_def(name, "vol", 0.0)) + linear_to_db(maxf(0.01, vol_k))
		owner_node.add_child(p2)
		p2.play()
		pl = p2
	else:
		var p1 := AudioStreamPlayer.new()
		p1.stream = st
		p1.volume_db = float(_def(name, "vol", 0.0)) + linear_to_db(maxf(0.01, vol_k))
		add_child(p1)
		p1.play()
		pl = p1
	_loops[key] = pl


func _free_voice() -> AudioStreamPlayer2D:
	for v in _voices:
		if not v.playing:
			return v
	if _voices.size() < MAX_VOICES:
		var v2 := AudioStreamPlayer2D.new()
		v2.attenuation = 1.6
		add_child(v2)
		_voices.append(v2)
		return v2
	return null
