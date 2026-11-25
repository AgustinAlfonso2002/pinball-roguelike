extends TableModule
## Tres carriles con luces arriba de todo (como en los pinballs de verdad).
## Pasar por un carril lo enciende; con los tres encendidos: bonus y se
## reinician titilando. Los flippers corren las luces a izquierda o derecha:
## así podés acomodar el carril apagado justo donde va a caer la bola.

const GAP := 30.0  ## Ancho de cada carril (unidades).
const POST_H := 34.0
const LIGHT_POINTS := 100.0
const ALL_POINTS := 1500.0

var _lit := [false, false, false]
var _flash := [0.0, 0.0, 0.0]
var _party := 0.0  ## Festejo al completar (titilan todas).


func _init() -> void:
	id = &"carriles_luz"
	display_name = "Carriles de luz"
	sizes = ["M"]
	only_tags = ["top"]
	weight = 1.2
	events = {
		&"lane": {"text": "Encendé carriles", "goal": 10},
		&"lanes_done": {"text": "Encendé los 3 carriles", "goal": 2, "big": true},
	}


func build() -> void:
	var c := center()
	var body := StaticBody2D.new()
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.4
	body.physics_material_override = mat
	for i in 4:
		var cs := CollisionShape2D.new()
		var cap := CapsuleShape2D.new()
		cap.radius = u(3)
		cap.height = u(POST_H)
		cs.shape = cap
		cs.position = c + Vector2((i - 1.5) * u(GAP), 0)
		body.add_child(cs)
	add_child(body)
	for i in 3:
		var area := Area2D.new()
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(u(GAP) - 6.0, u(10))
		cs.shape = rect
		area.add_child(cs)
		area.position = _lane_pos(i)
		area.body_entered.connect(_on_lane.bind(i))
		add_child(area)
	table.flipper_swung.connect(_on_flipper)


func _lane_pos(i: int) -> Vector2:
	return center() + Vector2((i - 1) * u(GAP), 0)


func _on_lane(body: Node, i: int) -> void:
	if not (body is Ball) or _party > 0.0:
		return
	_flash[i] = 1.0
	if _lit[i]:
		score(&"lane", LIGHT_POINTS * 0.25, _lane_pos(i))
		return
	_lit[i] = true
	Sfx.play("target", 1.3)
	score(&"lane", LIGHT_POINTS, _lane_pos(i))
	event(&"lane", _lane_pos(i))
	if _lit.all(func(v: bool) -> bool: return v):
		_party = 1.6
		Sfx.play("bank_complete", 1.1, 0.0)
		table.hitstop(0.8)
		TableFx.ring(table, center(), Color(1.0, 0.9, 0.4), u(60), 0.45)
		score(&"lanes", ALL_POINTS, center() + Vector2(0, 12))
		event(&"lanes_done", center())


## Los flippers corren las luces (izquierdo hacia la izquierda, derecho hacia la derecha).
func _on_flipper(left: bool, up: bool) -> void:
	if not up or _party > 0.0:
		return
	if left:
		_lit = [_lit[1], _lit[2], _lit[0]]
	else:
		_lit = [_lit[2], _lit[0], _lit[1]]


func _process(delta: float) -> void:
	for i in 3:
		_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)
	if _party > 0.0:
		_party -= delta
		if _party <= 0.0:
			_lit = [false, false, false]
	queue_redraw()


func _draw() -> void:
	var c := center()
	for i in 4:
		var x := c.x + (i - 1.5) * u(GAP)
		draw_line(Vector2(x, c.y - u(POST_H) * 0.5), Vector2(x, c.y + u(POST_H) * 0.5), Color(0.6, 0.65, 0.85), u(6))
		draw_circle(Vector2(x, c.y - u(POST_H) * 0.5), u(3), Color(0.75, 0.8, 1.0))
	for i in 3:
		var p := _lane_pos(i) + Vector2(0, u(POST_H) * 0.5 + 6.0)
		var on: bool = _lit[i]
		if _party > 0.0:
			on = fmod(_party * 8.0, 2.0) > 1.0
		var col := Color(1.0, 0.85, 0.35) if on else Color(0.35, 0.3, 0.2)
		draw_rect(Rect2(p - Vector2(5, 2), Vector2(10, 4)), col.lerp(Color.WHITE, _flash[i]))
		draw_line(_lane_pos(i) + Vector2(-2, -4), _lane_pos(i) + Vector2(0, -6), Color(col, 0.5), 1.0)
		draw_line(_lane_pos(i) + Vector2(2, -4), _lane_pos(i) + Vector2(0, -6), Color(col, 0.5), 1.0)
