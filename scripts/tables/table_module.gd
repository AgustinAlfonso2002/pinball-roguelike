class_name TableModule
extends Node2D
## Pieza de la mesa (bumpers, riel, portales, catapulta...). El generador
## elige qué módulos van en cada mesa y en qué encastre.
##
## Agregar un módulo = agregar un archivo en scripts/tables/modules/ que
## extienda TableModule, complete los datos en _init() y arme sus nodos en
## build(). Ver docs/MESAS.md.

var id: StringName = &""
var display_name := ""
var sizes: Array = ["S"]  ## Tamaños de encastre donde entra.
var sockets_needed := 1  ## Los portales usan 2.
var weight := 1.0  ## Probabilidad relativa de aparecer.
var min_night := 1  ## Desde qué noche puede aparecer.
var core := false  ## Pieza central (bumpers): toda mesa tiene una en el encastre grande.
var allow_low := false  ## Puede ir en encastres "low" (cerca de los flippers).
var only_tags: Array = []  ## Si no está vacío, solo va en encastres con alguno de estos tags.
## Eventos que emite para los objetivos: tag -> {"text": "...", "goal": n, "big": bool}
## "goal" es la meta base de un objetivo de contar; "big" marca hazañas.
var events := {}

var table: PinballTable
var chassis: Chassis
var rects: Array[Rect2] = []  ## Encastres asignados, en píxeles de la mesa.
var params := {}  ## Datos que calculó el generador para esta pieza.
var rng := RandomNumberGenerator.new()


## Crea los nodos de la pieza dentro de sus rects.
func build() -> void:
	pass


## La bola nueva se sirvió (por ejemplo, para soltar piezas trabadas).
func on_ball_served() -> void:
	pass


func center(i := 0) -> Vector2:
	return rects[i].get_center()


## Suma puntos (pasa por los objetos y multiplicadores como cualquier golpe).
func score(source: StringName, base: float, pos: Vector2) -> void:
	table.hit.emit(source, base, pos, self)


## Avisa un evento para los objetivos y combos.
func event(tag: StringName, pos: Vector2) -> void:
	table.module_event.emit(tag, pos, self)


static func u(v: float) -> float:
	return v * Geom.S
