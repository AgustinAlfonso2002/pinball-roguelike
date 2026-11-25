extends Item
## Consumible activo: cámara lenta.


func _init() -> void:
	id = &"camara_lenta"
	display_name = "Cámara lenta"
	description = "Uso único: el juego va a la mitad de velocidad durante 6 segundos."
	price = 3
	kind = Kind.CONSUMABLE
	rarity = Rarity.COMMON
	color = Color(0.5, 0.8, 1.0)


func use(session) -> bool:
	session.table.set_effect_slowmo(0.5, 6.0)
	session.message("¡Cámara lenta!")
	return true
