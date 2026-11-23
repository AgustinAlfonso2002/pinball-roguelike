extends Node2D
## Prototipo de física: arma la mesa por código y maneja el loop básico
## (lanzar, puntaje, perder bola, sacudón/tilt) y el "juice" (sonido,
## vibración, puntos flotantes y congelamiento en los impactos).
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

## Separadores de inlane/outlane: x del separador izquierdo (el derecho es simétrico).
const LANE_GUIDE_X := 24.0
const LANE_GUIDE_TOP := 440.0
const TARGET_POSITIONS := [Vector2(150, 120), Vector2(184, 120), Vector2(218, 120)]
const BANK_BONUS := 2000

const COLOR_POINTS := Color(1.0, 0.85, 0.4)
const COLOR_BONUS := Color(0.55, 1.0, 0.6)

var ball: Ball
var flippers: Array[Flipper] = []
var bumpers: Array[Bumper] = []
var slings: Array[Slingshot] = []
var posts: Array[Post] = []
var targets: Array[DropTarget] = []

var score := 0
var balls_left := START_BALLS
var game_over := false
var tilted := false
var infinite_balls := false  ## Lo usa la autoprueba.
var juice_enabled := true  ## La autoprueba lo apaga (sin congelamientos).
var plunger_charge := 0.0

var _walls := StaticBody2D.new()
var _wall_material := PhysicsMaterial.new()
var _wall_segments: Array = []
var _wall_polys: Array[PackedVector2Array] = []
var _nudge_times: Array[float] = []
var _time := 0.0
var _shake := 0.0
var _shake_dir := Vector2.ZERO
var _slowmo := false
var _hitstop_until := 0
var _bank_resetting := false
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
	_build_posts()
	_build_slings()
	_build_bumpers()
	_build_targets()
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
	# Las paredes exteriores son bloques gruesos hacia "afuera" de la mesa,
	# así la bola no puede atravesarlas aunque vaya a máxima velocidad.
	_add_wall(Vector2(0, DRAIN_Y + 20), Vector2(0, 100), Vector2.LEFT)
	var n := 32
	for i in n:
		var a0 := PI + PI * float(i) / n
		var a1 := PI + PI * float(i + 1) / n
		var p0 := ARC_CENTER + Vector2(cos(a0), sin(a0)) * ARC_RADIUS
		var p1 := ARC_CENTER + Vector2(cos(a1), sin(a1)) * ARC_RADIUS
		_add_wall(p0, p1, ((p0 + p1) * 0.5 - ARC_CENTER).normalized())
	_add_wall(Vector2(TABLE_W, 100), Vector2(TABLE_W, DRAIN_Y + 20), Vector2.RIGHT)
	# Separador del carril del lanzador (fino, centrado en LANE_X).
	_add_wall(Vector2(LANE_X - 3, 200), Vector2(LANE_X - 3, DRAIN_Y + 20), Vector2.RIGHT, 6.0, false)
	_wall_segments.append([Vector2(LANE_X, 200), Vector2(LANE_X, TABLE_H)])
	_add_wall(Vector2(LANE_X, LANE_FLOOR_Y), Vector2(TABLE_W, LANE_FLOOR_Y), Vector2.DOWN)

	# Deflectores en las paredes laterales: evitan que la bola baje pegada
	# a la pared directo al outlane (y la mandan hacia el centro).
	_add_poly(PackedVector2Array([Vector2(0, 230), Vector2(44, 280), Vector2(0, 300)]), true)
	_add_poly(PackedVector2Array([Vector2(LANE_X - 3, 230), Vector2(LANE_X - 47, 280), Vector2(LANE_X - 3, 300)]), true)

	# Separadores inlane/outlane: un tramo vertical y otro diagonal hasta el flipper.
	for side in [1.0, -1.0]:
		var gx := LANE_GUIDE_X if side > 0 else LANE_X - LANE_GUIDE_X
		var end := Vector2(104, 548) if side > 0 else Vector2(LANE_X - 104, 548)
		_add_thin(Vector2(gx, LANE_GUIDE_TOP), Vector2(gx, 480))
		_add_thin(Vector2(gx, 480), end)

	_walls.physics_material_override = _wall_material
	add_child(_walls)


func _add_wall(a: Vector2, b: Vector2, outward: Vector2, thickness := 24.0, visible_line := true) -> void:
	_add_shape(PackedVector2Array([a, b, b + outward * thickness, a + outward * thickness]))
	if visible_line:
		_wall_segments.append([a, b])


## Pared fina de dos caras (la bola puede pasar por ambos lados).
func _add_thin(a: Vector2, b: Vector2, thickness := 6.0) -> void:
	var n := (b - a).orthogonal().normalized() * thickness * 0.5
	_add_shape(PackedVector2Array([a + n, b + n, b - n, a - n]))
	_wall_segments.append([a, b])


func _add_poly(points: PackedVector2Array, visible := false) -> void:
	_add_shape(points)
	if visible:
		_wall_polys.append(points)


func _add_shape(points: PackedVector2Array) -> void:
	var cs := CollisionShape2D.new()
	cs.shape = Shapes.convex(points)
	_walls.add_child(cs)


func _build_posts() -> void:
	for x in [LANE_GUIDE_X, LANE_X - LANE_GUIDE_X]:
		var post := Post.new()
		post.position = Vector2(x, LANE_GUIDE_TOP - 4.0)
		add_child(post)
		posts.append(post)


func _build_slings() -> void:
	var left := Slingshot.new()
	left.setup(Vector2(48, 400), Vector2(96, 490), Vector2(48, 460), Vector2(90, -48))
	add_child(left)
	var right := Slingshot.new()
	right.setup(Vector2(LANE_X - 48, 400), Vector2(LANE_X - 96, 490), Vector2(LANE_X - 48, 460), Vector2(-90, -48))
	add_child(right)
	slings = [left, right]


func _build_bumpers() -> void:
	for p in BUMPER_POSITIONS:
		var b := Bumper.new()
		b.position = p
		add_child(b)
		bumpers.append(b)


func _build_targets() -> void:
	for p in TARGET_POSITIONS:
		var t := DropTarget.new()
		t.position = p
		t.dropped.connect(_on_target_dropped)
		add_child(t)
		targets.append(t)


func _build_flippers() -> void:
	for left in [true, false]:
		var f := Flipper.new()
		f.position = LEFT_PIVOT if left else RIGHT_PIVOT
		f.setup(left)
		f.swung.connect(_on_flipper_swung)
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
	for t in targets:
		t.raise_up()
	spawn_ball(BALL_SPAWN)


## Crea una bola nueva en una posición (y velocidad) dada.
## No se teletransporta la existente: en Godot eso arrastra contactos del
## lugar viejo y puede dejar la bola del otro lado de una pared.
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
	_rumble(0.6, 0.8, 0.35)
	if balls_left <= 0:
		game_over = true
		spawn_ball(BALL_SPAWN)
		ball.freeze = true
		Sfx.play("game_over", 1.0, 0.0)
		_hud.show_message("FIN DEL JUEGO\nR / Options para reiniciar", 999.0)
	else:
		Sfx.play("drain", 1.0, 0.0)
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
			Sfx.play("launch", 0.5 + 0.5 * power)
			_rumble(0.2 * power, 0.6 * power, 0.12)
	else:
		plunger_charge = 0.0

	# Bola perdida (o escapada por algún error de física).
	var p := ball.global_position
	if p.y > DRAIN_Y or p.x < -60.0 or p.x > TABLE_W + 60.0 or p.y < -200.0:
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

	# Velocidad del juego: congelamiento breve > cámara lenta > normal.
	if Time.get_ticks_msec() < _hitstop_until:
		Engine.time_scale = 0.05
	else:
		Engine.time_scale = 0.25 if _slowmo else 1.0

	# Temblor de cámara.
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		var k := _shake / 0.15
		_camera.offset = _shake_dir * 6.0 * k + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0 * k
	else:
		_camera.offset = Vector2.ZERO

	_hud.set_stats(score, balls_left, ball.linear_velocity.length(), _slowmo, Input.get_connected_joypads().size())
	queue_redraw()


func _nudge(dir: Vector2) -> void:
	if tilted or ball.freeze:
		return
	ball.linear_velocity += dir.normalized() * Tuning.v("nudge_force")
	_start_shake(0.15, dir)
	Sfx.play("nudge")
	_rumble(0.3, 0.5, 0.1)
	_nudge_times.append(_time)
	while not _nudge_times.is_empty() and _time - _nudge_times[0] > TILT_WINDOW:
		_nudge_times.pop_front()
	if _nudge_times.size() >= TILT_LIMIT:
		tilted = true
		for f in flippers:
			f.enabled = false
		Sfx.play("tilt", 1.0, 0.0)
		_rumble(0.8, 1.0, 0.5)
		_hud.show_message("¡TILT!", 2.0)
	elif _nudge_times.size() == TILT_LIMIT - 1:
		_hud.show_message("¡Cuidado!", 0.8)


# --- Puntaje y eventos ---------------------------------------------------------

func _add_points(points: int, at: Vector2, color := COLOR_POINTS, size := 16) -> void:
	score += points
	if juice_enabled:
		var ft := FloatingText.new("+%d" % points, color, size)
		ft.position = at + Vector2(0, -12)
		add_child(ft)


func _on_ball_collided(body: Node) -> void:
	var speed := ball.linear_velocity.length()
	if body is Bumper:
		(body as Bumper).hit(ball)
		_add_points(Bumper.POINTS, body.global_position)
		Sfx.play("bumper")
		_rumble(0.35, 0.25, 0.08)
		_hitstop(1.0)
		_start_shake(0.06)
	elif body is Slingshot:
		if (body as Slingshot).try_kick(ball):
			_add_points(Slingshot.POINTS, ball.global_position)
			Sfx.play("sling")
			_rumble(0.25, 0.15, 0.06)
	elif body is DropTarget:
		var target := body as DropTarget
		if target.hit():
			_add_points(DropTarget.POINTS, target.global_position)
			Sfx.play("target")
			_rumble(0.3, 0.2, 0.07)
			_hitstop(0.6)
	elif body is Post:
		if speed > 150.0:
			(body as Post).flash = 1.0
			Sfx.play("post", clampf(speed / 1200.0, 0.3, 1.0))
	elif body is Flipper:
		var flipper := body as Flipper
		if flipper.is_swinging_up():
			# Golpe fuerte de flipper: un poco de vibración y congelamiento.
			_rumble(0.15, 0.35, 0.06)
			_hitstop(0.5)


func _on_target_dropped() -> void:
	if _bank_resetting:
		return
	for t in targets:
		if not t.is_down:
			return
	# ¡Banco completo!
	_bank_resetting = true
	var center: Vector2 = TARGET_POSITIONS[1]
	_add_points(BANK_BONUS, center + Vector2(0, -16), COLOR_BONUS, 22)
	Sfx.play("bank_complete", 1.0, 0.0)
	_rumble(0.5, 0.6, 0.25)
	_hud.show_message("¡BANCO COMPLETO!  +%d" % BANK_BONUS, 1.5)
	await get_tree().create_timer(1.2).timeout
	# No subir las dianas encima de la bola.
	while _ball_near_targets():
		await get_tree().create_timer(0.2).timeout
	for t in targets:
		t.raise_up()
	_bank_resetting = false


func _ball_near_targets() -> bool:
	for p in TARGET_POSITIONS:
		if ball.global_position.distance_to(p) < 24.0:
			return true
	return false


func _on_flipper_swung(up: bool) -> void:
	if up:
		Sfx.play("flipper_up")
		_rumble(0.08, 0.0, 0.04)
	else:
		Sfx.play("flipper_down", 0.6)


# --- Juice ---------------------------------------------------------------------

## Congela el juego un instante (intensity escala la duración configurada).
func _hitstop(intensity: float) -> void:
	if not juice_enabled:
		return
	var ms := int(Tuning.v("hitstop_ms") * intensity)
	if ms > 0:
		_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + ms)


func _rumble(weak: float, strong: float, duration: float) -> void:
	var k := Tuning.v("vibration")
	if k <= 0.0 or not juice_enabled:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(weak * k, 0.0, 1.0), clampf(strong * k, 0.0, 1.0), duration)


func _start_shake(duration: float, dir := Vector2.ZERO) -> void:
	if not juice_enabled:
		return
	_shake = duration
	_shake_dir = dir


# --- Dibujo ------------------------------------------------------------------

func _draw() -> void:
	# Fondo de la mesa.
	var outline := PackedVector2Array([Vector2(0, TABLE_H), Vector2(0, 100)])
	for i in 33:
		var a := PI + PI * float(i) / 32.0
		outline.append(ARC_CENTER + Vector2(cos(a), sin(a)) * ARC_RADIUS)
	outline.append(Vector2(TABLE_W, TABLE_H))
	draw_colored_polygon(outline, Color(0.09, 0.1, 0.16))

	# Paredes y deflectores.
	for poly in _wall_polys:
		draw_colored_polygon(poly, Color(0.25, 0.27, 0.4))
	for s in _wall_segments:
		draw_line(s[0], s[1], Color(0.6, 0.65, 0.85), 3.0)

	# Resorte del lanzador.
	var spring_top := LANE_FLOOR_Y + 2.0 + plunger_charge * 12.0
	draw_rect(Rect2(LANE_X + 6.0, spring_top, TABLE_W - LANE_X - 12.0, 6.0), Color(0.95, 0.6, 0.3))
	if plunger_charge > 0.0:
		draw_rect(Rect2(LANE_X + 4.0, LANE_FLOOR_Y - 120.0, 4.0, 100.0 * plunger_charge), Color(1.0, 0.85, 0.4))

	if tilted:
		draw_string(ThemeDB.fallback_font, Vector2(130, 470), "TILT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1, 0.3, 0.3))
