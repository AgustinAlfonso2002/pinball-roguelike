class_name RailPlanner
## Planea el recorrido del riel guiado (en unidades de diseño) para que no
## pase por encima de ninguna otra pieza ni se salga de la mesa.
##
## Prueba, en este orden:
##   1. Arco directo: sube desde la boca y baja al carril de un flipper.
##   2. Por las paredes: sube por un costado, cruza la cúpula pegado al borde
##      y baja por el otro costado.
##   3. Corto: va a la pared de su lado y baja a ese carril (si la boca está alta).
## Devuelve los puntos de paso (se suavizan con `curve()`), o [] si no hay forma.

const HALF_WIDTH := 10.0  ## Medio ancho del riel dibujado, en unidades.
const MARGIN := 4.0
const LEFT_X := 16.0
const RIGHT_X := 352.0
const ARC_CENTER := Vector2(200, 100)
const ARC_RADIUS := 200.0
const EDGE_R := 184.0  ## Radio del recorrido pegado al borde de la cúpula.


static func plan(ch: Chassis, mouth_socket: int, blocked: Array[Rect2], rng: RandomNumberGenerator) -> Array:
	var mouth: Vector2 = ch.sockets[mouth_socket].pos
	var grown: Array[Rect2] = []
	for r in blocked:
		grown.append(r.grow(HALF_WIDTH + MARGIN))
	var exits: Array = ch.rail_exits.duplicate()
	# Primero la salida más lejana (viaje más largo).
	exits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a.pos.x - mouth.x) > absf(b.pos.x - mouth.x))

	# 1. Arcos directos con distintas alturas.
	var arcs := []
	for e in exits:
		for top in [mouth.y - 90.0, mouth.y - 140.0, 40.0, -20.0]:
			if top < mouth.y - 60.0:
				arcs.append(_arc(mouth, e, top))
	_shuffle(arcs, rng)
	for pts in arcs:
		if _valid(pts, grown):
			return pts

	# 2. Por las paredes y la cúpula, saliendo por el otro lado.
	var near_left := mouth.x < 184.0
	for side_first in [near_left, not near_left]:
		var pts := _around(mouth, ch.rail_exits, side_first)
		if not pts.is_empty() and _valid(pts, grown):
			return pts

	# 3. Corto: a la pared de su lado y abajo.
	for e in exits:
		var left: bool = e.pos.x < 184.0
		var cx := LEFT_X if left else RIGHT_X
		if mouth.y > e.pos.y - 140.0:
			continue
		var pts := [mouth, mouth + Vector2(0, -26), Vector2(cx, mouth.y - 30), Vector2(cx, e.pos.y - 50), e.pos]
		if _valid(pts, grown):
			return pts
	return []


## Curva suave que pasa por los puntos (Catmull-Rom).
static func curve(points: Array, scale := 1.0) -> Curve2D:
	var c := Curve2D.new()
	var n := points.size()
	for i in n:
		var p: Vector2 = points[i] * scale
		var prev: Vector2 = points[maxi(i - 1, 0)] * scale
		var next: Vector2 = points[mini(i + 1, n - 1)] * scale
		var tangent := (next - prev) / 6.0
		if i == 0:
			tangent = Vector2(0, -absf(next.distance_to(p)) / 3.0)  # sale siempre hacia arriba
		c.add_point(p, -tangent if i > 0 else Vector2.ZERO, tangent if i < n - 1 else Vector2.ZERO)
	c.bake_interval = 2.0
	return c


static func _arc(mouth: Vector2, e: Dictionary, top: float) -> Array:
	var exit: Vector2 = e.pos
	var mid_x := lerpf(mouth.x, exit.x, 0.5)
	var side := signf(exit.x - mouth.x)
	var w := absf(exit.x - mouth.x) * 0.5
	return [
		mouth, mouth + Vector2(0, -26),
		Vector2(mouth.x + side * w * 0.25, lerpf(mouth.y, top, 0.75)),
		Vector2(mid_x, top),
		Vector2(exit.x - side * w * 0.25, lerpf(exit.y - 120.0, top, 0.6)),
		exit - (e.dir as Vector2).normalized() * 60.0, exit,
	]


static func _around(mouth: Vector2, exits: Array, start_left: bool) -> Array:
	var exit: Dictionary = {}
	for e in exits:
		if (e.pos.x < 184.0) != start_left:
			exit = e
	if exit.is_empty():
		return []
	var cx := LEFT_X if start_left else RIGHT_X
	var cx2 := RIGHT_X if start_left else LEFT_X
	var pts := [mouth, mouth + Vector2(0, -26), Vector2(cx, mouth.y - 40)]
	# Por el borde de la cúpula, de un lado al otro.
	var a0 := _edge_angle(cx)
	var a1 := _edge_angle(cx2)
	for k in 9:
		var a := lerpf(a0, a1, k / 8.0)
		pts.append(ARC_CENTER + Vector2(cos(a), sin(a)) * EDGE_R)
	pts.append(Vector2(cx2, exit.pos.y - 70.0))
	pts.append(exit.pos)
	return pts


## Ángulo del punto del borde de la cúpula que está sobre la vertical x.
static func _edge_angle(x: float) -> float:
	var dx := clampf((x - ARC_CENTER.x) / EDGE_R, -1.0, 1.0)
	# Puntos de arriba (y < centro): ángulo entre PI y 2·PI.
	return TAU - acos(dx) if dx >= 0.0 else PI + acos(-dx)


static func _valid(points: Array, grown: Array[Rect2]) -> bool:
	var c := curve(points)
	for p in c.get_baked_points():
		if p.x < 6.0 or p.x > 362.0 or p.y > 440.0:
			return false
		if p.y < ARC_CENTER.y and p.distance_to(ARC_CENTER) > ARC_RADIUS - 8.0:
			return false
		for r in grown:
			if r.has_point(p):
				return false
	return true


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
