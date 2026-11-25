extends Item
## Pasivo: potencia el bonus del banco de dianas (modifica una stat del juego).


func _init() -> void:
	id = &"banco_doble"
	display_name = "Coleccionista"
	description = "El bonus por completar el banco de dianas es ×3."
	price = 5
	rarity = Rarity.UNCOMMON
	color = Color(0.95, 0.6, 0.3)


func modify_stat(stat: StringName, value: float) -> float:
	if stat == &"bank_bonus":
		return value * 3.0
	return value
