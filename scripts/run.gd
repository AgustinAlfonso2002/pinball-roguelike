extends Node
## Estado de la run actual (autoload "Run").
##
## Noche, etapa (partida 1, partida 2, duelo), fichas, objetos y rivales.
## También calcula las estadísticas modificadas por los objetos (stat()).

signal changed  ## Cambiaron las fichas o los objetos.

const NIGHTS := 7
const STAGES_PER_NIGHT := 3  # 0 y 1 = partidas, 2 = duelo
const DUEL_STAGE := 2
const PASSIVE_SLOTS := 5
const CONSUMABLE_SLOTS := 2
const START_COINS := 4
const RIVALS_DIR := "res://scripts/rivals/catalog"

## Puntaje objetivo base de la noche 1 para cada etapa.
const BASE_TARGETS := [1500.0, 2500.0, 4000.0]
const TARGET_GROWTH := 1.8  ## Crecimiento por noche (noches 1 a 7).
const ENDLESS_GROWTH := 3.0  ## Crecimiento por noche en el modo infinito.

## Estadísticas del juego que no están en el panel de ajuste (Tuning).
## Los objetos las modifican con Item.modify_stat().
const BASE_STATS := {
	&"balls_per_game": 3.0,
	&"shop_slots": 4.0,
	&"reroll_base_cost": 1.0,
	&"coins_per_ball_left": 1.0,
	&"game_reward": 3.0,
	&"duel_reward": 5.0,
	&"bank_bonus": 2000.0,
	&"price_multiplier": 1.0,
}

var active := false
var night := 1
var stage := 0
var coins := 0
var endless := false
var passives: Array[Item] = []
var ball_item: Item = null
var consumables: Array[Item] = []
var rng := RandomNumberGenerator.new()

var debug_layout: TableLayout = null  ## Mesa forzada desde el panel F2 (solo esta noche).

var _layout_cache: TableLayout = null
var _rival_scripts := {}  # id -> Script
var _rival_order: Array = []


func _ready() -> void:
	for script in Catalog.load_scripts(RIVALS_DIR):
		var r = script.new()
		if r is Rival and r.id != &"":
			_rival_scripts[r.id] = script


func new_run(seed := -1) -> void:
	for item in all_items():
		item.on_remove()
	active = true
	night = 1
	stage = 0
	coins = START_COINS
	endless = false
	passives.clear()
	ball_item = null
	consumables.clear()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	_rival_order.clear()
	for id in _rival_scripts:
		var r: Rival = _rival_scripts[id].new()
		if not r.boss:
			_rival_order.append(id)
	_shuffle(_rival_order)
	changed.emit()


# --- Estadísticas --------------------------------------------------------------

## Valor de una estadística después de aplicar todos los objetos.
func stat(key: StringName) -> float:
	var value: float
	var k := String(key)
	if Tuning.PARAMS.has(k):
		value = Tuning.v(k)
	else:
		value = float(BASE_STATS.get(key, 0.0))
	for item in all_items():
		value = item.modify_stat(key, value)
	return value


func all_items() -> Array[Item]:
	var list: Array[Item] = []
	list.append_array(passives)
	if ball_item:
		list.append(ball_item)
	list.append_array(consumables)
	return list


## Llama un gancho en todos los objetos, en orden: pasivos, bola, consumibles.
func notify(method: StringName, args: Array = []) -> void:
	for item in all_items():
		item.callv(method, args)


## Pregunta a los objetos si alguno salva la bola perdida.
func try_save_ball(session) -> Item:
	for item in all_items():
		if item.try_save_ball(session):
			if item.kind == Item.Kind.CONSUMABLE:
				remove_item(item)
			return item
	return null


# --- Objetos -------------------------------------------------------------------

func price_of(item: Item) -> int:
	return maxi(1, int(round(item.price * stat(&"price_multiplier"))))


## "" si se puede comprar; si no, el motivo.
func cannot_buy_reason(item: Item) -> String:
	if coins < price_of(item):
		return "No te alcanzan las fichas"
	match item.kind:
		Item.Kind.PASSIVE:
			if passives.size() >= PASSIVE_SLOTS:
				return "No hay lugar (máx. %d pasivos)" % PASSIVE_SLOTS
		Item.Kind.CONSUMABLE:
			if consumables.size() >= CONSUMABLE_SLOTS:
				return "No hay lugar (máx. %d consumibles)" % CONSUMABLE_SLOTS
	return ""


func buy(item: Item) -> bool:
	if cannot_buy_reason(item) != "":
		return false
	coins -= price_of(item)
	add_item(item)
	return true


func add_item(item: Item) -> void:
	match item.kind:
		Item.Kind.PASSIVE:
			passives.append(item)
		Item.Kind.BALL:
			if ball_item:
				ball_item.on_remove()
			ball_item = item
		Item.Kind.CONSUMABLE:
			consumables.append(item)
	item.on_acquire()
	changed.emit()


func remove_item(item: Item) -> void:
	if passives.has(item):
		passives.erase(item)
	elif ball_item == item:
		ball_item = null
	elif consumables.has(item):
		consumables.erase(item)
	else:
		return
	item.on_remove()
	changed.emit()


func sell(item: Item) -> void:
	var value := item.sell_value()
	remove_item(item)
	add_coins(value)


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	changed.emit()


## Usa el consumible del espacio `index`. Devuelve un mensaje para mostrar.
func use_consumable(index: int, session) -> String:
	if index >= consumables.size():
		return ""
	var item := consumables[index]
	if item.use(session):
		remove_item(item)
		return item.display_name
	return "%s: se activa solo" % item.display_name


## Ids que no conviene ofrecer en la tienda (ya los tenés).
func owned_unique_ids() -> Array:
	var ids := []
	for item in passives:
		ids.append(item.id)
	if ball_item:
		ids.append(ball_item.id)
	return ids


# --- Noches y etapas ---------------------------------------------------------

func is_duel() -> bool:
	return stage == DUEL_STAGE


func target_for(p_night: int, p_stage: int) -> float:
	var t: float = BASE_TARGETS[p_stage] * pow(TARGET_GROWTH, mini(p_night, NIGHTS) - 1)
	if p_night > NIGHTS:
		t *= pow(ENDLESS_GROWTH, p_night - NIGHTS)
	return _nice(t)


func current_target() -> float:
	return target_for(night, stage)


func stage_title() -> String:
	if is_duel():
		return "Noche %d · DUELO" % night
	return "Noche %d · Partida %d de 2" % [night, stage + 1]


func is_final_night() -> bool:
	return night == NIGHTS and not endless


## Crea el rival de la noche actual (la última noche es el jefe).
func create_rival() -> Rival:
	if night >= NIGHTS:
		for id in _rival_scripts:
			var r: Rival = _rival_scripts[id].new()
			if r.boss:
				return r
	if _rival_order.is_empty():
		return null
	var id = _rival_order[(night - 1) % _rival_order.size()]
	return _rival_scripts[id].new()


func next_night() -> void:
	night += 1
	stage = 0
	debug_layout = null
	changed.emit()


# --- Mesas ------------------------------------------------------------------------

## Semilla de la mesa de la noche actual (sale de la semilla de la run, así
## una partida guardada vuelve a tener la misma mesa).
func table_seed() -> int:
	return hash([rng.seed, night]) & 0x7fffffff


## Mesa de la noche actual: la misma para las dos partidas y el duelo.
func night_layout() -> TableLayout:
	if debug_layout and debug_layout.night == night:
		return debug_layout
	var s := table_seed()
	if _layout_cache == null or _layout_cache.seed != s:
		_layout_cache = TableGenerator.generate(s, night)
	return _layout_cache


# --- Guardado -------------------------------------------------------------------

func to_dict() -> Dictionary:
	var items := []
	for item in all_items():
		items.append({"id": String(item.id), "state": item.save_state()})
	return {
		"version": 1,
		"night": night, "stage": stage, "coins": coins, "endless": endless,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"rival_order": _rival_order.map(func(x): return String(x)),
		"items": items,
	}


## Restaura una run guardada. Los objetos que ya no existen en el catálogo se ignoran.
func from_dict(d: Dictionary) -> void:
	new_run()
	night = int(d.get("night", 1))
	stage = int(d.get("stage", 0))
	coins = int(d.get("coins", START_COINS))
	endless = bool(d.get("endless", false))
	rng.seed = int(d.get("rng_seed", "0"))
	rng.state = int(d.get("rng_state", "0"))
	var order: Array = d.get("rival_order", [])
	if not order.is_empty():
		_rival_order = order.map(func(x): return StringName(x)).filter(func(x): return _rival_scripts.has(x))
	for entry in d.get("items", []):
		var item := Items.create(StringName(entry.get("id", "")))
		if item:
			add_item(item)
			item.load_state(entry.get("state", {}))
	changed.emit()


func _nice(x: float) -> float:
	if x <= 0.0:
		return 0.0
	var mag := pow(10.0, floor(log(x) / log(10.0)) - 1.0)
	return round(x / mag) * mag


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
