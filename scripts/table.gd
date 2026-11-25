class_name PinballTable
extends Node2D
## La mesa de pinball: geometría, física, lanzador, sacudón/tilt y "juice".
##
## No sabe nada de partidas ni de objetos: avisa lo que pasa con señales y
## quien la usa (GameSession) decide qué hacer (sumar puntos, servir otra bola...).
##
## Coordenadas: la mesa se diseñó en unidades originales (400 x 640) y todo
## se multiplica por Geom.S para dibujarla a 640 x 360.
##
## La parte de abajo (flippers, slingshots, carriles, lanzador) es fija. La de
## arriba la arma `layout` (TableLayout): un chasis con paredes propias y los
## módulos en sus encastres. Sin layout se arma la mesa clásica de siempre.

signal hit(source: StringName, base: float, position: Vector2, node: Node)
signal ball_lost
signal ball_launched(power: float)
signal flipper_swung(left: bool, up: bool)
signal bank_completed
## Un módulo avisa algo para los objetivos (portal cruzado, ladrillo roto...).
signal module_event(tag: StringName, position: Vector2, module: TableModule)

const S := Geom.S
const TABLE_W := 400.0 * S
const TABLE_H := 640.0 * S
const LANE_X := 368.0 * S
const LANE_FLOOR_Y := 604.0 * S
const ARC_CENTER := Vector2(200.0, 100.0) * S
const ARC_RADIUS := 200.0 * S
const BALL_SPAWN := Vector2(384.0, 592.0) * S
const TEST_DROP := Vector2(184.0, 380.0) * S
const DRAIN_Y := 690.0 * S
const TILT_WINDOW := 3.0
const TILT_LIMIT := 4

const LEFT_PIVOT := Vector2(110.0, 556.0) * S
const RIGHT_PIVOT := Vector2(258.0, 556.0) * S
const BUMPER_POSITIONS := [Vector2(130, 210) * S, Vector2(240, 210) * S, Vector2(185, 300) * S]
const LANE_GUIDE_X := 24.0 * S
const LANE_GUIDE_TOP := 440.0 * S
const TARGET_POSITIONS := [Vector2(150, 120) * S, Vector2(184, 120) * S, Vector2(218, 120) * S]

const BUMPER_POINTS := 100.0
const SLING_POINTS := 10.0
const TARGET_POINTS := 250.0
const POST_POINTS := 5.0

## Centro de la cámara: muestra la mesa entera en 640 x 360.
const CAMERA_CENTER := Vector2(200.0, 262.0) * S

var ball: Ball = null
var flippers: Array[Flipper] = []
var bumpers: Array[Bumper] = []
var slings: Array[Slingshot] = []
var posts: Array[Post] = []
var targets: Array[DropTarget] = []

var layout: TableLayout = null  ## Se asigna antes de agregar la mesa al árbol.
var chassis: Chassis
var modules: Array[TableModule] = []
var input_enabled := true  ## false = ignora flippers, lanzador y sacudón.
var robot_mode := false  ## La juega TableRobot: ignora al jugador.
var robot_launch := false  ## El robot mantiene apretado el lanzador.
var time_scale_override := 0.0  ## > 0: fija Engine.time_scale (robot acelerado).
var ball_held := false  ## Un módulo tiene la bola (riel, catapulta, vórtice).
var last_ball_color := Color(0.80, 0.83, 0.92)
var juice_enabled := true  ## La autoprueba lo apaga (sin congelamientos).
var tilted := false
var plunger_charge := 0.0

var _walls := StaticBody2D.new()
var _wall_material := PhysicsMaterial.new()
var _wall_segments: Array = []
var _wall_polys: Array[PackedVector2Array] = []
var _nudge_times: Array[float] = []
var _time := 0.0
var _shake := 0.0
var _shake_dir := Vector2.ZERO
var _debug_slowmo := false
var _hitstop_until := 0
var _effect_slowmo := 1.0
var _effect_slowmo_until := 0
var _bank_resetting := false
var _launch_armed := false  ## Evita lanzar con la misma tecla que cerró un cartel.
var _blackouts: Array = []  # [{rect: Rect2, until: float}]
var _jams: Array = []  # [{flipper: Flipper, until: float}]
var _camera := Camera2D.new()
var _overlay := Overlay.new()


func _ready() -> void:
	_camera.position = CAMERA_CENTER
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(_camera)
	_camera.make_current()

	if layout == null:
		layout = TableGenerator.default_layout()
	chassis = TableParts.chassis(layout.chassis_id)
	_build_walls()
	_build_posts()
	_build_slings()
	_build_flippers()
	chassis.build(self)
	_build_modules()

	_overlay.table = self
	_overlay.z_index = 20
	add_child(_overlay)

	Tuning.changed.connect(_apply_tuning)
	_apply_tuning()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- Construcción de la mesa -------------------------------------------------

func _build_walls() -> void:
	# Las paredes exteriores son bloques gruesos hacia "afuera" de la mesa,
	# así la bola no puede atravesarlas aunque vaya a máxima velocidad.
	# Grosor fijo (no escalado): a mayor grosor, más difícil que la bola atraviese.
	var thick := 30.0
	_add_wall(Vector2(0, DRAIN_Y + 10), Vector2(0, 100 * S), Vector2.LEFT, thick)
	var n := 32
	for i in n:
		var a0 := PI + PI * float(i) / n
		var a1 := PI + PI * float(i + 1) / n
		var p0 := ARC_CENTER + Vector2(cos(a0), sin(a0)) * ARC_RADIUS
		var p1 := ARC_CENTER + Vector2(cos(a1), sin(a1)) * ARC_RADIUS
		# Cada tramo se superpone un poco con los vecinos para no dejar uniones.
		var t := (p1 - p0).normalized() * 1.5
		_add_shape(PackedVector2Array([p0 - t, p1 + t, p1 + t + ((p1 - ARC_CENTER).normalized()) * thick, p0 - t + ((p0 - ARC_CENTER).normalized()) * thick]))
		_wall_segments.append([p0, p1])
	_add_wall(Vector2(TABLE_W, 100 * S), Vector2(TABLE_W, DRAIN_Y + 10), Vector2.RIGHT, thick)
	# Separador del carril del lanzador (fino, centrado en LANE_X).
	_add_wall(Vector2(LANE_X - 3 * S, 200 * S), Vector2(LANE_X - 3 * S, DRAIN_Y + 10), Vector2.RIGHT, 6.0 * S, false)
	_wall_segments.append([Vector2(LANE_X, 200 * S), Vector2(LANE_X, TABLE_H)])
	_add_wall(Vector2(LANE_X, LANE_FLOOR_Y), Vector2(TABLE_W, LANE_FLOOR_Y), Vector2.DOWN, thick)

	# Separadores inlane/outlane: un tramo vertical y otro diagonal hasta el flipper.
	for side in [1.0, -1.0]:
		var gx := LANE_GUIDE_X if side > 0 else LANE_X - LANE_GUIDE_X
		var end := Vector2(104, 548) * S if side > 0 else Vector2(264, 548) * S
		_add_thin(Vector2(gx, LANE_GUIDE_TOP), Vector2(gx, 480 * S))
		_add_thin(Vector2(gx, 480 * S), end)

	_walls.physics_material_override = _wall_material
	add_child(_walls)


func _add_wall(a: Vector2, b: Vector2, outward: Vector2, thickness: float, visible_line := true) -> void:
	_add_shape(PackedVector2Array([a, b, b + outward * thickness, a + outward * thickness]))
	if visible_line:
		_wall_segments.append([a, b])


## Pared fina de dos caras (la bola puede pasar por ambos lados).
func _add_thin(a: Vector2, b: Vector2) -> void:
	var n := (b - a).orthogonal().normalized() * 3.0 * S
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
		post.position = Vector2(x, LANE_GUIDE_TOP - 4.0 * S)
		add_child(post)
		posts.append(post)


func _build_slings() -> void:
	var left := Slingshot.new()
	left.setup(Vector2(48, 400) * S, Vector2(96, 490) * S, Vector2(48, 460) * S, Vector2(90, -48))
	add_child(left)
	var right := Slingshot.new()
	right.setup(Vector2(320, 400) * S, Vector2(272, 490) * S, Vector2(320, 460) * S, Vector2(-90, -48))
	add_child(right)
	slings = [left, right]


func _build_flippers() -> void:
	for left in [true, false]:
		_make_flipper(LEFT_PIVOT if left else RIGHT_PIVOT, left)


func _make_flipper(pivot: Vector2, left: bool) -> Flipper:
	var f := Flipper.new()
	f.position = pivot
	f.setup(left)
	f.swung.connect(_on_flipper_swung.bind(left))
	add_child(f)
	flippers.append(f)
	return f


func _build_modules() -> void:
	for p in layout.placements:
		var m := TableParts.create_module(p.module)
		if m == null:
			push_warning("Módulo desconocido: %s" % p.module)
			continue
		m.table = self
		m.chassis = chassis
		for i in p.sockets:
			m.rects.append(chassis.socket_rect(i))
		m.rng.seed = hash([layout.seed, p.module, p.sockets])
		add_child(m)
		m.build()
		modules.append(m)


# --- Para chasis y módulos (coordenadas en unidades de diseño) -----------------

## Pared maciza convexa (los chasis la usan para deflectores y paredes internas).
func add_wall_poly(points_units: Array) -> void:
	var pts := PackedVector2Array()
	for p in points_units:
		pts.append(p * S)
	_add_poly(pts, true)


## Flipper extra (se mueve con el botón de su lado).
func add_flipper(pivot_units: Vector2, left: bool) -> Flipper:
	return _make_flipper(pivot_units * S, left)


## Agrega un bumper (los módulos lo usan; queda en `bumpers`).
func add_bumper(pos: Vector2) -> Bumper:
	var b := Bumper.new()
	b.position = pos
	add_child(b)
	bumpers.append(b)
	return b


## Agrega una diana (los módulos la usan; queda en `targets` y cuenta para el banco).
func add_target(pos: Vector2) -> DropTarget:
	var t := DropTarget.new()
	t.position = pos
	t.dropped.connect(_on_target_dropped)
	add_child(t)
	targets.append(t)
	return t


func _apply_tuning() -> void:
	_wall_material.bounce = Run.stat(&"wall_bounce")
	_wall_material.friction = 0.1


# --- Bola ------------------------------------------------------------------------

## Pone una bola nueva en el lanzador.
func serve_ball() -> void:
	_reset_ball_state()
	ball_held = false
	spawn_ball(BALL_SPAWN)
	for m in modules:
		m.on_ball_served()


## Crea una bola nueva en una posición (y velocidad) dada.
## No se teletransporta la existente: en Godot eso arrastra contactos del
## lugar viejo y puede dejar la bola del otro lado de una pared.
func spawn_ball(pos: Vector2, vel := Vector2.ZERO) -> void:
	remove_ball()
	ball = Ball.new()
	ball.position = pos
	ball.linear_velocity = vel
	Run.notify(&"configure_ball", [ball])
	add_child(ball)
	ball.collided.connect(_on_ball_collided)
	last_ball_color = ball.color


## Un módulo se queda con la bola (riel, catapulta, vórtice): la bola real
## desaparece y el módulo dibuja una de mentira hasta soltarla.
## Devuelve {pos, vel} de la bola al momento de agarrarla, o {} si no había.
func capture_ball() -> Dictionary:
	if not ball or ball_held:
		return {}
	var info := {"pos": ball.global_position, "vel": ball.linear_velocity}
	last_ball_color = ball.color
	remove_ball()
	ball_held = true
	return info


## Devuelve la bola al juego en una posición y velocidad.
func release_ball(pos: Vector2, vel: Vector2) -> void:
	if not ball_held:
		return
	ball_held = false
	spawn_ball(pos, vel)


## Hay una bola en juego (en la mesa o en manos de un módulo).
func ball_in_play() -> bool:
	return ball != null or ball_held


func remove_ball() -> void:
	if ball:
		remove_child(ball)
		ball.queue_free()
		ball = null


func _reset_ball_state() -> void:
	tilted = false
	plunger_charge = 0.0
	_nudge_times.clear()
	for f in flippers:
		f.enabled = true


func ball_in_lane() -> bool:
	if not ball:
		return false
	var p := ball.global_position
	return p.x > LANE_X and p.y > LANE_FLOOR_Y - 40.0 * S


func ball_speed() -> float:
	return ball.linear_velocity.length() if ball else 0.0


func nudge_force() -> float:
	return Run.stat(&"nudge_force")


# --- Loop ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	_update_timed_effects()
	if not ball:
		return

	# Lanzador: cargar mientras se mantiene, soltar para lanzar.
	var launch_pressed := robot_launch if robot_mode else (input_enabled and Input.is_action_pressed("launch"))
	if not launch_pressed:
		_launch_armed = true
	if ball_in_lane() and _launch_armed:
		if launch_pressed:
			plunger_charge = minf(1.0, plunger_charge + delta / Run.stat(&"plunger_charge_time"))
		elif plunger_charge > 0.0:
			var power := maxf(plunger_charge, 0.15)
			ball.linear_velocity = Vector2(0.0, -Run.stat(&"plunger_max") * power)
			plunger_charge = 0.0
			Sfx.play("launch", 0.5 + 0.5 * power)
			rumble(0.2 * power, 0.6 * power, 0.12)
			ball_launched.emit(power)
	else:
		plunger_charge = 0.0

	# Bola perdida (o escapada por algún error de física).
	var p := ball.global_position
	if p.y > DRAIN_Y or p.x < -30.0 or p.x > TABLE_W + 30.0 or p.y < -100.0:
		remove_ball()
		_reset_ball_state()
		rumble(0.6, 0.8, 0.35)
		ball_lost.emit()
		return

	if input_enabled and not robot_mode:
		if Input.is_action_just_pressed("nudge_left"):
			_nudge(Vector2(-1.0, -0.3))
		if Input.is_action_just_pressed("nudge_right"):
			_nudge(Vector2(1.0, -0.3))
		if Input.is_action_just_pressed("nudge_up"):
			_nudge(Vector2(0.0, -1.0))


func _process(delta: float) -> void:
	if OS.is_debug_build() and input_enabled:
		if Input.is_action_just_pressed("debug_drop_ball") and ball:
			_reset_ball_state()
			spawn_ball(TEST_DROP, Vector2(randf_range(-40.0, 40.0), 0.0))
		if Input.is_action_just_pressed("toggle_slowmo"):
			_debug_slowmo = not _debug_slowmo

	# Velocidad del juego: congelamiento breve > efectos > cámara lenta debug.
	var now := Time.get_ticks_msec()
	if now < _hitstop_until:
		Engine.time_scale = 0.05
	else:
		# Velocidad general (panel de ajuste): ralentiza todo por igual sin
		# cambiar cómo rebota la bola.
		var ts := time_scale_override if time_scale_override > 0.0 else Tuning.v("game_speed")
		if now < _effect_slowmo_until:
			ts *= _effect_slowmo
		if _debug_slowmo:
			ts *= 0.25
		Engine.time_scale = ts

	# Temblor de cámara.
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		var k := _shake / 0.15
		_camera.offset = (_shake_dir * 3.0 * k + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * k).round()
	else:
		_camera.offset = Vector2.ZERO
	queue_redraw()
	_overlay.queue_redraw()


func is_debug_slowmo() -> bool:
	return _debug_slowmo


func _nudge(dir: Vector2) -> void:
	if tilted or not ball:
		return
	ball.linear_velocity += dir.normalized() * nudge_force()
	start_shake(0.15, dir)
	Sfx.play("nudge")
	rumble(0.3, 0.5, 0.1)
	_nudge_times.append(_time)
	while not _nudge_times.is_empty() and _time - _nudge_times[0] > TILT_WINDOW:
		_nudge_times.pop_front()
	if _nudge_times.size() >= TILT_LIMIT:
		tilted = true
		for f in flippers:
			f.enabled = false
		Sfx.play("tilt", 1.0, 0.0)
		rumble(0.8, 1.0, 0.5)
		show_text("¡TILT!", CAMERA_CENTER, Color(1, 0.3, 0.3), GameFonts.WORLD_BIG)
	elif _nudge_times.size() == TILT_LIMIT - 1:
		show_text("¡Cuidado!", CAMERA_CENTER, Color(1, 0.6, 0.3), GameFonts.WORLD_BIG)


# --- Sabotajes y efectos (los usan rivales y objetos) ---------------------------

## Empuja la bola (sin contar para el tilt).
func shove_ball(dir: Vector2, force: float) -> void:
	if not ball or ball_in_lane():
		return
	ball.linear_velocity += dir.normalized() * force
	start_shake(0.25, dir)
	Sfx.play("nudge", 1.0, 0.0)
	rumble(0.6, 0.9, 0.25)


## Oscurece una zona de la mesa durante unos segundos.
func blackout(rect: Rect2, seconds: float) -> void:
	_blackouts.append({"rect": rect, "until": _time + seconds})


## Traba un flipper durante unos segundos.
func jam_flipper(left: bool, seconds: float) -> void:
	var f: Flipper = flippers[0] if left else flippers[1]
	f.jammed = true
	_jams.append({"flipper": f, "until": _time + seconds})
	Sfx.play("tilt", 0.5, 0.0)
	show_text("¡Flipper trabado!", f.global_position + Vector2(0, -16), Color(1, 0.4, 0.3), GameFonts.SMALL_SIZE)


## Cámara lenta por un efecto (scale 0,5 = mitad de velocidad). Dura `seconds` reales.
func set_effect_slowmo(time_scale: float, seconds: float) -> void:
	_effect_slowmo = time_scale
	_effect_slowmo_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func _update_timed_effects() -> void:
	for i in range(_blackouts.size() - 1, -1, -1):
		if _time >= _blackouts[i].until:
			_blackouts.remove_at(i)
	for i in range(_jams.size() - 1, -1, -1):
		if _time >= _jams[i].until:
			_jams[i].flipper.jammed = false
			_jams.remove_at(i)


# --- Golpes ----------------------------------------------------------------------

func _on_ball_collided(body: Node) -> void:
	var speed := ball.linear_velocity.length()
	if body is Bumper:
		(body as Bumper).hit(ball)
		Sfx.play("bumper")
		rumble(0.35, 0.25, 0.08)
		hitstop(1.0)
		start_shake(0.06)
		hit.emit(&"bumper", BUMPER_POINTS, body.global_position, body)
		module_event.emit(body.get_meta("event", &"bumper"), body.global_position, body.get_meta("module", null))
	elif body is Slingshot:
		if (body as Slingshot).try_kick(ball):
			Sfx.play("sling")
			rumble(0.25, 0.15, 0.06)
			hit.emit(&"sling", SLING_POINTS, ball.global_position, body)
	elif body is DropTarget:
		var target := body as DropTarget
		if target.hit():
			Sfx.play("target")
			rumble(0.3, 0.2, 0.07)
			hitstop(0.6)
			hit.emit(&"target", TARGET_POINTS, target.global_position, target)
			module_event.emit(&"target", target.global_position, target.get_meta("module", null))
	elif body is Post:
		if speed > 75.0:
			(body as Post).flash = 1.0
			Sfx.play("post", clampf(speed / 600.0, 0.3, 1.0))
			hit.emit(&"post", POST_POINTS, body.global_position, body)
	elif body.has_method("ball_hit"):
		body.ball_hit(ball)
	elif body is Flipper:
		if (body as Flipper).is_swinging_up():
			# Golpe fuerte de flipper: un poco de vibración y congelamiento.
			rumble(0.15, 0.35, 0.06)
			hitstop(0.5)


func _on_target_dropped() -> void:
	if _bank_resetting:
		return
	for t in targets:
		if not t.is_down:
			return
	# ¡Banco completo!
	_bank_resetting = true
	Sfx.play("bank_complete", 1.0, 0.0)
	rumble(0.5, 0.6, 0.25)
	var mid: Vector2 = targets[targets.size() / 2].global_position if not targets.is_empty() else CAMERA_CENTER
	hit.emit(&"bank", Run.stat(&"bank_bonus"), mid + Vector2(0, -8), null)
	module_event.emit(&"bank", mid, null)
	bank_completed.emit()
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	# No subir las dianas encima de la bola.
	while _ball_near_targets():
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return
	for t in targets:
		t.raise_up()
	_bank_resetting = false


func _ball_near_targets() -> bool:
	if not ball:
		return false
	for t in targets:
		if ball.global_position.distance_to(t.global_position) < 12.0:
			return true
	return false


func _on_flipper_swung(up: bool, left: bool) -> void:
	if up:
		Sfx.play("flipper_up")
		rumble(0.08, 0.0, 0.04)
	else:
		Sfx.play("flipper_down", 0.6)
	flipper_swung.emit(left, up)


# --- Juice ---------------------------------------------------------------------

## Texto flotante sobre la mesa (puntos, avisos).
func show_text(text: String, at: Vector2, color := Color(1.0, 0.85, 0.4), size := GameFonts.SMALL_SIZE) -> void:
	if not juice_enabled:
		return
	var ft := FloatingText.new(text, color, size)
	ft.position = at + Vector2(0, -6)
	add_child(ft)


## Congela el juego un instante (intensity escala la duración configurada).
func hitstop(intensity: float) -> void:
	if not juice_enabled:
		return
	var ms := int(Tuning.v("hitstop_ms") * intensity)
	if ms > 0:
		_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + ms)


func rumble(weak: float, strong: float, duration: float) -> void:
	var k := Tuning.v("vibration")
	if k <= 0.0 or not juice_enabled:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(weak * k, 0.0, 1.0), clampf(strong * k, 0.0, 1.0), duration)


func start_shake(duration: float, dir := Vector2.ZERO) -> void:
	if not juice_enabled:
		return
	_shake = duration
	_shake_dir = dir


# --- Dibujo ------------------------------------------------------------------

func _draw() -> void:
	# Fondo de la mesa.
	var outline := PackedVector2Array([Vector2(0, TABLE_H), Vector2(0, 100 * S)])
	for i in 33:
		var a := PI + PI * float(i) / 32.0
		outline.append(ARC_CENTER + Vector2(cos(a), sin(a)) * ARC_RADIUS)
	outline.append(Vector2(TABLE_W, TABLE_H))
	draw_colored_polygon(outline, Color(0.09, 0.1, 0.16))

	# Paredes y deflectores.
	for poly in _wall_polys:
		draw_colored_polygon(poly, Color(0.25, 0.27, 0.4))
	for s in _wall_segments:
		draw_line(s[0], s[1], Color(0.6, 0.65, 0.85), 1.5)

	# Resorte del lanzador.
	var spring_top := LANE_FLOOR_Y + 1.0 + plunger_charge * 4.0
	draw_rect(Rect2(LANE_X + 3.0, spring_top, TABLE_W - LANE_X - 6.0, 2.0), Color(0.95, 0.6, 0.3))
	if plunger_charge > 0.0:
		draw_rect(Rect2(LANE_X + 2.0, LANE_FLOOR_Y - 60.0, 2.0, 50.0 * plunger_charge), Color(1.0, 0.85, 0.4))


## Capa que se dibuja encima de todo (apagones).
class Overlay extends Node2D:
	var table: PinballTable

	func _draw() -> void:
		for b in table._blackouts:
			var left: float = b.until - table._time
			var alpha := clampf(left * 2.0, 0.0, 0.94)
			draw_rect(b.rect, Color(0.0, 0.0, 0.02, alpha))
