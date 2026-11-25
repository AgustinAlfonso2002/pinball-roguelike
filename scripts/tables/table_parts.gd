class_name TableParts
## Catálogo de chasis y módulos de mesa (se cargan de sus carpetas).
## Agregar un archivo = agregar una pieza; no hay que registrarlo en otro lado.

const CHASSIS_DIR := "res://scripts/tables/chassis"
const MODULES_DIR := "res://scripts/tables/modules"

static var _chassis := {}  # id -> Chassis
static var _modules := {}  # id -> Script
static var _protos := {}  # id -> TableModule (para leer datos)


static func _load() -> void:
	if not _chassis.is_empty():
		return
	for script in Catalog.load_scripts(CHASSIS_DIR):
		var c = script.new()
		if c is Chassis and c.id != &"":
			_chassis[c.id] = c
	for script in Catalog.load_scripts(MODULES_DIR):
		var m = script.new()
		if m is TableModule and m.id != &"":
			_modules[m.id] = script
			_protos[m.id] = m
		elif m is Node:
			m.free()


static func chassis_ids() -> Array:
	_load()
	var ids := _chassis.keys()
	ids.sort()
	return ids


static func chassis(id: StringName) -> Chassis:
	_load()
	return _chassis.get(id)


static func module_ids() -> Array:
	_load()
	var ids := _modules.keys()
	ids.sort()
	return ids


static func module_proto(id: StringName) -> TableModule:
	_load()
	return _protos.get(id)


static func create_module(id: StringName) -> TableModule:
	_load()
	var script: Script = _modules.get(id)
	return script.new() if script else null


## Libera las instancias de referencia (al cerrar el juego).
static func cleanup() -> void:
	for m in _protos.values():
		if is_instance_valid(m):
			m.free()
	_protos.clear()
	_modules.clear()
	_chassis.clear()
