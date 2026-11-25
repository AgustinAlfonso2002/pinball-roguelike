extends Rival
## El Patovica: sacude la máquina y te desvía la bola.


func _init() -> void:
	id = &"patovica"
	display_name = "El Patovica"
	color = Color(0.95, 0.45, 0.35)
	intro_line = "Esta máquina es mía, flaco. Si la toco, la toco fuerte."
	taunts = ["¡Uy, se me resbaló la mano!", "¿Temblor? No sé de qué hablás.", "Perdón, perdón..."]
	defeat_line = "Bueno, bueno... la próxima no la toco."
	victory_line = "La máquina me quiere a mí."
	sabotage_name = "Sacudón"
	sabotage_description = "Cada tanto sacude la máquina y te desvía la bola."
	sabotage_interval = 9.0
	duration = 60.0


func sabotage(session) -> void:
	var dir := Vector2(Run.rng.randf_range(-1.0, 1.0), Run.rng.randf_range(-0.6, 0.2)).normalized()
	session.table.shove_ball(dir, session.table.nudge_force() * 2.5)
	session.rival_says(random_taunt(Run.rng))
