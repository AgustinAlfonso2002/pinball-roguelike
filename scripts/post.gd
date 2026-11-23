class_name Post
extends StaticBody2D
## Poste de goma: separa outlane e inlane, rebota la bola.

const RADIUS := 5.0

var flash := 0.0
var _material := PhysicsMaterial.new()


func _init() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_material.bounce = 0.6
	physics_material_override = _material


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 6.0)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + 1.5, Color(0.95, 0.95, 1.0).lerp(Color(1.0, 0.85, 0.4), flash))
	draw_circle(Vector2.ZERO, RADIUS - 1.5, Color(0.35, 0.38, 0.55))
