extends TableModule
## Molinete (spinner): una paleta que la bola atraviesa y la hace girar.
## Mientras más rápido pasa la bola, más vueltas da; cada media vuelta suma.
## No frena la bola: es una pieza "de mentira", solo cuenta.

const WIDTH := 40.0  ## Unidades.
const SPIN_POINTS := 25.0

var _area: Area2D
var _angle := 0.0
var _speed := 0.0  ## Radianes por segundo.
var _half_turns := 0
var _glow := 0.0


func _init() -> void:
	id = &"molinete"
	display_name = "Molinete"
	sizes = ["S"]
	allow_low = true
	weight = 1.0
	events = {&"spinner": {"text": "Hacé girar el molinete", "goal": 6}}


func build() -> void:
	_area = Area2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(u(WIDTH), u(8))
	cs.shape = rect
	_area.add_child(cs)
	_area.position = center()
	_area.body_entered.connect(_on_enter)
	add_child(_area)
	# Postes del marco (de verdad: la bola rebota en ellos).
	var body := StaticBody2D.new()
	for side in [-1.0, 1.0]:
		var post := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = u(4)
		post.shape = circle
		post.position = center() + Vector2(side * (u(WIDTH) * 0.5 + u(5)), 0)
		body.add_child(post)
	add_child(body)


func _on_enter(body: Node) -> void:
	if not (body is Ball):
		return
	var v: float = (body as Ball).linear_velocity.length()
	_speed = minf(_speed + v * 0.06, 60.0)
	_glow = 1.0
	event(&"spinner", center())


func _physics_process(delta: float) -> void:
	if _speed <= 0.0:
		return
	_angle += _speed * delta
	_speed = maxf(0.0, _speed - (4.0 + _speed * 0.6) * delta)
	var turns := int(_angle / PI)
	if turns > _half_turns:
		_half_turns = turns
		score(&"spinner", SPIN_POINTS, center())
		Sfx.play("post", 0.4 + minf(_speed / 60.0, 0.6))


func _process(delta: float) -> void:
	_glow = maxf(0.0, _glow - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var c := center()
	var w := u(WIDTH) * 0.5
	for side in [-1.0, 1.0]:
		draw_circle(c + Vector2(side * (w + u(5)), 0), u(4), Color(0.75, 0.8, 1.0))
	var h := absf(cos(_angle)) * u(8) + 1.0
	var face := Color(0.95, 0.9, 0.5) if cos(_angle) > 0.0 else Color(0.6, 0.55, 0.9)
	draw_rect(Rect2(c - Vector2(w, h * 0.5), Vector2(2 * w, h)), face.lerp(Color.WHITE, _glow * 0.6))
	draw_line(c + Vector2(-w, 0), c + Vector2(w, 0), Color(0.3, 0.3, 0.4), 1.0)
