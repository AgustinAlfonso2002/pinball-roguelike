class_name Item
extends RefCounted
## Clase base de todos los objetos de la tienda.
##
## Cada objeto es UN archivo en scripts/items/catalog/ que extiende Item.
## Se cargan solos al arrancar el juego: para agregar un objeto se crea un
## archivo nuevo; para quitarlo, se borra el archivo (o se pone enabled = false).
##
## Un objeto define sus datos en _init() y sobrescribe solo los ganchos que
## necesita. Ver docs/OBJETOS.md para la guía completa y ejemplos.

enum Kind {
	PASSIVE,     ## Efecto permanente durante la run (ocupa un espacio de pasivos).
	BALL,        ## Tipo de bola: se equipa una sola (comprar otra la reemplaza).
	CONSUMABLE,  ## Se usa una vez durante una partida (teclas E/Q o Círculo/Cuadrado).
}

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

const KIND_NAMES := ["Pasivo", "Bola", "Consumible"]
const RARITY_NAMES := ["Común", "Poco común", "Raro", "Legendario"]
const RARITY_COLORS := [Color(0.8, 0.82, 0.9), Color(0.45, 0.85, 0.5), Color(0.45, 0.65, 1.0), Color(1.0, 0.7, 0.25)]
const RARITY_WEIGHTS := [1.0, 0.6, 0.3, 0.1]

# --- Datos (se definen en _init de cada objeto) --------------------------------

var id := &""  ## Identificador único, en minúsculas y sin espacios.
var display_name := ""
var description := ""
var price := 4  ## Precio en fichas.
var kind := Kind.PASSIVE
var rarity := Rarity.COMMON
var enabled := true  ## false = no aparece en la tienda.
var weight := 1.0  ## Multiplica la probabilidad de aparecer en la tienda.
var color := Color(0.8, 0.82, 0.9)  ## Color del ícono provisorio.


# --- Ganchos (todos opcionales) ------------------------------------------------

## Modifica una estadística. Se llama cada vez que el juego consulta una
## (ver Run.stat). Ejemplos de stat: &"bumper_kick", &"gravity",
## &"flipper_up_speed", &"balls_per_game", &"bank_bonus", &"price_multiplier".
func modify_stat(_stat: StringName, value: float) -> float:
	return value


## Se compró / se vendió (o se gastó) el objeto.
func on_acquire() -> void:
	pass


func on_remove() -> void:
	pass


## Empieza / termina una partida (o duelo). session: GameSession.
func on_game_start(_session) -> void:
	pass


func on_game_end(_session, _won: bool) -> void:
	pass


## Un golpe que da puntos, ANTES de sumarse: se puede modificar hit.base,
## hit.mult_add y hit.xmult.
func on_hit(_session, _hit: HitEvent) -> void:
	pass


## Un golpe DESPUÉS de sumarse (points = puntos finales que dio).
func after_hit(_session, _hit: HitEvent, _points: float) -> void:
	pass


func on_flipper(_session, _left: bool, _up: bool) -> void:
	pass


func on_ball_launched(_session, _power: float) -> void:
	pass


func on_ball_lost(_session) -> void:
	pass


## Se completó el banco de dianas.
func on_bank_completed(_session) -> void:
	pass


## Cada frame de la partida (delta en segundos de juego).
func on_tick(_session, _delta: float) -> void:
	pass


## Cada vez que aparece una bola nueva (para objetos de tipo BALL: color, etc.).
func configure_ball(_ball: Ball) -> void:
	pass


## Se construyó la mesa de la partida (para objetos que agregan elementos).
func on_table_built(_session, _table) -> void:
	pass


## Se perdió una bola: devolver true para salvarla (no cuenta como perdida).
## Si el objeto es CONSUMIBLE, se gasta al salvarla.
func try_save_ball(_session) -> bool:
	return false


## Consumibles: se usa con E/Q (Círculo/Cuadrado). Devolver true si se gastó.
func use(_session) -> bool:
	return false


# --- Guardado -----------------------------------------------------------------------

const _BASE_VARS := ["id", "display_name", "description", "price", "kind", "rarity", "enabled", "weight", "color"]


## Estado propio del objeto para la partida guardada. Por defecto guarda
## todas las variables simples (números, textos, booleanos) que declare el
## objeto, como los contadores de Racha o Bola dorada. Sobrescribir solo si
## el objeto guarda algo más complejo.
func save_state() -> Dictionary:
	var d := {}
	for p in get_script().get_script_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or _BASE_VARS.has(p.name):
			continue
		var v = get(p.name)
		if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME]:
			d[p.name] = v
	return d


func load_state(d: Dictionary) -> void:
	for k in d:
		if not _BASE_VARS.has(k) and k in self:
			set(k, d[k])


## Descripción que se muestra (puede incluir contadores del objeto).
func get_description() -> String:
	return description


func sell_value() -> int:
	return maxi(1, int(Run.price_of(self) / 2.0))
