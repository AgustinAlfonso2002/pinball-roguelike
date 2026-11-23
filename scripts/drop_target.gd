class_name DropTarget
extends StaticBody2D
## Diana abatible: al golpearla se baja y deja pasar la bola.
## Main la agrupa en un banco: tirar todas da un bonus.

signal dropped

const SIZE := Vector2(24.0, 8.0)
const POINTS := 250

var is_down := false
var flash := 0.0

var _cs := CollisionShape2D.new()
var _material := PhysicsMaterial.new()


func _init() -> void:
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	_cs.shape = shape
	add_child(_cs)
	_material.bounce = 0.25
	physics_material_override = _material


## Baja la diana. Devuelve true si estaba arriba.
func hit() -> bool:
	if is_down:
		return false
	is_down = true
	flash = 1.0
	_cs.set_deferred("disabled", true)
	dropped.emit()
	return true


func raise_up() -> void:
	is_down = false
	flash = 0.6
	_cs.set_deferred("disabled", false)


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	if is_down:
		draw_rect(rect, Color(0.95, 0.6, 0.3, 0.25 + 0.5 * flash), false, 1.0)
	else:
		draw_rect(rect, Color(0.95, 0.6, 0.3).lerp(Color.WHITE, flash))
		draw_rect(rect, Color(0.45, 0.2, 0.05), false, 1.0)
