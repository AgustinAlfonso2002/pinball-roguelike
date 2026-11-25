extends Rival
## El Tramposo: te traba un flipper con una moneda trucha.


func _init() -> void:
	id = &"tramposo"
	display_name = "El Tramposo"
	color = Color(0.4, 0.85, 0.55)
	intro_line = "Tomá, te regalo una ficha. Es de la suerte... creo."
	taunts = ["¡Esa moneda no es mía!", "Se traba solo, te juro.", "Mala suerte, amigo."]
	defeat_line = "La próxima traigo monedas de verdad."
	victory_line = "En el arcade gana el más vivo."
	sabotage_name = "Moneda trucha"
	sabotage_description = "Te traba un flipper durante 2,5 segundos."
	sabotage_interval = 11.0
	duration = 60.0


func sabotage(session) -> void:
	session.table.jam_flipper(Run.rng.randf() < 0.5, 2.5)
	session.rival_says(random_taunt(Run.rng))
