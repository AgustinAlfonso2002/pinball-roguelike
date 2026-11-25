extends Item
## Bola: genera fichas con los golpes.


func _init() -> void:
	id = &"bola_dorada"
	display_name = "Bola dorada"
	description = "Cada 20 golpes ganás 1 ficha."
	price = 5
	kind = Kind.BALL
	rarity = Rarity.UNCOMMON
	color = Color(1.0, 0.82, 0.3)

var hits := 0


func configure_ball(ball: Ball) -> void:
	ball.color = Color(1.0, 0.85, 0.35)


func after_hit(session, hit: HitEvent, _points: float) -> void:
	if hit.source == &"post":
		return
	hits += 1
	if hits % 20 == 0:
		Run.add_coins(1)
		session.popup("+1 ficha", hit.position, Color(1.0, 0.85, 0.35))


func get_description() -> String:
	return description + " (%d/20)" % (hits % 20)
