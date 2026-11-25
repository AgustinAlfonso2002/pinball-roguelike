extends Rival
## El Campeón (jefe de la noche 7): alterna las trampas de todos.


func _init() -> void:
	id = &"campeon"
	display_name = "El Campeón"
	color = Color(1.0, 0.8, 0.3)
	intro_line = "Siete noches para llegar hasta acá. Siete segundos para irte."
	taunts = ["¿Eso es todo?", "Soy el dueño de este arcade.", "Mirá y aprendé."]
	defeat_line = "...El arcade tiene un nuevo campeón."
	victory_line = "Volvé cuando sepas jugar."
	sabotage_name = "De todo un poco"
	sabotage_description = "Alterna sacudones, apagones y flippers trabados, cada vez más seguido."
	sabotage_interval = 7.0
	duration = 50.0
	boss = true

var _step := 0


func sabotage(session) -> void:
	var table = session.table
	match _step % 3:
		0:
			var dir := Vector2(Run.rng.randf_range(-1.0, 1.0), Run.rng.randf_range(-0.6, 0.2)).normalized()
			table.shove_ball(dir, table.nudge_force() * 3.0)
		1:
			var w: float = table.TABLE_W
			table.blackout(Rect2(0.0 if Run.rng.randf() < 0.5 else w * 0.5, -60.0, w * 0.5, 460.0), 3.5)
		2:
			table.jam_flipper(Run.rng.randf() < 0.5, 2.0)
	_step += 1
	sabotage_interval = maxf(4.0, sabotage_interval - 0.5)
	session.rival_says(random_taunt(Run.rng))
