extends Item
## Consumible automático: salva una bola.


func _init() -> void:
	id = &"salvavidas"
	display_name = "Salvavidas"
	description = "Se activa solo: la próxima bola que se te caiga vuelve al lanzador."
	price = 4
	kind = Kind.CONSUMABLE
	rarity = Rarity.COMMON
	color = Color(1.0, 0.35, 0.3)


func try_save_ball(session) -> bool:
	session.message("¡Salvavidas!")
	return true
