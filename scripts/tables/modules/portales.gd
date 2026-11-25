extends TableModule
## Dos portales: la bola entra por uno y sale por el otro con la misma
## velocidad y dirección. Ocupa dos encastres chicos.

const RADIUS := 12.0
const POINTS := 150.0
const COLORS := [Color(1.0, 0.35, 0.8), Color(0.3, 0.9, 1.0)]

var _areas: Array[Area2D] = []
var _held: TableFx.HeldBall = null
var _ignore := -1  ## Portal por el que acaba de salir la bola (se ignora hasta que se aleje).
var _spin := 0.0
var _flash := [0.0, 0.0]


func _init() -> void:
	id = &"portales"
	display_name = "Portales"
	sizes = ["S"]
	sockets_needed = 2
	allow_low = true
	weight = 1.0
	events = {&"portal": {"text": "Cruzá portales", "goal": 6}}


func build() -> void:
	z_index = 2
	for i in 2:
		var area := Area2D.new()
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = u(RADIUS) * 0.6
		cs.shape = circle
		area.add_child(cs)
		area.position = center(i)
		area.body_entered.connect(_on_enter.bind(i))
		area.body_exited.connect(_on_exit.bind(i))
		add_child(area)
		_areas.append(area)


func on_ball_served() -> void:
	_ignore = -1
	if _held:
		_held.queue_free()
		_held = null


func _on_exit(body: Node, i: int) -> void:
	if body is Ball and _ignore == i:
		_ignore = -1


func _on_enter(body: Node, i: int) -> void:
	if not (body is Ball) or i == _ignore or _held:
		return
	_teleport.call_deferred(i)


func _teleport(from: int) -> void:
	var info := table.capture_ball()
	if info.is_empty():
		return
	var to := 1 - from
	var vel: Vector2 = info.vel
	if vel.length() < 220.0:
		vel = (vel.normalized() if vel.length() > 1.0 else Vector2.UP) * 220.0
	Sfx.play("launch", 0.6)
	_flash[from] = 1.0
	TableFx.ring(table, center(from), COLORS[from], 14.0, 0.25)
	score(&"portal", POINTS, center(from))
	event(&"portal", center(from))
	# La bola se achica en un portal y aparece en el otro.
	_held = TableFx.HeldBall.new()
	_held.color = table.last_ball_color
	_held.position = info.pos
	add_child(_held)
	var tw := create_tween()
	tw.tween_property(_held, "position", center(from), 0.08)
	tw.parallel().tween_property(_held, "size", 0.1, 0.08)
	tw.tween_callback(func() -> void: _held.position = center(to))
	tw.tween_property(_held, "size", 1.0, 0.08)
	await tw.finished
	if not is_inside_tree() or not _held:
		return
	_held.queue_free()
	_held = null
	_ignore = to
	_flash[to] = 1.0
	TableFx.ring(table, center(to), COLORS[to], 14.0, 0.25)
	TableFx.burst(table, center(to), COLORS[to], 8, 70.0)
	table.release_ball(center(to), vel)


func _process(delta: float) -> void:
	_spin += delta * 4.0
	for i in 2:
		_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	for i in 2:
		var c := center(i)
		var col: Color = COLORS[i]
		var r := u(RADIUS)
		draw_circle(c, r, Color(col.darkened(0.7), 0.85))
		var dir := 1.0 if i == 0 else -1.0
		for k in 3:
			var a := _spin * dir + TAU * k / 3.0
			draw_arc(c, r * (0.45 + 0.18 * k), a, a + 2.2, 10, Color(col, 0.6 + 0.4 * _flash[i]), 1.2)
		draw_arc(c, r, 0.0, TAU, 24, col.lerp(Color.WHITE, _flash[i]), 1.5)
	# Hilo de puntos que une los dos portales.
	var a := center(0)
	var b := center(1)
	var n := int(a.distance_to(b) / 10.0)
	for k in n:
		var t := (float(k) + fmod(_spin * 0.5, 1.0)) / n
		draw_rect(Rect2(a.lerp(b, t).floor(), Vector2.ONE), Color(0.8, 0.7, 1.0, 0.18))
