extends Item
## Pasivo: suma al multiplicador de todos los golpes.


func _init() -> void:
	id = &"ficha_de_la_suerte"
	display_name = "Ficha de la suerte"
	description = "+1 al multiplicador de todos los golpes."
	price = 6
	rarity = Rarity.UNCOMMON
	color = Color(1.0, 0.85, 0.3)


func on_hit(_session, hit: HitEvent) -> void:
	hit.mult_add += 1.0
