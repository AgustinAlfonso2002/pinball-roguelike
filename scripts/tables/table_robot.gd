class_name TableRobot
extends Node
## Robot que juega una mesa solo: lanza la bola, mueve los flippers cuando la
## bola se acerca y anota lo que pasa (cuánto dura cada bola, qué piezas
## toca, si la bola se traba o se escapa de la mesa).
##
## Se usa de dos formas:
##   - Panel F2 → "Robot juega": lo ves jugar la mesa actual.
##   - `godot --headless --path . -- --robot` → prueba muchas mesas generadas
##     a velocidad acelerada y escribe un reporte (ver RobotRunner).

var table: PinballTable
var skill := 0.9  ## Probabilidad de reaccionar a tiempo cuando la bola llega al flipper.
var rng := RandomNumberGenerator.new()

## Resultados.
var balls_lost := 0
var escapes := 0  ## Bolas que salieron de la mesa por un error de física.
var stuck := 0  ## Veces que la bola quedó trabada (se rescató).
var stuck_spots: Array[Vector2] = []
var nudges := 0
var play_time := 0.0  ## Segundos de juego con bola en la mesa.
var events := {}  ## tag -> cantidad
var module_hits := {}  ## id de módulo -> cantidad de eventos

var _charge_goal := -1.0
var _hold := {}  ## Flipper -> segundos que le quedan apretado
var _decided := {}  ## Flipper -> ya decidió en esta pasada
var _slow := 0.0
var _last_pos := Vector2.ZERO


func _ready() -> void:
	table.robot_mode = true
	for f in table.flippers:
		f.robot_driven = true
	table.module_event.connect(_on_event)
	table.ball_lost.connect(_on_lost)


func _exit_tree() -> void:
	if is_instance_valid(table):
		table.robot_mode = false
		table.robot_launch = false
		for f in table.flippers:
			f.robot_driven = false
			f.robot_hold = false


func _on_event(tag: StringName, _pos: Vector2, module: TableModule) -> void:
	events[tag] = events.get(tag, 0) + 1
	if module:
		module_hits[module.id] = module_hits.get(module.id, 0) + 1


func _on_lost() -> void:
	balls_lost += 1
	if _last_pos.y < PinballTable.DRAIN_Y - 30.0:
		escapes += 1
	_charge_goal = -1.0
	_slow = 0.0


func _physics_process(delta: float) -> void:
	var ball := table.ball
	if not ball:
		_slow = 0.0
		for f in table.flippers:
			f.robot_hold = false
		return
	_last_pos = ball.global_position

	# Lanzador: carga hasta una fuerza al azar y suelta.
	if table.ball_in_lane():
		if _charge_goal < 0.0:
			_charge_goal = rng.randf_range(0.55, 1.0)
		table.robot_launch = table.plunger_charge < _charge_goal
		return
	table.robot_launch = false
	_charge_goal = -1.0
	play_time += delta

	# Flippers: si la bola está al alcance y baja, golpear (casi siempre).
	for f in table.flippers:
		var t: float = _hold.get(f, 0.0)
		if t > 0.0:
			_hold[f] = t - delta
			f.robot_hold = true
			continue
		f.robot_hold = false
		if _in_reach(f, ball):
			if not _decided.get(f, false):
				_decided[f] = true
				if rng.randf() < skill:
					_hold[f] = rng.randf_range(0.14, 0.22)
		else:
			_decided[f] = false

	# Bola trabada: primero un sacudón, si sigue, se rescata y se anota.
	if ball.linear_velocity.length() < 12.0:
		_slow += delta
		if _slow > 2.0 and fmod(_slow, 1.0) < delta:
			ball.linear_velocity += Vector2(rng.randf_range(-1.0, 1.0), -1.0) * 140.0
			nudges += 1
		if _slow > 5.0:
			stuck += 1
			stuck_spots.append(ball.global_position)
			_slow = 0.0
			table.spawn_ball(PinballTable.TEST_DROP, Vector2(rng.randf_range(-40, 40), 0))
	else:
		_slow = 0.0


func _in_reach(f: Flipper, ball: Ball) -> bool:
	var rel := ball.global_position - f.global_position
	var reach := Flipper.LENGTH + Ball.RADIUS + 4.0
	if rel.length() > reach or rel.y > Ball.RADIUS * 1.5 or rel.y < -reach * 0.7:
		return false
	var along := rel.x if f.is_left else -rel.x
	return along > -Ball.RADIUS and ball.linear_velocity.y > -120.0


## Resumen de una línea.
func summary() -> String:
	var avg := play_time / maxf(1.0, float(balls_lost))
	return "%.0f s de juego · %d bolas (%.1f s c/u) · trabadas %d · escapes %d · sacudones %d" % [
		play_time, balls_lost, avg, stuck, escapes, nudges]
