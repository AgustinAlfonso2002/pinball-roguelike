extends Item
## Bola: cambia el aspecto, la física y los puntos.


func _init() -> void:
	id = &"bola_de_plomo"
	display_name = "Bola de plomo"
	description = "Más pesada: cae 15% más rápido, pero todos los golpes dan ×1,5 puntos."
	price = 6
	kind = Kind.BALL
	rarity = Rarity.UNCOMMON
	color = Color(0.45, 0.47, 0.55)


func configure_ball(ball: Ball) -> void:
	ball.color = Color(0.5, 0.52, 0.6)


func modify_stat(stat: StringName, value: float) -> float:
	if stat == &"gravity":
		return value * 1.15
	return value


func on_hit(_session, hit: HitEvent) -> void:
	hit.xmult *= 1.5
