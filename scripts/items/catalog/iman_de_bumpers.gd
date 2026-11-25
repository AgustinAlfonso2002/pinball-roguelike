extends Item
## Pasivo simple: más puntos base en los bumpers.


func _init() -> void:
	id = &"iman_de_bumpers"
	display_name = "Imán de bumpers"
	description = "Los bumpers dan +50 puntos base."
	price = 4
	rarity = Rarity.COMMON
	color = Color(0.95, 0.4, 0.45)


func on_hit(_session, hit: HitEvent) -> void:
	if hit.source == &"bumper":
		hit.base += 50.0
