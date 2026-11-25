extends Item
## Pasivo raro: una bola más por partida.


func _init() -> void:
	id = &"bola_extra"
	display_name = "Bola extra"
	description = "+1 bola en cada partida y duelo."
	price = 8
	rarity = Rarity.RARE
	color = Color(0.85, 0.88, 0.95)


func modify_stat(stat: StringName, value: float) -> float:
	if stat == &"balls_per_game":
		return value + 1.0
	return value
