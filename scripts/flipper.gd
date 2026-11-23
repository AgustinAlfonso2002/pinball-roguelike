class_name Flipper
extends AnimatableBody2D
## Flipper controlado por código (no por física pura): el golpe es
## instantáneo y siempre igual, así el jugador aprende a apuntar.
## Godot calcula la velocidad del cuerpo cinemático a partir de su giro,
## y con eso le transmite el golpe a la bola.

const LENGTH := 62.0
const BASE_RADIUS := 10.0
const TIP_RADIUS := 5.0
const SWING_DEG := 30.0

var is_left := true
var action := ""
var enabled := true
var rest_angle := 0.0
var active_angle := 0.0

var _material := PhysicsMaterial.new()
var _outline := PackedVector2Array()


func setup(left: bool) -> void:
	is_left = left
	var dir := 1.0 if left else -1.0
	action = "flipper_left" if left else "flipper_right"
	rest_angle = deg_to_rad(SWING_DEG) * dir
	active_angle = -deg_to_rad(SWING_DEG) * dir
	sync_to_physics = false
	rotation = rest_angle

	_outline = _build_outline(dir)
	var shape := Shapes.convex(_outline)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	physics_material_override = _material


func _ready() -> void:
	Tuning.changed.connect(_apply_tuning)
	_apply_tuning()


func _apply_tuning() -> void:
	_material.bounce = Tuning.v("flipper_bounce")
	_material.friction = 0.3


func is_up() -> bool:
	return enabled and Input.is_action_pressed(action)


func _physics_process(delta: float) -> void:
	var pressed := is_up()
	var target := active_angle if pressed else rest_angle
	var speed := Tuning.v("flipper_up_speed") if pressed else Tuning.v("flipper_down_speed")
	rotation = move_toward(rotation, target, speed * delta)


func _build_outline(dir: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:  # Semicírculo trasero (pivote)
		var a := PI * 0.5 + PI * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * BASE_RADIUS)
	for i in 13:  # Semicírculo de la punta
		var a := -PI * 0.5 + PI * float(i) / 12.0
		pts.append(Vector2(LENGTH, 0.0) + Vector2(cos(a), sin(a)) * TIP_RADIUS)
	for i in pts.size():
		pts[i] = Vector2(pts[i].x * dir, pts[i].y)
	return pts


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var col := Color(0.55, 0.79, 0.90) if enabled else Color(0.4, 0.4, 0.45)
	draw_colored_polygon(_outline, col)
	var closed := _outline.duplicate()
	closed.append(_outline[0])
	draw_polyline(closed, Color(0.2, 0.35, 0.45), 1.5)
	draw_circle(Vector2.ZERO, 3.0, Color(0.15, 0.2, 0.3))
