extends TableModule
## Riel guiado: si la bola entra a la boca yendo hacia arriba, sube al riel
## (elevado), lo recorre acelerando y sale por uno de los carriles de arriba
## de los flippers. Recompensa los tiros apuntados: es la "rampa" de esta mesa.
## El recorrido lo planea RailPlanner para no tapar otras piezas.

const MOUTH := Vector2(34, 16)
const POINTS := 500.0
const START_SPEED := 220.0  ## Píxeles de mesa por segundo.
const END_SPEED := 420.0
const MIN_ENTRY_SPEED := 60.0

var _area: Area2D
var _curve := Curve2D.new()
var _baked := PackedVector2Array()
var _length := 0.0
var _exit_dir := Vector2.DOWN
var _held: TableFx.HeldBall = null
var _chase := 0.0
var _lit := 0.0
var _cool := 0.0


func _init() -> void:
	id = &"riel"
	display_name = "Riel guiado"
	sizes = ["S"]
	allow_low = true
	weight = 1.0
	events = {&"rail": {"text": "Recorré el riel", "goal": 3, "big": true}}


func build() -> void:
	_area = Area2D.new()
	z_index = 10  # El riel pasa por encima de las demás piezas.
	var mouth := center()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = MOUTH * Geom.S
	cs.shape = rect
	_area.add_child(cs)
	_area.position = mouth
	_area.body_entered.connect(_on_enter)
	add_child(_area)
	# Recorrido: lo planea el generador para no pasar por encima de otras piezas.
	var path: Array = params.get("path", [])
	if path.is_empty():
		for p in table.layout.placements:
			if p.module == id:
				var socket: int = p.sockets[0]
				path = RailPlanner.plan(chassis, socket, table.layout.occupied_rects(chassis, p), rng)
	if path.is_empty():
		path = [mouth / Geom.S, mouth / Geom.S + Vector2(0, -60), Vector2(36, 360), Vector2(36, 420)]
	_curve = RailPlanner.curve(path, Geom.S)
	var n := _curve.point_count
	_exit_dir = (_curve.get_point_position(n - 1) - _curve.sample_baked(_curve.get_baked_length() - 8.0)).normalized()
	_baked = _curve.get_baked_points()
	_length = _curve.get_baked_length()


func on_ball_served() -> void:
	if _held:
		_held.queue_free()
		_held = null


func _on_enter(body: Node) -> void:
	if not (body is Ball) or _held or _cool > 0.0:
		return
	var vel: Vector2 = (body as Ball).linear_velocity
	if vel.y < -MIN_ENTRY_SPEED:
		_ride.call_deferred()


func _ride() -> void:
	var info := table.capture_ball()
	if info.is_empty():
		return
	Sfx.play("flipper_up", 1.2)
	table.rumble(0.15, 0.3, 0.1)
	_held = TableFx.HeldBall.new()
	_held.color = table.last_ball_color
	_held.height = 6.0
	add_child(_held)
	var dist := 0.0
	var speed := maxf(START_SPEED, (info.vel as Vector2).length() * 0.5)
	while dist < _length:
		await get_tree().physics_frame
		if not is_inside_tree() or not _held:
			return
		var dt := get_physics_process_delta_time()
		speed = move_toward(speed, END_SPEED, 300.0 * dt)
		dist += speed * dt
		_held.position = _curve.sample_baked(minf(dist, _length))
		_lit = 1.0
	_held.queue_free()
	_held = null
	_cool = 0.5
	var exit := _curve.get_point_position(_curve.point_count - 1)
	score(&"rail", POINTS, exit + Vector2(0, -10))
	event(&"rail", exit)
	Sfx.play("bank_complete", 0.7)
	TableFx.burst(table, exit, Color(0.5, 1.0, 0.7), 10, 90.0)
	table.release_ball(exit, _exit_dir * speed * 0.6)


func _process(delta: float) -> void:
	_chase += delta * (1.0 + 3.0 * _lit)
	_lit = maxf(0.0, _lit - delta * 1.5)
	_cool = maxf(0.0, _cool - delta)
	queue_redraw()


func _draw() -> void:
	if _baked.size() < 2:
		return
	var col := Color(0.45, 0.95, 0.7)
	# Dos rieles paralelos.
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in _baked.size():
			var a := _baked[maxi(i - 1, 0)]
			var b := _baked[mini(i + 1, _baked.size() - 1)]
			var n := (b - a).orthogonal().normalized()
			pts.append(_baked[i] + n * side * 5.0)
		draw_polyline(pts, Color(col, 0.55 + 0.45 * _lit), 1.0)
	# Luces que corren hacia la salida.
	var n := 14
	for i in n:
		var t := fmod(float(i) / n + _chase * 0.15, 1.0)
		var p := _curve.sample_baked(t * _length)
		draw_rect(Rect2(p.floor() - Vector2.ONE * 0.5, Vector2.ONE * 1.5), Color(col, 0.35 + 0.5 * _lit))
	# Boca (flecha hacia arriba).
	var m := center()
	var w := MOUTH.x * Geom.S * 0.5
	draw_line(m + Vector2(-w, 6), m + Vector2(-w, -6), col, 1.5)
	draw_line(m + Vector2(w, 6), m + Vector2(w, -6), col, 1.5)
	var blink := 0.4 + 0.6 * absf(sin(_chase * 3.0))
	draw_line(m + Vector2(-5, 2), m + Vector2(0, -3), Color(col, blink), 1.0)
	draw_line(m + Vector2(5, 2), m + Vector2(0, -3), Color(col, blink), 1.0)
