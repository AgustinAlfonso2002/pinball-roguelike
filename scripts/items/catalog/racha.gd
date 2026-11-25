extends Item
## Pasivo con estado propio: cuenta golpes seguidos sin usar los flippers.


func _init() -> void:
	id = &"racha"
	display_name = "Racha"
	description = "Cada golpe seguido sin tocar los flippers suma ×0,1 al siguiente. Se reinicia al usar un flipper."
	price = 7
	rarity = Rarity.RARE
	color = Color(0.4, 0.9, 1.0)

var streak := 0


func on_hit(_session, hit: HitEvent) -> void:
	if hit.source == &"post":
		return
	hit.xmult *= 1.0 + 0.1 * streak
	streak += 1


func on_flipper(_session, _left: bool, up: bool) -> void:
	if up:
		streak = 0


func on_game_start(_session) -> void:
	streak = 0


func get_description() -> String:
	return description + " (Racha actual: %d)" % streak
