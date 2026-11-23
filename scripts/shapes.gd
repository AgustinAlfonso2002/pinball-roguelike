class_name Shapes
## Utilidades para crear formas de colisión.


## Crea un ConvexPolygonShape2D limpio a partir de una nube de puntos:
## calcula la envolvente convexa y quita el punto repetido del cierre
## (una arista de largo cero confunde a la detección de colisiones).
static func convex(points: PackedVector2Array) -> ConvexPolygonShape2D:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	var shape := ConvexPolygonShape2D.new()
	shape.points = hull
	return shape
