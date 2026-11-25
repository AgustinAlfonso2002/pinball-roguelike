class_name Rival
extends RefCounted
## Clase base de los rivales del duelo.
##
## Igual que los objetos: un archivo por rival en scripts/rivals/catalog/.
## El rival suma su puntaje a lo largo de `duration` segundos (lo ves subir en
## vivo) y cada `sabotage_interval` segundos te hace una trampa.
## Para ganarle tenés que superar su puntaje final antes de quedarte sin bolas.

var id := &""
var display_name := ""
var color := Color(0.9, 0.4, 0.4)
var intro_line := ""  ## Lo que dice al empezar el duelo.
var taunts: Array[String] = []  ## Frases al azar cuando sabotea.
var defeat_line := ""  ## Lo que dice si le ganás.
var victory_line := ""  ## Lo que dice si te gana.
var sabotage_name := ""
var sabotage_description := ""
var sabotage_interval := 10.0
var duration := 60.0  ## Segundos que tarda en completar su puntaje.
var boss := false  ## El jefe aparece en la última noche.

var _timer := 0.0


func start(_session) -> void:
	_timer = sabotage_interval * 0.6


func tick(session, delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = sabotage_interval
		sabotage(session)


## La trampa del rival. session.table da acceso a la mesa:
## shove_ball(), blackout(), jam_flipper(), etc.
func sabotage(_session) -> void:
	pass


## Progreso de su puntaje (0 a 1) según los segundos transcurridos.
## Avanza en rachas: a veces más rápido, a veces más lento.
func progress(seconds: float) -> float:
	var x := clampf(seconds / duration, 0.0, 1.0)
	return clampf(x - sin(TAU * 3.0 * x) / (TAU * 3.0) * 0.5, 0.0, 1.0)


func random_taunt(rng: RandomNumberGenerator) -> String:
	if taunts.is_empty():
		return ""
	return taunts[rng.randi_range(0, taunts.size() - 1)]
