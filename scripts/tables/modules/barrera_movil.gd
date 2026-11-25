extends TableModule
## Barrera que va y viene de un lado al otro. Cada golpe suma y la hace
## brillar; si la tocás tres veces seguidas sin que pase mucho tiempo, se
## acelera un rato.

const SIZE := Vector2(44, 8)
const RANGE := 46.0  ## Cuánto se mueve hacia cada lado (unidades).
const POINTS := 40.0

var _bar: AnimatableBody2D
var _t := 0.0
var _speed := 1.4
var _fast := 0.0
var _streak := 0
var _last_hit := -10.0
var _flash := 0.0


func _init() -> void:
	id = &"barrera_movil"
	display_name = "Barrera móvil"
	sizes = ["M"]
	weight = 1.0
	events = {&"bar": {"text": "Golpeá la barrera móvil", "goal": 10}}


func build() -> void:
	_t = rng.randf() * TAU
	_bar = Bar.new()
	_bar.module = self
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE * Geom.S
	cs.shape = rect
	_bar.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.75
	_bar.physics_material_override = mat
	_bar.position = _pos()
	table.add_child(_bar)


func _pos() -> Vector2:
	return center() + Vector2(sin(_t) * u(RANGE), 0)


func _physics_process(delta: float) -> void:
	_fast = maxf(0.0, _fast - delta)
	_t += delta * (_speed * (2.0 if _fast > 0.0 else 1.0))
	_bar.position = _pos()


func on_bar_hit() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_streak = _streak + 1 if now - _last_hit < 3.0 else 1
	_last_hit = now
	_flash = 1.0
	Sfx.play("post", 0.9)
	score(&"bar", POINTS * (2.0 if _fast > 0.0 else 1.0), _bar.position)
	event(&"bar", _bar.position)
	if _streak >= 3:
		_streak = 0
		_fast = 5.0
		TableFx.burst(table, _bar.position, Color(0.4, 1.0, 0.8), 12, 100.0)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var c := center()
	# Riel por donde corre.
	draw_line(c + Vector2(-u(RANGE) - u(SIZE.x) * 0.5, 0), c + Vector2(u(RANGE) + u(SIZE.x) * 0.5, 0), Color(0.3, 0.35, 0.5, 0.6), 1.0)
	var s := SIZE * Geom.S
	var col := Color(0.35, 0.95, 0.75) if _fast > 0.0 else Color(0.3, 0.75, 0.9)
	draw_rect(Rect2(_bar.position - s * 0.5, s), col.lerp(Color.WHITE, _flash))
	draw_rect(Rect2(_bar.position - s * 0.5, s), col.darkened(0.5), false, 1.0)


class Bar extends AnimatableBody2D:
	var module

	func _init() -> void:
		sync_to_physics = true

	func ball_hit(_ball: Ball) -> void:
		module.on_bar_hit()
