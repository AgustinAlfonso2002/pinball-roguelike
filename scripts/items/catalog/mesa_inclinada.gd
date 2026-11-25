extends Item
## Pasivo de física: menos gravedad = bola más lenta y controlable.


func _init() -> void:
	id = &"mesa_inclinada"
	display_name = "Calza en las patas"
	description = "La mesa queda menos inclinada: la bola cae 15% más lento."
	price = 3
	rarity = Rarity.COMMON
	color = Color(0.6, 0.5, 0.35)


func modify_stat(stat: StringName, value: float) -> float:
	if stat == &"gravity":
		return value * 0.85
	return value
