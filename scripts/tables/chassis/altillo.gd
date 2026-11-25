extends Chassis
## Mesa con un tercer flipper en la pared derecha (se mueve con el botón
## derecho): permite tiros a la zona alta.


func _init() -> void:
	id = &"altillo"
	display_name = "Altillo"
	weight = 1.0
	sockets = [
		{"pos": Vector2(130, 145), "size": "L"},  # 0 arriba izquierda
		{"pos": Vector2(282, 112), "size": "S"},  # 1 arriba derecha (blanco del tercer flipper)
		{"pos": Vector2(190, 285), "size": "M"},  # 2 centro
		{"pos": Vector2(92, 335), "size": "S"},  # 3 izquierda baja
		{"pos": Vector2(200, 362), "size": "S", "tags": ["low"]},  # 4 abajo
	]
	rail_exits = [
		{"pos": Vector2(36, 420), "dir": Vector2(0.15, 1)},
		{"pos": Vector2(332, 420), "dir": Vector2(-0.15, 1)},
	]


func build(table: PinballTable) -> void:
	table.add_wall_poly([Vector2(0, 230), Vector2(44, 280), Vector2(0, 300)])
	table.add_flipper(Vector2(338, 262), false)
	# Repisa bajo el flipper: la bola que baja por la derecha cae sobre él.
	table.add_wall_poly([Vector2(365, 250), Vector2(365, 290), Vector2(350, 282)])
