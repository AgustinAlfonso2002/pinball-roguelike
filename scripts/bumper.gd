class_name Bumper
extends StaticBody2D
## Bumper redondo: al tocarlo empuja la bola hacia afuera con fuerza fija.

const RADIUS := 20.0 * Geom.S
const POINTS := 100

var flash := 0.0
var _material := PhysicsMaterial.new()


func _init() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_material.bounce = 0.5
	physics_material_override = _material


func hit(ball: Ball) -> void:
	var n := (ball.global_position - global_position).normalized()
	var vel := ball.linear_velocity
	vel -= n * vel.dot(n)  # Conserva solo el componente tangencial...
	vel += n * Run.stat(&"bumper_kick")  # ...y lo despide hacia afuera.
	ball.linear_velocity = vel
	flash = 1.0


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var base := Color(0.91, 0.31, 0.39)
	var lit := Color(1.0, 0.85, 0.4)
	draw_circle(Vector2.ZERO, RADIUS, base.lerp(lit, flash))
	draw_circle(Vector2.ZERO, RADIUS * 0.45, Color(1.0, 0.82, 0.4).lerp(Color.WHITE, flash))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.4, 0.1, 0.15), 1.0)
