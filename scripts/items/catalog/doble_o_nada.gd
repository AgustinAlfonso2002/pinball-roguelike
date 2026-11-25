extends Item
## Consumible activo: potenciador temporal de puntos.


func _init() -> void:
	id = &"doble_o_nada"
	display_name = "Doble o nada"
	description = "Uso único: todos los puntos ×2 durante 10 segundos."
	price = 4
	kind = Kind.CONSUMABLE
	rarity = Rarity.COMMON
	color = Color(1.0, 0.45, 0.8)


func use(session) -> bool:
	session.add_buff("Doble o nada", 2.0, 10.0)
	return true
