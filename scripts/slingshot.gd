class_name Slingshot
extends StaticBody2D
## Slingshot triangular arriba de cada flipper. Solo patea cuando la bola
## toca el lado largo (la "goma"), en dirección a su normal.

const POINTS := 10

var edge_a := Vector2.ZERO
var edge_b := Vector2.ZERO
var kick_normal := Vector2.UP
var flash := 0.0

var _points := PackedVector2Array()
var _material := PhysicsMaterial.new()


func setup(a: Vector2, b: Vector2, c: Vector2, normal: Vector2) -> void:
	edge_a = a
	edge_b = b
	kick_normal = normal.normalized()
	_points = PackedVector2Array([a, b, c])
	var shape := Shapes.convex(_points)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_material.bounce = 0.3
	physics_material_override = _material


## Devuelve true si la bola tocó la goma y fue pateada.
func try_kick(ball: Ball) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(ball.global_position, edge_a, edge_b)
	if closest.distance_to(ball.global_position) > Ball.RADIUS + 3.0 * Geom.S:
		return false
	var vel := ball.linear_velocity
	vel -= kick_normal * vel.dot(kick_normal)
	vel += kick_normal * Run.stat(&"sling_kick")
	ball.linear_velocity = vel
	flash = 1.0
	return true


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 5.0)
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_points, Color(0.25, 0.27, 0.4))
	var rubber := Color(0.95, 0.95, 1.0).lerp(Color(1.0, 0.85, 0.4), flash)
	draw_line(edge_a, edge_b, rubber, 2.0)
