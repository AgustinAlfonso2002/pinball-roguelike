class_name TableObjective
extends RefCounted
## Objetivo secundario de una partida. La partida se gana siempre llegando
## al puntaje; los objetivos dan premios extra:
##   COUNT  "Cruzá portales 0/6"            → fichas
##   FEAT   "Completá el banco 0/2"         → +1 al multiplicador por toda la partida
##   COMBO  "Activá 3 piezas distintas en 5 s" → puntos

enum Kind { COUNT, FEAT, COMBO }
enum Reward { COINS, MULT, POINTS }

var kind := Kind.COUNT
var tag: StringName = &""  ## Evento que cuenta (COUNT y FEAT).
var label := ""
var goal := 1
var progress := 0
var window := 5.0  ## Segundos del combo.
var reward := Reward.COINS
var reward_value := 1
var done := false

var _recent: Array = []  # combo: [{module, time}]


## Registra un evento. Devuelve true si con esto se cumplió.
func track(event_tag: StringName, module: Object, time: float) -> bool:
	if done:
		return false
	match kind:
		Kind.COUNT, Kind.FEAT:
			if event_tag != tag:
				return false
			progress += 1
		Kind.COMBO:
			if module == null:
				return false
			_recent = _recent.filter(func(e: Dictionary) -> bool: return time - e.time <= window and e.module != module)
			_recent.append({"module": module, "time": time})
			progress = _recent.size()
	if progress >= goal:
		progress = goal
		done = true
		return true
	return false


func text() -> String:
	if kind == Kind.COMBO:
		return "%s en %d s" % [label, int(window)]
	return "%s %d/%d" % [label, progress, goal]


func reward_text() -> String:
	match reward:
		Reward.COINS:
			return "+%d fichas" % reward_value
		Reward.MULT:
			return "+%d mult. toda la partida" % reward_value
		_:
			return "+%s puntos" % Fmt.score(reward_value)
