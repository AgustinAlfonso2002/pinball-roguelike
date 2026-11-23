extends Node
## Parámetros de física ajustables en vivo (autoload "Tuning").
##
## Todos los valores que definen cómo se siente el pinball viven acá.
## El panel de ajuste (Tab) los modifica mientras jugás y se guardan
## automáticamente en user://tuning.cfg para la próxima vez.

signal changed

const SAVE_PATH := "user://tuning.cfg"

## clave: [valor por defecto, mínimo, máximo, paso, etiqueta]
const PARAMS := {
	"gravity": [1100.0, 300.0, 3000.0, 10.0, "Gravedad de la mesa"],
	"ball_bounce": [0.30, 0.0, 1.0, 0.01, "Rebote de la bola"],
	"ball_friction": [0.15, 0.0, 1.0, 0.01, "Fricción de la bola"],
	"wall_bounce": [0.40, 0.0, 1.0, 0.01, "Rebote de las paredes"],
	"flipper_up_speed": [30.0, 5.0, 60.0, 0.5, "Flipper: velocidad de subida (rad/s)"],
	"flipper_down_speed": [14.0, 2.0, 40.0, 0.5, "Flipper: velocidad de bajada (rad/s)"],
	"flipper_bounce": [0.15, 0.0, 1.0, 0.01, "Flipper: rebote"],
	"bumper_kick": [520.0, 0.0, 1500.0, 10.0, "Bumper: fuerza de empuje"],
	"sling_kick": [420.0, 0.0, 1500.0, 10.0, "Slingshot: fuerza de empuje"],
	"plunger_max": [1600.0, 300.0, 3000.0, 10.0, "Lanzador: fuerza máxima"],
	"plunger_charge_time": [0.9, 0.2, 3.0, 0.05, "Lanzador: tiempo de carga (s)"],
	"nudge_force": [140.0, 0.0, 600.0, 5.0, "Sacudón: fuerza"],
	"max_ball_speed": [2600.0, 800.0, 5000.0, 50.0, "Velocidad máxima de la bola"],
}

var values := {}


func _ready() -> void:
	reset_defaults(false)
	_load()


func v(key: String) -> float:
	return float(values.get(key, PARAMS[key][0]))


func set_value(key: String, value: float) -> void:
	values[key] = value
	changed.emit()
	_save()


func reset_defaults(save := true) -> void:
	for key in PARAMS:
		values[key] = float(PARAMS[key][0])
	changed.emit()
	if save:
		_save()


## Devuelve los valores actuales como texto JSON (para copiar y compartir).
func to_json() -> String:
	return JSON.stringify(values, "  ", true)


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("tuning", key, values[key])
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in PARAMS:
		if cfg.has_section_key("tuning", key):
			values[key] = float(cfg.get_value("tuning", key))
	changed.emit()
