class_name TableGenerator
## Arma las mesas: elige un chasis y llena sus encastres con módulos según
## la semilla y la noche. La misma semilla da siempre la misma mesa.
##
## Reglas:
##   - El encastre grande (L) siempre lleva una pieza central (bumpers).
##   - Si hay un encastre mediano (M), lleva algo que sube el multiplicador
##     (banco de dianas o muro de ladrillos).
##   - Cantidad de piezas según la noche: 4 la primera, hasta llenar la mesa.
##   - Cada módulo aparece una vez como máximo; los portales usan dos encastres.
##   - El riel se dibuja por encima de la mesa: su recorrido se planea para que
##     no pase por arriba de ninguna otra pieza. Si no hay lugar, va otra pieza.

const MULT_SOURCES := [&"banco_dianas", &"ladrillos"]


## La mesa de siempre (prototipo y autoprueba).
static func default_layout() -> TableLayout:
	var l := TableLayout.new()
	l.chassis_id = &"clasica"
	l.add(&"banco_dianas", [0])
	l.add(&"trio_bumpers", [1])
	return l


## `force_chassis` (opcional) obliga a usar un chasis (panel F2).
static func generate(seed: int, night: int, force_chassis: StringName = &"") -> TableLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var l := TableLayout.new()
	l.seed = seed
	l.night = night

	# Chasis.
	var options := []
	for id in TableParts.chassis_ids():
		var c := TableParts.chassis(id)
		if c.min_night <= night:
			options.append([id, c.weight])
	l.chassis_id = _pick(options, rng)
	if force_chassis != &"" and TableParts.chassis(force_chassis):
		l.chassis_id = force_chassis
	var ch := TableParts.chassis(l.chassis_id)

	var wanted := mini(ch.sockets.size(), wanted_pieces(night))
	var count := 0
	var free := range(ch.sockets.size())

	# 1. Pieza central en el encastre grande.
	for i in ch.sockets.size():
		if ch.socket_size(i) == "L":
			var cores := []
			for id in TableParts.module_ids():
				var m := TableParts.module_proto(id)
				if m.core and "L" in m.sizes and m.min_night <= night and not l.has_module(id):
					cores.append([id, m.weight])
			if not cores.is_empty():
				l.add(_pick(cores, rng), [i])
				free.erase(i)
				count += 1

	# 2. Algo que suba el multiplicador en un encastre mediano.
	for i in free.duplicate():
		if ch.socket_size(i) == "M":
			var opts := []
			for id in MULT_SOURCES:
				var m := TableParts.module_proto(id)
				if m and m.min_night <= night:
					opts.append([id, m.weight])
			if not opts.is_empty():
				l.add(_pick(opts, rng), [i])
				free.erase(i)
				count += 1
			break

	# 3. El resto, al azar entre lo que entra.
	_shuffle(free, rng)
	for i in free.duplicate():
		if count >= wanted:
			break
		if not (i in free):
			continue
		var opts := []
		for id in TableParts.module_ids():
			var m := TableParts.module_proto(id)
			if m.core or l.has_module(id) or m.min_night > night:
				continue
			if not (ch.socket_size(i) in m.sizes):
				continue
			if not _fits_tags(ch, i, m):
				continue
			if m.sockets_needed > 1 and _partner(ch, free, i, m) < 0:
				continue
			opts.append([id, m.weight])
		if opts.is_empty():
			continue
		var pick: StringName = _pick(opts, rng)
		var proto := TableParts.module_proto(pick)
		var used := [i]
		if proto.sockets_needed > 1:
			used.append(_partner(ch, free, i, proto))
		for s in used:
			free.erase(s)
		l.add(pick, used)
		count += 1
	_plan_rail(l, ch, rng, night)
	return l


## Cuántas piezas lleva una mesa según la noche (4 la primera, +1 cada tanto).
static func wanted_pieces(night: int) -> int:
	return 3 + ceili(night * 0.75)


static func _fits_tags(ch: Chassis, i: int, m: TableModule) -> bool:
	if ch.socket_has_tag(i, "low") and not m.allow_low:
		return false
	if not m.only_tags.is_empty():
		for t in m.only_tags:
			if ch.socket_has_tag(i, t):
				return true
		return false
	return true


## Planea el recorrido del riel esquivando las demás piezas. Si no hay forma,
## lo cambia por otra pieza chica que entre en ese encastre.
static func _plan_rail(l: TableLayout, ch: Chassis, rng: RandomNumberGenerator, night: int) -> void:
	for p in l.placements:
		if p.module != &"riel":
			continue
		var path := RailPlanner.plan(ch, p.sockets[0], l.occupied_rects(ch, p), rng)
		if not path.is_empty():
			p.params = {"path": path}
			return
		l.placements.erase(p)
		var socket: int = p.sockets[0]
		var opts := []
		for id in TableParts.module_ids():
			var m := TableParts.module_proto(id)
			if id == &"riel" or m.core or l.has_module(id) or m.min_night > night or m.sockets_needed > 1:
				continue
			if ch.socket_size(socket) in m.sizes and _fits_tags(ch, socket, m):
				opts.append([id, m.weight])
		if not opts.is_empty():
			l.add(_pick(opts, rng), [socket])
		return


## Otro encastre libre compatible (para piezas de dos encastres), el más lejano.
static func _partner(ch: Chassis, free: Array, first: int, m: TableModule) -> int:
	var best := -1
	var best_d := 0.0
	for j in free:
		if j == first or not (ch.socket_size(j) in m.sizes):
			continue
		if not _fits_tags(ch, j, m):
			continue
		var d: float = (ch.sockets[j].pos as Vector2).distance_to(ch.sockets[first].pos)
		if d > best_d:
			best = j
			best_d = d
	return best


## Objetivos secundarios de una partida (2, de tipos distintos).
## Se arman con los eventos de las piezas que tiene la mesa.
static func objectives(l: TableLayout, seed: int, night: int, target_score: float) -> Array[TableObjective]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var small := []  # [tag, info]
	var big := []
	var module_count := 0
	for p in l.placements:
		var m := TableParts.module_proto(p.module)
		if not m:
			continue
		module_count += 1
		for tag in m.events:
			var info: Dictionary = m.events[tag]
			if info.get("big", false):
				big.append([tag, info])
			else:
				small.append([tag, info])
	var kinds := [TableObjective.Kind.COUNT, TableObjective.Kind.FEAT, TableObjective.Kind.COMBO]
	_shuffle(kinds, rng)
	var out: Array[TableObjective] = []
	for kind in kinds:
		if out.size() >= 2:
			break
		var o := TableObjective.new()
		o.kind = kind
		match kind:
			TableObjective.Kind.COUNT:
				if small.is_empty():
					continue
				var e: Array = small[rng.randi_range(0, small.size() - 1)]
				o.tag = e[0]
				o.label = e[1].text
				o.goal = maxi(1, roundi(e[1].goal * (1.0 + 0.15 * (night - 1))))
				o.reward = TableObjective.Reward.COINS
				o.reward_value = 2 + night / 3
			TableObjective.Kind.FEAT:
				if big.is_empty():
					continue
				var e: Array = big[rng.randi_range(0, big.size() - 1)]
				o.tag = e[0]
				o.label = e[1].text
				o.goal = e[1].goal + (1 if night >= 4 else 0)
				o.reward = TableObjective.Reward.MULT
				o.reward_value = 1
			TableObjective.Kind.COMBO:
				if module_count < 3:
					continue
				o.label = "Combo: 3 piezas distintas"
				o.goal = 3
				o.window = 5.0
				o.reward = TableObjective.Reward.POINTS
				o.reward_value = roundi(target_score * 0.15 / 10.0) * 10
		out.append(o)
	return out


static func _pick(options: Array, rng: RandomNumberGenerator) -> Variant:
	var total := 0.0
	for o in options:
		total += o[1]
	var r := rng.randf() * total
	for o in options:
		r -= o[1]
		if r <= 0.0:
			return o[0]
	return options[-1][0]


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
