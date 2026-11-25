class_name TableFx
extends Node2D
## Efectos simples para las piezas de la mesa (chispas y ondas), dibujados
## con figuras hasta que esté el arte. Se borran solos al terminar.
##   TableFx.burst(mesa, posición, color)   chispas que salen volando
##   TableFx.ring(mesa, posición, color)    onda que se expande

var _sparks: Array = []  # {pos, vel, life, max, color}
var _rings: Array = []  # {pos, r, max_r, life, max, color}


static func burst(parent: Node, pos: Vector2, color: Color, count := 10, speed := 90.0) -> void:
	if not parent.is_inside_tree():
		return
	var fx := TableFx.new()
	fx.z_index = 15
	for i in count:
		var a := randf() * TAU
		var life := randf_range(0.25, 0.55)
		fx._sparks.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.4, 1.0), "life": life, "max": life, "color": color})
	parent.add_child(fx)


static func ring(parent: Node, pos: Vector2, color: Color, max_radius := 24.0, duration := 0.35) -> void:
	if not parent.is_inside_tree():
		return
	var fx := TableFx.new()
	fx.z_index = 15
	fx._rings.append({"pos": pos, "max_r": max_radius, "life": duration, "max": duration, "color": color})
	parent.add_child(fx)


func _process(delta: float) -> void:
	for s in _sparks:
		s.life -= delta
		s.pos += s.vel * delta
		s.vel *= 0.92
	for r in _rings:
		r.life -= delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	_rings = _rings.filter(func(r: Dictionary) -> bool: return r.life > 0.0)
	if _sparks.is_empty() and _rings.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	for s in _sparks:
		var k: float = s.life / s.max
		draw_rect(Rect2(s.pos.floor(), Vector2.ONE * (2.0 if k > 0.5 else 1.0)), Color(s.color, k))
	for r in _rings:
		var k: float = 1.0 - r.life / r.max
		draw_arc(r.pos, 2.0 + r.max_r * k, 0.0, TAU, 32, Color(r.color, 1.0 - k), 1.5)


## Bola "de mentira" que dibujan los módulos mientras tienen la bola real
## (riel, catapulta, vórtice, portales). `height` la levanta del tablero:
## se agranda y deja una sombra.
class HeldBall extends Node2D:
	var color := Color(0.8, 0.83, 0.92)
	var height := 0.0
	var size := 1.0

	func _init() -> void:
		z_index = 12

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		# La posición del nodo es el punto del tablero; la bola se dibuja
		# `height` píxeles más arriba y más grande, con su sombra abajo.
		var r := Ball.RADIUS * size * (1.0 + height / 40.0)
		if height > 0.5:
			draw_circle(Vector2.ZERO, Ball.RADIUS * size * 0.9, Color(0, 0, 0, 0.35))
		var c := Vector2(0, -height)
		draw_circle(c, r, color)
		draw_circle(c + Vector2(-1.2, -1.2) * (r / Ball.RADIUS), 1.3 * r / Ball.RADIUS, Color(1, 1, 1, 0.9))
