extends Chassis
## Mesa angosta: dos paredes en panza achican el centro. Más rápida y
## directa, pero con menos lugar para salvar la bola.


func _init() -> void:
	id = &"embudo"
	display_name = "Embudo"
	weight = 1.0
	sockets = [
		{"pos": Vector2(184, 112), "size": "M"},  # 0 arriba
		{"pos": Vector2(184, 245), "size": "L"},  # 1 centro
		{"pos": Vector2(74, 96), "size": "S"},  # 2 arriba izquierda
		{"pos": Vector2(294, 96), "size": "S"},  # 3 arriba derecha
		{"pos": Vector2(184, 362), "size": "S", "tags": ["low"]},  # 4 abajo
	]
	rail_exits = [
		{"pos": Vector2(36, 420), "dir": Vector2(0.15, 1)},
		{"pos": Vector2(332, 420), "dir": Vector2(-0.15, 1)},
	]


func build(table: PinballTable) -> void:
	table.add_wall_poly([Vector2(0, 150), Vector2(58, 200), Vector2(58, 300), Vector2(0, 350)])
	table.add_wall_poly([Vector2(365, 150), Vector2(307, 200), Vector2(307, 300), Vector2(365, 350)])
