extends Node
## Registro de objetos (autoload "Items").
##
## Al arrancar carga todos los archivos de scripts/items/catalog/.
## Cada archivo es un objeto: agregar un archivo = agregar un objeto.

const CATALOG_DIR := "res://scripts/items/catalog"

var _scripts := {}  # id -> Script
var _protos := {}  # id -> Item (instancia de referencia para leer datos)


func _ready() -> void:
	reload()


func reload() -> void:
	_scripts.clear()
	_protos.clear()
	for script in Catalog.load_scripts(CATALOG_DIR):
		var item = script.new()
		if not (item is Item):
			push_warning("%s no extiende Item; se ignora." % script.resource_path)
			continue
		if item.id == &"":
			push_warning("%s no tiene id; se ignora." % script.resource_path)
			continue
		if _scripts.has(item.id):
			push_warning("Id de objeto repetido: %s" % item.id)
			continue
		_scripts[item.id] = script
		_protos[item.id] = item


func ids() -> Array:
	return _scripts.keys()


func has(id: StringName) -> bool:
	return _scripts.has(id)


func create(id: StringName) -> Item:
	return _scripts[id].new() if _scripts.has(id) else null


func proto(id: StringName) -> Item:
	return _protos.get(id)


## Elige `count` objetos distintos al azar para la tienda, según rareza y peso.
## `exclude` = ids que no deben aparecer (por ejemplo, pasivos que ya tenés).
func random_offer(count: int, rng: RandomNumberGenerator, exclude: Array = []) -> Array[Item]:
	var pool: Array = []
	for id in _protos:
		var p: Item = _protos[id]
		if p.enabled and not exclude.has(id):
			pool.append(p)
	var result: Array[Item] = []
	while result.size() < count and not pool.is_empty():
		var total := 0.0
		for p in pool:
			total += Item.RARITY_WEIGHTS[p.rarity] * p.weight
		var r := rng.randf() * total
		var chosen: Item = pool[pool.size() - 1]
		for p in pool:
			r -= Item.RARITY_WEIGHTS[p.rarity] * p.weight
			if r <= 0.0:
				chosen = p
				break
		pool.erase(chosen)
		result.append(create(chosen.id))
	return result
