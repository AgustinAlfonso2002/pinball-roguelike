extends TableModule
## Vórtice: chupa la bola, la hace girar en espiral hasta el centro y la
## escupe hacia arriba con fuerza, en una dirección al azar.

const RADIUS := 20.0
const SPIN_TIME := 0.75
const POINTS := 300.0
const SHOT_SPEED := 620.0
const COOLDOWN := 0.8

var _area: Area2D
var _held: TableFx.HeldBall = null
var _cool := 0.0
var _spin := 0.0
var _charge := 0.0  ## 0 a 1 mientras tiene la bola.


func _init() -> void:
	id = &"vortice"
	display_name = "Vórtice"
	sizes = ["S", "M"]
	allow_low = true
	weight = 1.0
	events = {&"vortex": {"text": "Entrá al vórtice", "goal": 5}}


func build() -> void:
	_area = Area2D.new()
	z_index = 2
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = u(RADIUS) * 0.75
	cs.shape = circle
	_area.add_child(cs)
	_area.position = center()
	_area.body_entered.connect(_on_enter)
	add_child(_area)


func on_ball_served() -> void:
	_cool = 0.0
	if _held:
		_held.queue_free()
		_held = null
		_charge = 0.0


func _on_enter(body: Node) -> void:
	if body is Ball and _cool <= 0.0 and not _held:
		_suck.call_deferred()


func _suck() -> void:
	var info := table.capture_ball()
	if info.is_empty():
		return
	Sfx.play("bumper", 0.6)
	_held = TableFx.HeldBall.new()
	_held.color = table.last_ball_color
	add_child(_held)
	var offset: Vector2 = info.pos - center()
	var start_r := maxf(offset.length(), 6.0)
	var start_a := offset.angle()
	var t := 0.0
	while t < SPIN_TIME:
		await get_tree().physics_frame
		if not is_inside_tree() or not _held:
			return
		t += get_physics_process_delta_time()
		var k := t / SPIN_TIME
		_charge = k
		var a := start_a + k * k * 14.0
		_held.position = center() + Vector2(cos(a), sin(a)) * start_r * (1.0 - k)
		_held.size = 1.0 - 0.3 * k
	_held.queue_free()
	_held = null
	_charge = 0.0
	_cool = COOLDOWN
	# Escupe la bola hacia arriba, abierto hasta 50° para cada lado.
	var dir := Vector2.UP.rotated(deg_to_rad(rng.randf_range(-50.0, 50.0)))
	var exit := center() + dir * (u(RADIUS) + Ball.RADIUS + 2.0)
	score(&"vortex", POINTS, center())
	event(&"vortex", center())
	Sfx.play("launch", 0.9)
	table.hitstop(0.8)
	table.rumble(0.4, 0.5, 0.15)
	TableFx.ring(table, center(), Color(0.7, 0.5, 1.0), u(RADIUS) * 2.0, 0.35)
	TableFx.burst(table, exit, Color(0.8, 0.6, 1.0), 10, 120.0)
	table.release_ball(exit, dir * SHOT_SPEED)


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	_spin += delta * (3.0 + 18.0 * _charge)
	queue_redraw()


func _draw() -> void:
	var c := center()
	var r := u(RADIUS)
	draw_circle(c, r, Color(0.12, 0.06, 0.22, 0.9))
	# Brazos de la espiral.
	for arm in 4:
		var pts := PackedVector2Array()
		for i in 12:
			var k := float(i) / 11.0
			var a := -_spin + arm * TAU / 4.0 + k * 3.2
			pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 - k * 0.85))
		draw_polyline(pts, Color(0.75, 0.5, 1.0, 0.45 + 0.5 * _charge), 1.2)
	draw_arc(c, r, 0.0, TAU, 28, Color(0.8, 0.6, 1.0).lerp(Color.WHITE, _charge), 1.5)
	if _cool > 0.0:
		draw_arc(c, r + 2.0, -PI * 0.5, -PI * 0.5 + TAU * (_cool / COOLDOWN), 24, Color(1, 1, 1, 0.3), 1.0)
