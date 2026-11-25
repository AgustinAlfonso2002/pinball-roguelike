extends Item
## Pasivo: modifica puntos Y una estadística de física.


func _init() -> void:
	id = &"goma_nueva"
	display_name = "Goma nueva"
	description = "Los slingshots dan ×3 puntos base y patean 20% más fuerte."
	price = 4
	rarity = Rarity.COMMON
	color = Color(0.95, 0.95, 1.0)


func on_hit(_session, hit: HitEvent) -> void:
	if hit.source == &"sling":
		hit.base *= 3.0


func modify_stat(stat: StringName, value: float) -> float:
	if stat == &"sling_kick":
		return value * 1.2
	return value
