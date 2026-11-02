class_name Stair
extends Node2D
## Escada de um prédio de vários andares. [E] sobe ou desce (o servidor teleporta).

var cell := Vector2i.ZERO
var to := Vector2i.ZERO
var label := "Escada"


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("stairs")


func prompt() -> String:
	return "[E] " + label


func options(_p: Player) -> Array:
	return [{"id": "escada", "txt": label, "ok": true}]


func interact(_p: Player) -> void:
	pass


func _draw() -> void:
	# degraus em isométrico (desenho provisório)
	var up := label.begins_with("Subir")
	for i in 5:
		var k := float(i) / 5.0
		var y := -k * 26.0 if up else k * 6.0
		var w := 30.0 - k * 10.0
		var pts := PackedVector2Array([Vector2(-w, y), Vector2(0, y - w * 0.5), Vector2(w, y), Vector2(0, y + w * 0.5)])
		draw_colored_polygon(pts, Color(0.42, 0.40, 0.46).darkened(0.1 * i if up else 0.15 * (4 - i)))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0), 1.0)
	draw_string(UITheme.font(), Vector2(-4, -30 if up else -8), "▲" if up else "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_S, UITheme.ACCENT)
