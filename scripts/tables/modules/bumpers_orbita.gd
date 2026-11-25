extends TableModule
## Tres bumpers que giran alrededor de un centro. Cada golpe los acelera un
## rato y cada tanto cambian de sentido.

const RADIUS := 44.0
const BASE_SPEED := 1.1  # radianes por segundo

var _bumpers: Array[Bumper] = []
var _angle := 0.0
var _dir := 1.0
var _boost := 0.0
var _next_flip := 7.0
var _glow := 0.0


func _init() -> void:
	id = &"bumpers_orbita"
	display_name = "Bumpers en órbita"
	sizes = ["L"]
	core = true
	weight = 1.0
	events = {&"orbit": {"text": "Golpeá los bumpers en órbita", "goal": 20}}


func build() -> void:
	_angle = rng.randf() * TAU
	for i in 3:
		var b := table.add_bumper(_pos(i))
		b.set_meta("module", self)
		b.set_meta("event", &"orbit")
		_bumpers.append(b)
	table.module_event.connect(_on_event)


func _pos(i: int) -> Vector2:
	var a := _angle + TAU * i / 3.0
	return center() + Vector2(cos(a), sin(a)) * u(RADIUS)


func _physics_process(delta: float) -> void:
	_boost = maxf(0.0, _boost - delta * 1.5)
	_next_flip -= delta
	if _next_flip <= 0.0:
		_next_flip = rng.randf_range(6.0, 10.0)
		_dir = -_dir
		TableFx.ring(table, center(), Color(0.6, 0.9, 1.0), u(RADIUS) + 8.0, 0.5)
	_angle += _dir * (BASE_SPEED + _boost) * delta
	for i in _bumpers.size():
		_bumpers[i].position = _pos(i)


func _on_event(tag: StringName, _pos_hit: Vector2, module: TableModule) -> void:
	if module == self and tag == &"orbit":
		_boost = minf(_boost + 1.2, 4.0)
		_glow = 1.0


func _process(delta: float) -> void:
	_glow = maxf(0.0, _glow - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var c := center()
	var r := u(RADIUS)
	draw_arc(c, r, 0.0, TAU, 48, Color(0.35, 0.55, 0.9, 0.35 + 0.4 * _glow), 1.5)
	# Marcas que corren sobre la órbita (muestran el sentido y la velocidad).
	for i in 6:
		var a := _angle * 1.5 + TAU * i / 6.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r, 1.2, Color(0.6, 0.85, 1.0, 0.7))
	draw_circle(c, 4.0, Color(0.6, 0.85, 1.0, 0.5 + 0.5 * _glow))
