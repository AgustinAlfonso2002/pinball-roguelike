extends Rival
## La Apagona: apaga las luces de media mesa por unos segundos.


func _init() -> void:
	id = &"apagona"
	display_name = "La Apagona"
	color = Color(0.7, 0.5, 1.0)
	intro_line = "¿Jugás bien con luz? A ver sin."
	taunts = ["Ups, se cortó la luz.", "¿Dónde está la bolita?", "A oscuras se juega mejor."]
	defeat_line = "Encima jugás de memoria..."
	victory_line = "Nadie le gana a la oscuridad."
	sabotage_name = "Apagón"
	sabotage_description = "Apaga las luces de media mesa durante 4 segundos."
	sabotage_interval = 10.0
	duration = 60.0


func sabotage(session) -> void:
	var table = session.table
	var w: float = table.TABLE_W
	var top := -60.0
	var h: float = table.DRAIN_Y - top
	var halves := [
		Rect2(0.0, top, w * 0.5, h),  # izquierda
		Rect2(w * 0.5, top, w * 0.5, h),  # derecha
		Rect2(0.0, top, w, h * 0.5),  # arriba
	]
	table.blackout(halves[Run.rng.randi_range(0, halves.size() - 1)], 4.0)
	session.rival_says(random_taunt(Run.rng))
