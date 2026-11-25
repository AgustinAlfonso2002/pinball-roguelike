class_name RobotRunner
extends Node
## Prueba muchas mesas generadas con el robot, a velocidad acelerada, y
## escribe un reporte: qué mesas traban la bola, cuáles la dejan escapar y
## qué piezas casi nunca se usan.
##
##   godot --headless --path . --fixed-fps 60 -- --robot [mesas] [segundos]
##
## Por defecto 40 mesas de 90 segundos de juego. Con --fixed-fps y sin
## pantalla, Godot simula todo lo rápido que puede la computadora (no se
## acelera el tiempo: eso estira cada paso de física y la bola atraviesa paredes). El reporte se imprime y se
## guarda en user://robot_report.txt (en Windows:
## %APPDATA%\Godot\app_userdata\FICHINLIKE\robot_report.txt).

var world: Node2D
var tables := 40
var seconds := 90.0
var first_seed := 1000

var _lines: PackedStringArray = []
var _module_tables := {}  ## id -> mesas donde apareció
var _module_used := {}  ## id -> mesas donde se activó al menos una vez
var _module_events := {}  ## id -> eventos totales
var _problems := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_physics_steps_per_frame = 64
	_log("ROBOT · %d mesas · %d s de juego cada una" % [tables, int(seconds)])
	_log("")
	for i in tables:
		var seed := first_seed + i
		var night := 1 + i % Run.NIGHTS
		await _test_table(seed, night)
	_log("")
	_log("PIEZAS (mesas donde se activó / mesas donde apareció · eventos por mesa)")
	var ids := _module_tables.keys()
	ids.sort()
	for id in ids:
		var n: int = _module_tables[id]
		var used: int = _module_used.get(id, 0)
		var per: float = float(_module_events.get(id, 0)) / n
		var warn := "   ← casi no se usa" if used < n * 0.5 else ""
		_log("  %-18s %2d / %2d · %.1f%s" % [id, used, n, per, warn])
	_log("")
	_log("RESULTADO: %d mesas con problemas" % _problems)
	var f := FileAccess.open("user://robot_report.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines))
	Engine.time_scale = 1.0
	get_tree().quit(1 if _problems > 0 else 0)


func _test_table(seed: int, night: int) -> void:
	var layout := TableGenerator.generate(seed, night)
	var table := PinballTable.new()
	table.layout = layout
	table.juice_enabled = false
	world.add_child(table)
	var robot := TableRobot.new()
	robot.table = table
	robot.rng.seed = seed
	table.add_child(robot)
	table.ball_lost.connect(table.serve_ball)
	table.serve_ball()
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var bad := robot.stuck > 0 or robot.escapes > 0
	if bad:
		_problems += 1
	_log("%s semilla %d · noche %d · %s" % ["!!" if bad else "ok", seed, night, layout.describe()])
	_log("     %s" % robot.summary())
	for p in robot.stuck_spots:
		_log("     trabada en (%d, %d)" % [roundi(p.x / Geom.S), roundi(p.y / Geom.S)])
	for pl in layout.placements:
		var id: StringName = pl.module
		_module_tables[id] = _module_tables.get(id, 0) + 1
		var n: int = robot.module_hits.get(id, 0)
		_module_events[id] = _module_events.get(id, 0) + n
		if n > 0:
			_module_used[id] = _module_used.get(id, 0) + 1
	table.queue_free()
	await get_tree().physics_frame


func _log(text: String) -> void:
	print(text)
	_lines.append(text)
