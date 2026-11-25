extends TableModule
## Catapulta: atrapa la bola, tensa el brazo y la lanza por el aire (con
## sombra) hasta otra zona de la mesa. Al aterrizar hace una onda que golpea
## todo lo que esté cerca: bumpers, dianas y ladrillos.

const CUP_RADIUS := 12.0
const WINDUP := 0.4
const FLIGHT := 0.9
const PEAK := 70.0  ## Altura máxima del vuelo (píxeles de mesa).
const SHOCK_RADIUS := 36.0  ## En unidades de diseño.
const LAUNCH_POINTS := 400.0
const LAND_POINTS := 250.0

var _area: Area2D
var _held: TableFx.HeldBall = null
var _cool := 0.0
var _arm := 0.0  ## 0 = en reposo, 1 = tensado.
var _target := Vector2.ZERO
var _aim_blink := 0.0


func _init() -> void:
	id = &"catapulta"
	display_name = "Catapulta"
	sizes = ["S", "M"]
	allow_low = true
	weight = 1.0
	events = {&"catapult": {"text": "Volá con la catapulta", "goal": 3, "big": true}}


func build() -> void:
	_area = Area2D.new()
	z_index = 2
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = u(CUP_RADIUS) * 0.7
	cs.shape = circle
	_area.add_child(cs)
	_area.position = center()
	_area.body_entered.connect(_on_enter)
	add_child(_area)


func on_ball_served() -> void:
	_cool = 0.0
	_arm = 0.0
	if _held:
		_held.queue_free()
		_held = null


func _on_enter(body: Node) -> void:
	if body is Ball and _cool <= 0.0 and not _held:
		_launch.call_deferred()


func _launch() -> void:
	var info := table.capture_ball()
	if info.is_empty():
		return
	Sfx.play("target", 0.7)
	_held = TableFx.HeldBall.new()
	_held.color = table.last_ball_color
	_held.position = center()
	add_child(_held)
	_target = _pick_landing()
	# Tensar el brazo.
	var t := 0.0
	while t < WINDUP:
		await get_tree().physics_frame
		if not _alive():
			return
		t += get_physics_process_delta_time()
		_arm = t / WINDUP
		_held.position = center() + Vector2(0, 3.0 * _arm)
	# ¡Vuela!
	Sfx.play("launch", 1.0)
	table.rumble(0.3, 0.6, 0.15)
	score(&"catapult", LAUNCH_POINTS, center())
	event(&"catapult", center())
	var from := center()
	t = 0.0
	while t < FLIGHT:
		await get_tree().physics_frame
		if not _alive():
			return
		t += get_physics_process_delta_time()
		var k := t / FLIGHT
		_arm = maxf(0.0, 1.0 - k * 6.0)
		_held.position = from.lerp(_target, k)
		_held.height = sin(PI * k) * PEAK
	_held.queue_free()
	_held = null
	_land()


func _alive() -> bool:
	return is_inside_tree() and _held != null


func _land() -> void:
	_cool = 1.0
	Sfx.play("bumper", 1.0, 0.0)
	table.hitstop(1.5)
	table.start_shake(0.2, Vector2.DOWN)
	table.rumble(0.6, 0.8, 0.2)
	TableFx.ring(table, _target, Color(1.0, 0.75, 0.3), u(SHOCK_RADIUS), 0.4)
	TableFx.burst(table, _target, Color(1.0, 0.8, 0.4), 16, 140.0)
	score(&"catapult", LAND_POINTS, _target)
	_shockwave(_target)
	var dir := Vector2(rng.randf_range(-0.6, 0.6), 1.0).normalized()
	table.release_ball(_target, dir * 120.0)


## Golpea todo lo que esté cerca del aterrizaje.
func _shockwave(at: Vector2) -> void:
	var r := u(SHOCK_RADIUS) + 10.0
	for b in table.bumpers:
		if b.global_position.distance_to(at) < r:
			b.flash = 1.0
			table.hit.emit(&"bumper", PinballTable.BUMPER_POINTS, b.global_position, b)
			table.module_event.emit(b.get_meta("event", &"bumper"), b.global_position, b.get_meta("module", null))
	for tg in table.targets:
		if tg.global_position.distance_to(at) < r and tg.hit():
			table.hit.emit(&"target", PinballTable.TARGET_POINTS, tg.global_position, tg)
			table.module_event.emit(&"target", tg.global_position, tg.get_meta("module", null))
	for node in table.get_children():
		if node.has_method("shock") and node is Node2D and node.global_position.distance_to(at) < r:
			node.shock()


## Elige dónde aterriza: cerca de otra pieza (para que la onda la golpee),
## en un lugar libre para que la bola no aparezca dentro de algo.
func _pick_landing() -> Vector2:
	var candidates: Array[Vector2] = []
	for m in table.modules:
		if m != self:
			for rc in m.rects:
				candidates.append(rc.get_center() + Vector2(rng.randf_range(-20, 20), rng.randf_range(-6, 18)))
	for i in 6:
		candidates.append(Vector2(rng.randf_range(40, 330), rng.randf_range(70, 330)) * Geom.S)
	candidates.shuffle()
	var space := table.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Ball.RADIUS + 3.0
	query.shape = circle
	query.collide_with_areas = false
	for p in candidates:
		if p.distance_to(center()) < u(60):
			continue
		# Bordes de la mesa: lejos de las paredes del arco y del carril.
		if p.x < u(20) or p.x > u(345) or p.y < u(60) or p.y > u(380):
			continue
		if p.distance_to(PinballTable.ARC_CENTER) > PinballTable.ARC_RADIUS - u(24) and p.y < PinballTable.ARC_CENTER.y:
			continue
		query.transform = Transform2D(0.0, p)
		if space.intersect_shape(query, 1).is_empty():
			return p
	return Vector2(184, 330) * Geom.S


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if not _held:
		_arm = maxf(0.0, _arm - delta * 4.0)
	_aim_blink += delta
	queue_redraw()


func _draw() -> void:
	var c := center()
	var r := u(CUP_RADIUS)
	# Base y brazo.
	draw_rect(Rect2(c + Vector2(-r - 2, r * 0.4), Vector2(2 * r + 4, 3)), Color(0.45, 0.32, 0.2))
	var arm_end := c + Vector2(0, -r * 0.2 + 4.0 * _arm)
	draw_line(c + Vector2(0, r * 0.4), arm_end, Color(0.6, 0.45, 0.3), 2.0)
	draw_arc(c, r, 0.15 * PI, 0.85 * PI, 12, Color(1.0, 0.7, 0.35), 2.0)
	draw_arc(c, r, 0.0, TAU, 24, Color(1.0, 0.7, 0.35, 0.35), 1.0)
	# Mira en el punto de aterrizaje mientras vuela.
	if _held:
		var blink := 0.5 + 0.5 * sin(_aim_blink * 20.0)
		draw_arc(_target, 6.0, 0.0, TAU, 16, Color(1.0, 0.8, 0.4, 0.5 + 0.5 * blink), 1.0)
		draw_line(_target + Vector2(-9, 0), _target + Vector2(-4, 0), Color(1.0, 0.8, 0.4, 0.8), 1.0)
		draw_line(_target + Vector2(4, 0), _target + Vector2(9, 0), Color(1.0, 0.8, 0.4, 0.8), 1.0)
	if _cool > 0.0:
		draw_arc(c, r + 2.0, -PI * 0.5, -PI * 0.5 + TAU * _cool, 24, Color(1, 1, 1, 0.3), 1.0)
