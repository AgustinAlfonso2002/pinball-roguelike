extends Item
## Pasivo de física: flippers más rápidos.


func _init() -> void:
	id = &"flippers_aceitados"
	display_name = "Flippers aceitados"
	description = "Los flippers suben 25% más rápido (tiros más fuertes)."
	price = 3
	rarity = Rarity.COMMON
	color = Color(0.55, 0.8, 0.9)


func modify_stat(stat: StringName, value: float) -> float:
	if stat == &"flipper_up_speed":
		return value * 1.25
	return value
