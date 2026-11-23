extends Node2D
## Prototipo de física: arma la mesa por código y maneja el loop básico
## (lanzar, puntaje, perder bola, sacudón/tilt).
##
## Coordenadas de la mesa: origen arriba a la izquierda, 400 x 640 px.
## La zona de juego va de x = 0 a 368; el carril del lanzador, de 368 a 400.

const TABLE_W := 400.0
const TABLE_H := 640.0
const LANE_X := 368.0
const LANE_FLOOR_Y := 624.0
const ARC_CENTER := Vector2(200.0, 100.0)
const ARC_RADIUS := 200.0
const BALL_SPAWN := Vector2(384.0, 612.0)
const TEST_DROP := Vector2(184.0, 380.0)
const DRAIN_Y := 690.0
const START_BALLS := 3
const TILT_WINDOW := 3.0
const TILT_LIMIT := 4

const LEFT_PIVOT := Vector2(110.0, 556.0)
const RIGHT_PIVOT := Vector2(258.0, 556.0)
const BUMPER_POSITIONS := [Vector2(130, 210), Vector2(240, 210), Vector2(185, 300)]

var ball: Ball
var flippers: Array[Flipper] = []
var bumpers: Array[Bumper] = []
var slings: Array[Slingshot] = []

var score := 0
var balls_left := START_BALLS
var game_over := false
var tilted := false
var infinite_balls := false  ## Lo usa la autoprueba.
var plunger_charge := 0.0

var _walls := StaticBody2D.new()
var _wall_material := PhysicsMaterial.new()
var _wall_segments: Array = []
var _nudge_times: Array[float] = []
var _time := 0.0
var _shake := 0.0
var _shake_dir := Vector2.ZERO
var _slowmo := false
var _camera := Camera2D.new()
var _hud := Hud.new()
var _panel: TuningPanel


func _ready() -> void:
	_camera.position = Vector2(TABLE_W * 0.5, 272.0)
	_camera.zoom = Vector2(0.92, 0.92)
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(_camera)
	_camera.make_current()

	_build_walls()
	_build_slings()
	_build_bumpers()
	_build_flippers()

	add_child(_hud)
	_panel = TuningPanel.new()
	add_child(_panel)

	Tuning.changed.connect(_apply_tuning)
	_apply_tuning()
	new_game()

	if "--selftest" in OS.get_cmdline_user_args():
		var test: Node = load("res://tests/self_test.gd").new()
		test.main = self
		add_child(test)


# --- Construcción de la mesa -------------------------------------------------

func _build_walls() -> void:
	# Cada pared es un bloque grueso hacia "afuera" de la mesa, así la bola
	# no puede atravesarla aunque vaya a máxima velocidad.
	_add_wall(Vector2(0, 460), Vector2(0, 100), Vector2.LEFT)
	var n := 32
	for i in n:
		var a0 := PI + PI * float(i) / n
		var a1 := PI + PI * float(i + 1) / n
		var p0 := ARC_CENTER + Vector2(cos(a0), sin(a0)) * ARC_RADIUS
		var p1 := ARC_CENTER + Vector2(cos(a1), sin(a1)) * ARC_RADIUS
		_add_wall(p0, p1, ((p0 + p1) * 0.5 - ARC_CENTER).normalized())
	_add_wall(Vector2(TABLE_W, 100), Vector2(TABLE_W, TABLE_H + 40), Vector2.RIGHT)
	# Separador del carril del lanzador (fino, centrado en LANE_X).
	_add_wall(Vector2(LANE_X - 3, 200), Vector2(LANE_X - 3, TABLE_H + 40), Vector2.RIGHT, 6.0, false)
	_add_wall(Vector2(LANE_X, LANE_FLOOR_Y), Vector2(TABLE_W, LANE_FLOOR_Y), Vector2.DOWN)
	# Guías que llevan la bola hacia los flippers.
	_add_wall(Vector2(0, 460), Vector2(104, 548), Vector2(-88, 104).normalized())
	# La guía derecha se recorta en el separador para no invadir el carril.
	var ga := Vector2(LANE_X - 3, 460)
	var gb := Vector2(264, 548)
	var go := Vector2(88, 104).normalized() * 24.0
	_add_poly(PackedVector2Array([ga, gb, gb + go, Vector2(LANE_X - 3, 490)]))
	_wall_segments.append([ga, gb])
	_walls.physics_material_override = _wall_material
	add_child(_walls)
	# Línea visible del separador.
	_wall_segments.append([Vector2(LANE_X, 200), Vector2(LANE_X, TABLE_H)])


func _add_poly(points: PackedVector2Array) -> void:
	var cs := CollisionShape2D.new()
	cs.shape = Shapes.convex(points)
	_walls.add_child(cs)


func _add_wall(a: Vector2, b: Vector2, outward: Vector2, thickness := 24.0, visible_line := true) -> void:
	var shape := Shapes.convex(PackedVector2Array([a, b, b + outward * thickness, a + outward * thickness]))
	var cs := CollisionShape2D.new()
	cs.shape = shape
	_walls.add_child(cs)
	if visible_line:
		_wall_segments.append([a, b])


func _build_slings() -> void:
	var left := Slingshot.new()
	left.setup(Vector2(40, 410), Vector2(92, 505), Vector2(40, 470), Vector2(95, -52))
	add_child(left)
	var right := Slingshot.new()
	right.setup(Vector2(LANE_X - 40, 410), Vector2(LANE_X - 92, 505), Vector2(LANE_X - 40, 470), Vector2(-95, -52))
	add_child(right)
	slings = [left, right]


func _build_bumpers() -> void:
	for p in BUMPER_POSITIONS:
		var b := Bumper.new()
		b.position = p
		add_child(b)
		bumpers.append(b)


func _build_flippers() -> void:
	for left in [true, false]:
		var f := Flipper.new()
		f.position = LEFT_PIVOT if left else RIGHT_PIVOT
		f.setup(left)
		add_child(f)
		flippers.append(f)


func _apply_tuning() -> void:
	_wall_material.bounce = Tuning.v("wall_bounce")
	_wall_material.friction = 0.1


# --- Loop de juego -------------------------------------------------------------

func new_game() -> void:
	score = 0
	balls_left = START_BALLS
	game_over = false
	_reset_ball_state()
	spawn_ball(BALL_SPAWN)


## Crea una bola nueva en una posición (y velocidad) dada.
func spawn_ball(pos: Vector2, vel := Vector2.ZERO) -> void:
	if ball:
		remove_child(ball)
		ball.queue_free()
	ball = Ball.new()
	ball.position = pos
	ball.linear_velocity = vel
	add_child(ball)
	ball.collided.connect(_on_ball_collided)


func _reset_ball_state() -> void:
	tilted = false
	plunger_charge = 0.0
	_nudge_times.clear()
	for f in flippers:
		f.enabled = true


func lose_ball() -> void:
	if not infinite_balls:
		balls_left -= 1
	_reset_ball_state()
	if balls_left <= 0:
		game_over = true
		spawn_ball(BALL_SPAWN)
		ball.freeze = true
		_hud.show_message("FIN DEL JUEGO\nR / Options para reiniciar", 999.0)
	else:
		_hud.show_message("Bola perdida", 1.2)
		spawn_ball(BALL_SPAWN)


func ball_in_lane() -> bool:
	var p := ball.global_position
	return p.x > LANE_X and p.y > LANE_FLOOR_Y - 40.0


func _physics_process(delta: float) -> void:
	_time += delta
	if game_over:
		return

	# Lanzador: cargar mientras se mantiene, soltar para lanzar.
	if ball_in_lane():
		if Input.is_action_pressed("launch"):
			plunger_charge = minf(1.0, plunger_charge + delta / Tuning.v("plunger_charge_time"))
		elif plunger_charge > 0.0:
			var power := maxf(plunger_charge, 0.15)
			ball.linear_velocity = Vector2(0.0, -Tuning.v("plunger_max") * power)
			plunger_charge = 0.0
	else:
		plunger_charge = 0.0

	# Bola perdida (o escapada por algún error de física).
	var p := ball.global_position
	if (p.y > DRAIN_Y or p.x < -60.0 or p.x > TABLE_W + 60.0 or p.y < -200.0):
		lose_ball()

	if Input.is_action_just_pressed("nudge_left"):
		_nudge(Vector2(-1.0, -0.3))
	if Input.is_action_just_pressed("nudge_right"):
		_nudge(Vector2(1.0, -0.3))
	if Input.is_action_just_pressed("nudge_up"):
		_nudge(Vector2(0.0, -1.0))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_hud.show_message("", 0.0)
		new_game()
	if Input.is_action_just_pressed("debug_drop_ball") and not game_over:
		_reset_ball_state()
		spawn_ball(TEST_DROP, Vector2(randf_range(-80.0, 80.0), 0.0))
	if Input.is_action_just_pressed("toggle_slowmo"):
		_slowmo = not _slowmo
		Engine.time_scale = 0.25 if _slowmo else 1.0

	# Temblor de cámara.
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_camera.offset = _shake_dir * 6.0 * (_shake / 0.15) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0 * (_shake / 0.15)
	else:
		_camera.offset = Vector2.ZERO

	_hud.set_stats(score, balls_left, ball.linear_velocity.length(), _slowmo, Input.get_connected_joypads().size())
	queue_redraw()


func _nudge(dir: Vector2) -> void:
	if tilted or ball.freeze:
		return
	ball.linear_velocity += dir.normalized() * Tuning.v("nudge_force")
	_start_shake(0.15, dir)
	_nudge_times.append(_time)
	while not _nudge_times.is_empty() and _time - _nudge_times[0] > TILT_WINDOW:
		_nudge_times.pop_front()
	if _nudge_times.size() >= TILT_LIMIT:
		tilted = true
		for f in flippers:
			f.enabled = false
		_hud.show_message("¡TILT!", 2.0)
	elif _nudge_times.size() == TILT_LIMIT - 1:
		_hud.show_message("¡Cuidado!", 0.8)


func _start_shake(duration: float, dir := Vector2.ZERO) -> void:
	_shake = duration
	_shake_dir = dir


func _on_ball_collided(body: Node) -> void:
	if body is Bumper:
		(body as Bumper).hit(ball)
		score += Bumper.POINTS
		_start_shake(0.06)
	elif body is Slingshot:
		if (body as Slingshot).try_kick(ball):
			score += Slingshot.POINTS


# --- Dibujo ------------------------------------------------------------------

func _draw() -> void:
	# Fondo de la mesa.
	var outline := PackedVector2Array([Vector2(0, TABLE_H), Vector2(0, 100)])
	for i in 33:
		var a := PI + PI * float(i) / 32.0
		outline.append(ARC_CENTER + Vector2(cos(a), sin(a)) * ARC_RADIUS)
	outline.append(Vector2(TABLE_W, TABLE_H))
	draw_colored_polygon(outline, Color(0.09, 0.1, 0.16))

	# Paredes.
	for s in _wall_segments:
		draw_line(s[0], s[1], Color(0.6, 0.65, 0.85), 3.0)

	# Resorte del lanzador.
	var top := LANE_FLOOR_Y + 2.0 + plunger_charge * 12.0
	draw_rect(Rect2(LANE_X + 6.0, top, TABLE_W - LANE_X - 12.0, 6.0), Color(0.95, 0.6, 0.3))
	if plunger_charge > 0.0:
		draw_rect(Rect2(LANE_X + 4.0, LANE_FLOOR_Y - 120.0, 4.0, 100.0 * plunger_charge), Color(1.0, 0.85, 0.4))

	if tilted:
		draw_string(ThemeDB.fallback_font, Vector2(130, 470), "TILT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1, 0.3, 0.3))
