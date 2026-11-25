extends Chassis
## La mesa original: abierta, con deflectores a los costados.


func _init() -> void:
	id = &"clasica"
	display_name = "Clásica"
	weight = 1.0
	sockets = [
		{"pos": Vector2(184, 120), "size": "M"},  # 0 arriba
		{"pos": Vector2(185, 250), "size": "L"},  # 1 centro
		{"pos": Vector2(62, 150), "size": "S"},  # 2 izquierda
		{"pos": Vector2(306, 150), "size": "S"},  # 3 derecha
		{"pos": Vector2(184, 362), "size": "S", "tags": ["low"]},  # 4 abajo
	]
	rail_exits = [
		{"pos": Vector2(36, 420), "dir": Vector2(0.15, 1)},
		{"pos": Vector2(332, 420), "dir": Vector2(-0.15, 1)},
	]


func build(table: PinballTable) -> void:
	# Deflectores laterales: evitan que la bola baje pegada a la pared directo al outlane.
	table.add_wall_poly([Vector2(0, 230), Vector2(44, 280), Vector2(0, 300)])
	table.add_wall_poly([Vector2(365, 230), Vector2(321, 280), Vector2(365, 300)])
