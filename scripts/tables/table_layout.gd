class_name TableLayout
extends RefCounted
## Cómo está armada una mesa: qué chasis y qué módulo va en cada encastre.
## La arma TableGenerator a partir de una semilla (la misma semilla da
## siempre la misma mesa).

var seed := 0
var night := 1
var chassis_id: StringName = &"clasica"
## Cada pieza: {"module": id, "sockets": [índices de encastre], "params": {...}}
## params: datos que calcula el generador (por ejemplo, el recorrido del riel).
var placements: Array = []


func add(module_id: StringName, sockets: Array, params := {}) -> void:
	placements.append({"module": module_id, "sockets": sockets, "params": params})


## Rectángulos (en unidades de diseño) ocupados por las piezas, salvo `except`.
func occupied_rects(ch: Chassis, except: Dictionary = {}) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p in placements:
		if p == except:
			continue
		for i in p.sockets:
			out.append(ch.socket_rect_units(i))
	return out


func has_module(module_id: StringName) -> bool:
	for p in placements:
		if p.module == module_id:
			return true
	return false


func used_sockets() -> Array:
	var used := []
	for p in placements:
		used.append_array(p.sockets)
	return used


## Resumen legible (panel F2 y reportes del robot).
func describe() -> String:
	var names := []
	for p in placements:
		var proto := TableParts.module_proto(p.module)
		names.append(proto.display_name if proto else str(p.module))
	var ch := TableParts.chassis(chassis_id)
	return "%s · %s" % [ch.display_name if ch else str(chassis_id), ", ".join(names)]
