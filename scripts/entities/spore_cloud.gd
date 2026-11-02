class_name SporeCloud
extends Node2D
## Nuvem de esporos da bolha que estourou (só visual; o efeito é aplicado pelo servidor).

var _t := 2.5
var _puffs: Array = []


func _ready() -> void:
	z_index = 40
	for i in 14:
		_puffs.append([Vector2(randf_range(-60, 60), randf_range(-30, 30)), randf_range(8.0, 18.0), randf() * TAU])


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf(_t / 2.5, 0.0, 1.0)
	for pf in _puffs:
		var grow := 1.0 + (1.0 - a) * 0.8
		var p: Vector2 = pf[0] * grow + Vector2(0, -6.0 * (1.0 - a))
		draw_circle(p.round(), float(pf[1]) * grow, Color(0.6, 0.85, 0.3, 0.32 * a))
