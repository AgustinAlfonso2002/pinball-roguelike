extends Item
## Pasivo de economía: interés sobre las fichas.


func _init() -> void:
	id = &"ahorrista"
	display_name = "Chanchito"
	description = "Al ganar una partida, +1 ficha por cada 5 que tengas (máx. +5)."
	price = 5
	rarity = Rarity.UNCOMMON
	color = Color(1.0, 0.6, 0.75)


func on_game_end(session, won: bool) -> void:
	if won:
		var gain := mini(5, Run.coins / 5)
		if gain > 0:
			Run.add_coins(gain)
			session.extra_rewards.append("Chanchito: +%d" % gain)
