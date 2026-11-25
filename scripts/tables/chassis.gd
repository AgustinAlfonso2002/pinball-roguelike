class_name Chassis
extends RefCounted
## Forma de una mesa. Todas comparten la parte de abajo (flippers,
## slingshots, carriles laterales y lanzador) para que la mano no se
## desentrene; cada chasis cambia la parte de arriba: paredes internas,
## flippers extra y los ENCASTRES donde el generador pone módulos.
##
## Agregar un chasis = agregar un archivo en scripts/tables/chassis/.
## Coordenadas en unidades de diseño (400 x 640); se multiplican por Geom.S.

const SIZES := {"S": Vector2(64, 64), "M": Vector2(140, 60), "L": Vector2(150, 150)}

var id: StringName = &""
var display_name := ""
var weight := 1.0
var min_night := 1
## Encastres: {"pos": centro, "size": "S"/"M"/"L", "tags": [...]}.
## Tags: "low" = cerca de los flippers (solo piezas que no tapan el paso).
var sockets: Array = []
## Salidas del riel guiado: {"pos", "dir"}. La bola sale ahí con esa dirección.
var rail_exits: Array = []


## Paredes, deflectores y flippers propios del chasis.
func build(_table: PinballTable) -> void:
	pass


## Rectángulo del encastre en píxeles de la mesa.
func socket_rect(index: int) -> Rect2:
	var s: Dictionary = sockets[index]
	var size: Vector2 = SIZES[s.size]
	return Rect2((s.pos - size * 0.5) * Geom.S, size * Geom.S)


func socket_size(index: int) -> String:
	return sockets[index].size


func socket_has_tag(index: int, tag: String) -> bool:
	return tag in sockets[index].get("tags", [])
