extends Node
## Autoprueba sin ventana:
##   godot --headless --path . --fixed-fps 60 -- --selftest
##
## Física: golpes de flipper, bumper, slingshot y lanzador; la bola no atraviesa
## paredes a máxima velocidad; outlanes, inlanes, deflectores y dianas.
## Juego: catálogo de objetos y rivales, puntaje con objetos, estadísticas,
## tienda, partidas y duelos completos.

const S := Geom.S

var main: Node
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


var table: PinballTable:
	get:
		return main.table


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["OK   " if ok else "FALLA", name, detail])
	if not ok:
		_failed += 1


func _run() -> void:
	await _frames(10)
	print("--- Física")
	await _test_respawn()
	await _test_launch()
	await _test_flipper(true)
	await _test_flipper(false)
	await _test_bumper()
	await _test_sling()
	await _test_tunneling()
	await _test_rest_on_flipper()
	await _test_outlanes()
	await _test_deflectors()
	await _test_target_bank()
	await _test_launch_survives()
	await _test_random_play()
	print("--- Juego")
	_test_catalog()
	_test_stats_and_scoring()
	_test_targets_and_shop()
	await _test_session_win_and_loss()
	await _test_duel_and_sabotage()
	await _test_consumables()
	await _test_debug_tools()
	print("--- Mesas generadas")
	_test_generator()
	_test_objectives()
	await _test_session_objectives()
	await _test_modules()
	await _test_robot()
	print("--- Guardado y menús")
	_test_save_load()
	await _test_title_screen()
	await _test_ui_layout()
	print("RESULTADO: %d fallas" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


# --- Física ----------------------------------------------------------------------

func _test_respawn() -> void:
	var ok_count := 0
	for x in [40.0, 184.0, 231.0, 330.0]:
		main.start_sandbox()
		await _frames(5)
		table.spawn_ball(Vector2(x, 685.0) * S, Vector2(0, 300))
		await _frames(int(1.0 * 240))
		if table.ball_in_lane() and table.ball_speed() < 15.0:
			ok_count += 1
	_check("La bola reaparece quieta en el carril del lanzador", ok_count == 4, "%d de 4" % ok_count)


func _test_launch() -> void:
	main.start_sandbox()
	await _frames(20)
	Input.action_press("launch")
	await _frames(int(1.1 * 240))
	Input.action_release("launch")
	var left_lane := false
	var min_y := 9999.0
	for i in int(2.0 * 240):
		await get_tree().physics_frame
		if not table.ball:
			continue
		min_y = minf(min_y, table.ball.global_position.y)
		if table.ball.global_position.x < table.LANE_X - 10.0:
			left_lane = true
	_check("Lanzador saca la bola del carril", left_lane, "altura mínima y=%.0f" % min_y)


func _flipper_ball_pos(left: bool, along: float) -> Vector2:
	var pivot: Vector2 = table.LEFT_PIVOT if left else table.RIGHT_PIVOT
	var ang := deg_to_rad(Flipper.SWING_DEG)
	var d := Vector2(cos(ang), sin(ang)) if left else Vector2(-cos(ang), sin(ang))
	var n := Vector2(d.y, -d.x) if left else Vector2(-d.y, d.x)
	var half := Flipper.BASE_RADIUS - (Flipper.BASE_RADIUS - Flipper.TIP_RADIUS) * (along / Flipper.LENGTH)
	return pivot + d * along + n * (half + Ball.RADIUS + 0.25)


func _test_flipper(left: bool) -> void:
	# La bola cae sobre el flipper en reposo y se golpea justo al tocarlo.
	var action := "flipper_left" if left else "flipper_right"
	for along in [10.0, 17.5, 25.0]:
		main.start_sandbox()
		await _frames(10)
		var contact := _flipper_ball_pos(left, along)
		table.spawn_ball(contact + Vector2(0.0, -20.0))
		var landed := false
		for i in 240:
			await get_tree().physics_frame
			if table.ball.global_position.y >= contact.y - 1.0:
				landed = true
				break
		Input.action_press(action)
		var best := Vector2.ZERO
		for i in int(0.15 * 240):
			await get_tree().physics_frame
			if table.ball and table.ball.linear_velocity.length() > best.length():
				best = table.ball.linear_velocity
		Input.action_release(action)
		var side := "izquierdo" if left else "derecho"
		_check("Flipper %s golpea fuerte (a %.1f px del pivote)" % [side, along],
				landed and best.length() > 350.0 and best.y < 0.0,
				"velocidad %d px/s, dirección %s" % [int(best.length()), str(best.normalized().snapped(Vector2(0.01, 0.01)))])


func _test_bumper() -> void:
	main.start_sandbox()
	await _frames(10)
	var hits := []
	table.hit.connect(func(source, base, _p, _n) -> void: hits.append([source, base]))
	var b: Bumper = table.bumpers[0]
	table.spawn_ball(b.global_position + Vector2(0, 30), Vector2(0, -250))
	var best := 0.0
	for i in int(0.2 * 240):
		await get_tree().physics_frame
		best = maxf(best, table.ball_speed())
	_check("Bumper despide la bola y avisa el golpe", not hits.is_empty() and hits[0][0] == &"bumper" and best >= Run.stat(&"bumper_kick") * 0.8,
			"velocidad %d px/s, golpes %s" % [int(best), str(hits)])


func _test_sling() -> void:
	main.start_sandbox()
	await _frames(10)
	var hits := []
	table.hit.connect(func(source, _b, _p, _n) -> void: hits.append(source))
	var s: Slingshot = table.slings[0]
	var mid := (s.edge_a + s.edge_b) * 0.5
	table.spawn_ball(mid + s.kick_normal * 20.0, -s.kick_normal * 200.0)
	await _frames(int(0.2 * 240))
	_check("Slingshot patea la bola", hits.has(&"sling"), str(hits))


## Busca un punto al azar en la mesa donde la bola no se superponga con nada.
func _free_spot(rng: RandomNumberGenerator) -> Vector2:
	var space := table.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = Ball.RADIUS + 1.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	if table.ball:
		q.exclude = [table.ball.get_rid()]
	while true:
		var p := Vector2(rng.randf_range(60.0, 300.0), rng.randf_range(60.0, 420.0)) * S
		q.transform = Transform2D(0.0, p)
		if space.intersect_shape(q, 1).is_empty():
			return p
	return Vector2.ZERO


func _test_tunneling() -> void:
	var escapes := 0
	var trials := 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	main.start_sandbox()
	await _frames(5)
	for t in trials:
		var dir := Vector2.from_angle(rng.randf_range(0.0, TAU))
		table.spawn_ball(_free_spot(rng), dir * Run.stat(&"max_ball_speed"))
		for i in int(0.6 * 240):
			await get_tree().physics_frame
			if not table.ball:
				break
			var p: Vector2 = table.ball.global_position
			if p.x < -1.0 or p.x > table.TABLE_W + 1.0 or p.y < -51.0:
				escapes += 1
				break
	_check("La bola no atraviesa paredes a velocidad máxima", escapes == 0, "%d escapes en %d disparos" % [escapes, trials])


func _test_rest_on_flipper() -> void:
	main.start_sandbox()
	await _frames(10)
	Input.action_press("flipper_left")
	await _frames(20)
	table.spawn_ball(table.LEFT_PIVOT + Vector2(20, -30))
	await _frames(int(1.5 * 240))
	var still: bool = table.ball != null and table.ball_speed() < 20.0
	var p: Vector2 = table.ball.global_position if table.ball else Vector2.ZERO
	Input.action_release("flipper_left")
	_check("La bola queda atrapada con el flipper levantado", still, "posición %s, velocidad %d px/s" % [str(p.round()), int(table.ball_speed())])


func _test_outlanes() -> void:
	var results := []
	for x in [5.0, table.LANE_X - 5.0]:
		main.start_sandbox()
		await _frames(5)
		var lost := [false]
		table.ball_lost.connect(func() -> void: lost[0] = true)
		table.spawn_ball(Vector2(x, 200.0), Vector2(0, 50))
		await _frames(int(1.5 * 240))
		results.append(lost[0])
	_check("Las bolas que caen por los outlanes se pierden", results == [true, true], str(results))

	var reached := []
	for left in [true, false]:
		main.start_sandbox()
		await _frames(5)
		var x: float = 18.5 if left else table.LANE_X - 18.5
		table.spawn_ball(Vector2(x, 210.0), Vector2(0, 50))
		var f: Flipper = table.flippers[0] if left else table.flippers[1]
		var closest := 9999.0
		for i in int(1.2 * 240):
			await get_tree().physics_frame
			if table.ball:
				closest = minf(closest, table.ball.global_position.distance_to(f.global_position))
		reached.append(closest < 15.0)
	_check("Las bolas que caen por los inlanes llegan al flipper", reached == [true, true], str(reached))


func _test_deflectors() -> void:
	var ok := []
	for left in [true, false]:
		main.start_sandbox()
		await _frames(5)
		var x: float = 4.5 if left else table.LANE_X - 6.0
		table.spawn_ball(Vector2(x, 75.0), Vector2(0, 150))
		var max_inward := 0.0
		for i in int(0.8 * 240):
			await get_tree().physics_frame
			if not table.ball:
				break
			var d: float = table.ball.global_position.x if left else table.LANE_X - table.ball.global_position.x
			max_inward = maxf(max_inward, d)
		ok.append(max_inward > 25.0)
	_check("Los deflectores laterales despegan la bola de la pared", ok == [true, true], str(ok))


func _test_target_bank() -> void:
	main.start_sandbox()
	await _frames(5)
	var sources := []
	table.hit.connect(func(source, _b, _p, _n) -> void: sources.append(source))
	for t in table.targets:
		table.spawn_ball(t.global_position + Vector2(0, 20), Vector2(0, -350))
		await _frames(int(0.25 * 240))
	var all_down := true
	for t in table.targets:
		all_down = all_down and t.is_down
	_check("El banco de dianas se completa y da el bonus", all_down and sources.count(&"target") == 3 and sources.has(&"bank"), str(sources))
	table.serve_ball()
	await _frames(int(2.0 * 240))
	var all_up := true
	for t in table.targets:
		all_up = all_up and not t.is_down
	_check("Las dianas vuelven a subir después del bonus", all_up, "")


func _test_launch_survives() -> void:
	var survived := 0
	var holds := [0.6, 0.75, 0.9, 1.0, 1.2]
	for hold in holds:
		main.start_sandbox()
		await _frames(20)
		var lost := [false]
		table.ball_lost.connect(func() -> void: lost[0] = true)
		Input.action_press("launch")
		await _frames(int(hold * 240))
		Input.action_release("launch")
		await _frames(int(3.0 * 240))
		if not lost[0]:
			survived += 1
	_check("Los lanzamientos no se van directo al drenaje", survived >= 4, "%d de %d sobreviven 3 s" % [survived, holds.size()])


func _test_random_play() -> void:
	main.start_sandbox()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var escapes := 0
	var hits := [0]
	table.hit.connect(func(_s, _b, _p, _n) -> void: hits[0] += 1)
	for i in int(40.0 * 240):
		if i % 30 == 0:
			for a in ["flipper_left", "flipper_right"]:
				if rng.randf() < 0.5:
					Input.action_press(a)
				else:
					Input.action_release(a)
		if table.ball_in_lane():
			if i % 400 < 250:
				Input.action_press("launch")
			else:
				Input.action_release("launch")
		await get_tree().physics_frame
		if table.ball:
			var p: Vector2 = table.ball.global_position
			if p.x < -1.0 or p.x > table.TABLE_W + 1.0 or p.y < -51.0:
				escapes += 1
	for a in ["flipper_left", "flipper_right", "launch"]:
		Input.action_release(a)
	_check("Partida al azar de 40 s sin escapes y con golpes", escapes == 0 and hits[0] > 10, "%d golpes, %d escapes" % [hits[0], escapes])


# --- Juego ---------------------------------------------------------------------------

func _test_catalog() -> void:
	var ids := Items.ids()
	var problems := []
	for id in ids:
		var it := Items.create(id)
		if it.display_name == "" or it.description == "" or it.price <= 0:
			problems.append(id)
	_check("Catálogo de objetos cargado desde la carpeta", ids.size() >= 10 and problems.is_empty(), "%d objetos, con problemas: %s" % [ids.size(), str(problems)])
	Run.new_run(1)
	var r1 := Run.create_rival()
	Run.night = Run.NIGHTS
	var boss := Run.create_rival()
	_check("Rivales cargados (y jefe en la última noche)", r1 != null and boss != null and boss.boss, "%s / %s" % [r1.display_name if r1 else "-", boss.display_name if boss else "-"])


func _test_stats_and_scoring() -> void:
	Run.new_run(1)
	var base_speed := Run.stat(&"flipper_up_speed")
	Run.add_item(Items.create(&"flippers_aceitados"))
	var fast := Run.stat(&"flipper_up_speed")
	_check("Los objetos modifican estadísticas", is_equal_approx(fast, base_speed * 1.25), "%.2f -> %.2f" % [base_speed, fast])

	Run.new_run(1)
	var evt := HitEvent.new(&"bumper", 100.0, Vector2.ZERO)
	Run.notify(&"on_hit", [null, evt])
	var plain := evt.total(1.0)
	Run.add_item(Items.create(&"iman_de_bumpers"))  # +50 base
	Run.add_item(Items.create(&"ficha_de_la_suerte"))  # +1 mult
	Run.add_item(Items.create(&"bola_de_plomo"))  # ×1,5
	evt = HitEvent.new(&"bumper", 100.0, Vector2.ZERO)
	Run.notify(&"on_hit", [null, evt])
	var boosted := evt.total(2.0)  # multiplicador de bola ×2
	# (100 + 50) × (2 + 1) × 1,5 = 675
	_check("Puntaje = base × (multiplicador + suma) × xmult", is_equal_approx(plain, 100.0) and is_equal_approx(boosted, 675.0), "%s y %s" % [plain, boosted])
	_check("Formato de números grandes", Fmt.score(1234567.0) == "1,2 M" and Fmt.score(12345.0) == "12.345" and Fmt.score(3.2e15) == "3,20e15",
			"%s · %s · %s" % [Fmt.score(1234567.0), Fmt.score(12345.0), Fmt.score(3.2e15)])


func _test_targets_and_shop() -> void:
	Run.new_run(1)
	var ok := true
	for n in range(1, 10):
		for st in 3:
			if st > 0:
				ok = ok and Run.target_for(n, st) > Run.target_for(n, st - 1)
			if n > 1:
				ok = ok and Run.target_for(n, st) > Run.target_for(n - 1, st)
	_check("Los objetivos crecen con cada etapa y noche", ok, "noche 1: %s / %s / %s · noche 7 duelo: %s · noche 9 duelo: %s" % [
		Fmt.score(Run.target_for(1, 0)), Fmt.score(Run.target_for(1, 1)), Fmt.score(Run.target_for(1, 2)),
		Fmt.score(Run.target_for(7, 2)), Fmt.score(Run.target_for(9, 2))])

	var offer := Items.random_offer(4, Run.rng, [])
	var ids := {}
	for it in offer:
		ids[it.id] = true
	_check("La tienda ofrece objetos distintos", offer.size() == 4 and ids.size() == 4, str(ids.keys()))

	Run.coins = 100
	var bought := 0
	for id in Items.ids():
		var it := Items.create(id)
		if it.kind == Item.Kind.PASSIVE and Run.buy(it):
			bought += 1
	_check("Máximo de pasivos respetado", Run.passives.size() == Run.PASSIVE_SLOTS, "%d comprados" % bought)
	var coins_before := Run.coins
	var sold := Run.passives[0]
	var value := sold.sell_value()
	Run.sell(sold)
	_check("Vender devuelve fichas y libera el lugar", Run.coins == coins_before + value and Run.passives.size() == Run.PASSIVE_SLOTS - 1, "+%d" % value)


func _new_session(duel: bool, target: float, rival: Rival = null) -> GameSession:
	main.stop_sandbox()
	var s := GameSession.new()
	s.setup(main.world, duel, target, rival)
	main.add_child(s)
	s.table.juice_enabled = false
	return s


func _test_session_win_and_loss() -> void:
	Run.new_run(1)
	Run.add_item(Items.create(&"bola_extra"))
	var s := _new_session(false, 300.0)
	await _frames(5)
	_check("Bola extra: +1 bola por partida", s.balls_total == 4, "%d bolas" % s.balls_total)
	var result := [null]
	s.finished.connect(func(won: bool) -> void: result[0] = won)
	for i in 3:
		s.table.hit.emit(&"bumper", 100.0, Vector2(100, 100), null)
	await _frames(30)
	var still_playing: bool = result[0] == null and s.target_reached and not s.done and s.table.flippers[0].enabled
	s.table.hit.emit(&"bumper", 100.0, Vector2(100, 100), null)  # sigue sumando
	s.table.ball_lost.emit()
	await get_tree().create_timer(2.0, true, false, true).timeout
	_check("Al llegar al objetivo se sigue jugando hasta perder la bola", still_playing and result[0] == true and s.score >= 400.0,
			"puntaje %s" % s.score)
	_check("Las bolas sin usar quedan para el bonus", s.balls_left == s.balls_total - 1, "%d de %d sin usar" % [s.balls_left, s.balls_total])
	s.queue_free()
	await _frames(5)

	Run.new_run(1)
	s = _new_session(false, 1e9)
	await _frames(5)
	result = [null]
	s.finished.connect(func(won: bool) -> void: result[0] = won)
	for i in 3:
		s.table.ball_lost.emit()
		await _frames(2)
	await get_tree().create_timer(2.0, true, false, true).timeout
	_check("La partida se pierde al quedarse sin bolas", result[0] == false and s.balls_left == 0, "bolas %d" % s.balls_left)
	s.queue_free()
	await _frames(5)

	Run.new_run(1)
	s = _new_session(false, 1e9)
	await _frames(5)
	s.table.bank_completed.emit()
	s.table.bank_completed.emit()
	var mult_ok := is_equal_approx(s.multiplier, 3.0)
	s.table.ball_lost.emit()
	await _frames(2)
	_check("Banco completo sube el multiplicador; perder la bola lo reinicia", mult_ok and is_equal_approx(s.multiplier, 1.0), "")
	s.queue_free()
	await _frames(5)


func _test_duel_and_sabotage() -> void:
	Run.new_run(3)
	var all_ok := true
	var names := []
	for id in ["patovica", "apagona", "tramposo", "campeon"]:
		var script: Script = load("res://scripts/rivals/catalog/%s.gd" % id)
		var rival: Rival = script.new()
		var s := _new_session(true, 5000.0, rival)
		await _frames(5)
		# Avanzar el tiempo del rival y forzar sabotajes.
		rival.tick(s, rival.sabotage_interval + 0.1)
		rival.tick(s, rival.sabotage_interval + 0.1)
		s.elapsed = rival.duration * 0.5
		await _frames(2)
		var mid_ok := s.rival_score > 0.0 and s.rival_score < 5000.0
		var jammed: bool = s.table.flippers[0].jammed or s.table.flippers[1].jammed
		var dark: bool = not s.table._blackouts.is_empty()
		names.append("%s (%s%s)" % [rival.display_name, "trabó flipper " if jammed else "", "apagón" if dark else ""])
		all_ok = all_ok and mid_ok
		s.queue_free()
		await _frames(5)
	_check("Duelos: el rival suma en vivo y sabotea sin errores", all_ok, ", ".join(names))

	# Después de superarlo, el rival sigue saboteando hasta que pierdas la bola.
	var tramposo: Rival = load("res://scripts/rivals/catalog/tramposo.gd").new()
	var d := _new_session(true, 300.0, tramposo)
	await _frames(5)
	for i in 4:
		d.table.hit.emit(&"bumper", 100.0, Vector2(100, 100), null)
	for f in d.table.flippers:
		f.jammed = false
	d._process(tramposo.sabotage_interval + 0.1)
	var sabotaged: bool = d.target_reached and not d.done and (d.table.flippers[0].jammed or d.table.flippers[1].jammed)
	var result := [null]
	d.finished.connect(func(won: bool) -> void: result[0] = won)
	d.table.ball_lost.emit()
	await get_tree().create_timer(2.0, true, false, true).timeout
	_check("Duelo ganado: el rival sigue saboteando y hay bonus por bolas sin usar",
			sabotaged and result[0] == true and d.balls_left == d.balls_total - 1, "bolas sin usar %d" % d.balls_left)
	d.queue_free()
	await _frames(5)
	main.start_sandbox()


func _test_consumables() -> void:
	Run.new_run(1)
	Run.add_item(Items.create(&"salvavidas"))
	Run.add_item(Items.create(&"doble_o_nada"))
	var s := _new_session(false, 1e9)
	await _frames(5)
	s.table.ball_lost.emit()
	await _frames(2)
	_check("Salvavidas salva la bola y se gasta", s.balls_left == s.balls_total and Run.consumables.size() == 1, "bolas %d/%d, consumibles %d" % [s.balls_left, s.balls_total, Run.consumables.size()])
	Input.action_press("use_item_1")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("use_item_1")
	var before := s.score
	s.table.hit.emit(&"sling", 10.0, Vector2(100, 100), null)
	_check("Doble o nada: puntos ×2 y se gasta", is_equal_approx(s.score - before, 20.0) and Run.consumables.is_empty(), "+%s" % (s.score - before))
	s.queue_free()
	await _frames(5)
	main.start_sandbox()


func _test_debug_tools() -> void:
	Run.new_run(1)
	GameSession.debug_infinite_balls = true
	var s := _new_session(false, 1e9)
	await _frames(5)
	for i in 5:
		s.debug_lose_ball()
		await _frames(2)
	var kept := s.balls_left == s.balls_total and not s.done
	GameSession.debug_infinite_balls = false
	var result := [null]
	s.finished.connect(func(won: bool) -> void: result[0] = won)
	s.debug_win()
	await get_tree().create_timer(2.0, true, false, true).timeout
	_check("Depuración: bolas infinitas y ganar al instante", kept and result[0] == true, "bolas %d/%d" % [s.balls_left, s.balls_total])
	s.queue_free()
	await _frames(5)
	main.start_sandbox()


func _test_save_load() -> void:
	SaveGame.delete()
	Run.new_run(5)
	Run.night = 3
	Run.stage = 1
	Run.coins = 17
	var racha := Items.create(&"racha")
	Run.add_item(racha)
	racha.streak = 6
	Run.add_item(Items.create(&"bola_dorada"))
	Run.ball_item.hits = 13
	Run.add_item(Items.create(&"salvavidas"))
	SaveGame.save("stage")
	var summary := SaveGame.summary()
	var rival_before := Run.create_rival().display_name
	# Romper el estado y cargar.
	Run.new_run(99)
	var phase := SaveGame.load_run()
	var r: Item = null
	for it in Run.passives:
		if it.id == &"racha":
			r = it
	var ok: bool = phase == "stage" and Run.night == 3 and Run.stage == 1 and Run.coins == 17 \
			and r != null and r.streak == 6 and Run.ball_item != null and Run.ball_item.hits == 13 \
			and Run.consumables.size() == 1 and Run.create_rival().display_name == rival_before
	_check("Guardar y cargar la run (con estado de objetos)", ok, "%s · fase %s" % [summary, phase])
	SaveGame.save("shop")
	_check("Resumen del menú para la tienda", SaveGame.summary().begins_with("Tienda (noche 3)"), SaveGame.summary())
	SaveGame.delete()
	_check("Borrar la partida guardada", not SaveGame.exists(), "")


func _test_title_screen() -> void:
	main.stop_sandbox()
	var title := TitleScreen.new()
	main.ui.add_child(title)
	await get_tree().create_timer(2.0).timeout
	var buttons := title._buttons
	var cont_disabled: bool = buttons[1].disabled
	var focused: Control = main.ui.get_viewport().gui_get_focus_owner()
	var got := [""]
	title.chosen.connect(func(a: String) -> void: got[0] = a)
	# Se aprieta Cruz de verdad (botón A del joystick), no la acción simulada.
	for p in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = JOY_BUTTON_A
		ev.pressed = p
		Input.parse_input_event(ev)
		await _frames(3)
	await get_tree().create_timer(0.6).timeout
	_check("Menú de inicio: sin partida, Continuar deshabilitado; foco en Nueva partida; Cruz elige",
			cont_disabled and focused == buttons[0] and got[0] == "new", "elegido: %s" % got[0])
	title.queue_free()
	await _frames(5)
	main.start_sandbox()


## Tamaños de fuente en la grilla de cada fuente y fondos de pantalla completa.
func _test_ui_layout() -> void:
	# Grillas (unidades por em / unidades por pixel): ver game_fonts.gd.
	var grids := {"Jersey15-Regular.ttf": 27.0, "Jersey10-Regular.ttf": 1400.0 / 75.0, "Micro5-Regular.ttf": 11.0}
	var bad := []
	for size in [GameFonts.BODY_SIZE, GameFonts.TITLE_SIZE, GameFonts.HUGE_SIZE, GameFonts.SMALL_SIZE, GameFonts.WORLD_BIG]:
		var f := GameFonts.for_size(size)
		var grid: float = grids[_font_name(f)]
		var k: float = size / grid
		if absf(k - roundf(k)) > 0.001:
			bad.append(size)
	_check("Fuentes: todos los tamaños caen en la grilla de su fuente", bad.is_empty(), "fuera de grilla: %s" % [bad])
	main.stop_sandbox()
	var p := PauseMenu.new()
	main.ui.add_child(p)
	await _frames(2)
	var dim: Control = p.get_child(0)
	_check("Pausa: el oscurecido cubre toda la pantalla", dim.size == UiTheme.SCREEN, "tamaño %s" % dim.size)
	p.queue_free()
	await _frames(2)
	main.start_sandbox()


func _font_name(f: FontFile) -> String:
	for n in ["Jersey15-Regular.ttf", "Jersey10-Regular.ttf", "Micro5-Regular.ttf"]:
		if GameFonts._load(n) == f:
			return n
	return ""


# --- Mesas generadas -------------------------------------------------------------

func _test_generator() -> void:
	var a := TableGenerator.generate(4242, 3)
	var b := TableGenerator.generate(4242, 3)
	_check("Generador: la misma semilla arma la misma mesa", a.describe() == b.describe() and str(a.placements) == str(b.placements), a.describe())
	var problems := []
	var seen_modules := {}
	var seen_chassis := {}
	for i in 300:
		var night := 1 + i % 7
		var l := TableGenerator.generate(i * 7919 + 13, night)
		var ch := TableParts.chassis(l.chassis_id)
		seen_chassis[l.chassis_id] = true
		var used := {}
		var has_core := false
		for p in l.placements:
			var m := TableParts.module_proto(p.module)
			seen_modules[p.module] = true
			if m.core:
				has_core = true
			if p.sockets.size() != m.sockets_needed:
				problems.append("%s usa %d encastres" % [p.module, p.sockets.size()])
			for sk in p.sockets:
				if used.has(sk):
					problems.append("encastre %d repetido" % sk)
				used[sk] = true
				if not (ch.socket_size(sk) in m.sizes):
					problems.append("%s no entra en %s" % [p.module, ch.socket_size(sk)])
				if ch.socket_has_tag(sk, "low") and not m.allow_low:
					problems.append("%s en encastre bajo" % p.module)
		var ids := l.placements.map(func(p: Dictionary) -> StringName: return p.module)
		for id in ids:
			if ids.count(id) > 1:
				problems.append("%s repetido" % id)
		if not has_core:
			problems.append("mesa sin bumpers (%s)" % l.describe())
		var expected := mini(ch.sockets.size(), 2 + ceili(night / 2.0))
		if l.placements.size() < mini(3, expected) or l.placements.size() > expected:
			problems.append("noche %d con %d piezas" % [night, l.placements.size()])
	_check("Generador: 300 mesas respetan las reglas", problems.is_empty(), "%d problemas %s" % [problems.size(), problems.slice(0, 3)])
	_check("Generador: aparecen todos los chasis y módulos",
			seen_chassis.size() == TableParts.chassis_ids().size() and seen_modules.size() == TableParts.module_ids().size(),
			"%d chasis, %d módulos" % [seen_chassis.size(), seen_modules.size()])


func _test_objectives() -> void:
	var l := TableGenerator.generate(777, 4)
	var objs := TableGenerator.objectives(l, 1, 4, 10000.0)
	_check("Objetivos: dos por partida, de tipos distintos", objs.size() == 2 and objs[0].kind != objs[1].kind, str(objs.map(func(o: TableObjective) -> String: return o.text())))
	var c := TableObjective.new()
	c.kind = TableObjective.Kind.COMBO
	c.goal = 3
	c.window = 5.0
	var m1 := Node.new()
	var m2 := Node.new()
	var m3 := Node.new()
	var step1 := c.track(&"x", m1, 0.0) or c.track(&"x", m1, 1.0) or c.track(&"x", m2, 2.0)
	var late := c.track(&"x", m3, 9.0)  # m1 y m2 ya vencieron
	var done := c.track(&"x", m1, 10.0) or c.track(&"x", m2, 11.0)
	_check("Objetivos: el combo cuenta piezas distintas dentro del tiempo", not step1 and not late and done, "progreso %d" % c.progress)
	for n in [m1, m2, m3]:
		n.free()


func _test_session_objectives() -> void:
	Run.new_run(3)
	var s := _new_session(false, 1e9)
	await _frames(3)
	var coins := Run.coins
	var count := TableObjective.new()
	count.kind = TableObjective.Kind.COUNT
	count.tag = &"portal"
	count.goal = 2
	count.reward = TableObjective.Reward.COINS
	count.reward_value = 3
	var feat := TableObjective.new()
	feat.kind = TableObjective.Kind.FEAT
	feat.tag = &"rail"
	feat.goal = 1
	feat.reward = TableObjective.Reward.MULT
	feat.reward_value = 1
	s.objectives = [count, feat]
	for i in 2:
		s.table.module_event.emit(&"portal", Vector2(100, 100), null)
	s.table.module_event.emit(&"rail", Vector2(100, 100), null)
	var before := s.score
	s.table.hit.emit(&"bumper", 100.0, Vector2(100, 100), null)
	_check("Objetivos en la partida: dan fichas y multiplicador para toda la partida",
			Run.coins == coins + 3 and s.bonus_mult == 1.0 and s.score - before == 200.0 and count.done and feat.done,
			"fichas +%d, mult +%s, golpe %s" % [Run.coins - coins, s.bonus_mult, s.score - before])
	s.queue_free()
	await _frames(5)


func _wait_for(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func u(v: float) -> float:
	return v * S


## Mesa de prueba con piezas elegidas a mano.
func _custom_table(chassis_id: StringName, placements: Array) -> PinballTable:
	main.stop_sandbox()
	var l := TableLayout.new()
	l.chassis_id = chassis_id
	for p in placements:
		l.add(p[0], p[1])
	var t := PinballTable.new()
	t.layout = l
	t.juice_enabled = false
	main.world.add_child(t)
	main.table = t
	return t


func _module_of(t: PinballTable, id: StringName) -> TableModule:
	for m in t.modules:
		if m.id == id:
			return m
	return null


func _test_modules() -> void:
	var events := []
	# Portales: entra por uno y sale por el otro.
	var t := _custom_table(&"clasica", [[&"trio_bumpers", [1]], [&"portales", [2, 3]]])
	t.module_event.connect(func(tag: StringName, _p: Vector2, _m: TableModule) -> void: events.append(tag))
	await _frames(2)
	var pm := _module_of(t, &"portales")
	t.spawn_ball(pm.center(0) + Vector2(0, 14), Vector2(0, -200))
	await _frames(70)
	var near_b := t.ball != null and t.ball.global_position.distance_to(pm.center(1)) < 40.0
	_check("Portales: la bola sale por el otro portal", &"portal" in events and near_b,
			"eventos %s, bola en %s" % [events, t.ball.global_position if t.ball else "?"])

	# Vórtice: chupa la bola y la escupe hacia arriba.
	events.clear()
	t = _custom_table(&"clasica", [[&"trio_bumpers", [1]], [&"vortice", [4]]])
	t.module_event.connect(func(tag: StringName, _p: Vector2, _m: TableModule) -> void: events.append(tag))
	await _frames(2)
	var vm := _module_of(t, &"vortice")
	t.spawn_ball(vm.center() + Vector2(0, -20), Vector2(0, 120))
	await _wait_for(func() -> bool: return &"vortex" in events, 900)
	await _frames(1)
	var went_up := t.ball != null and t.ball.linear_velocity.y < -300.0
	_check("Vórtice: atrapa la bola y la escupe hacia arriba", &"vortex" in events and went_up, "eventos %s" % [events])

	# Catapulta: la bola vuela y aterriza lejos.
	events.clear()
	t = _custom_table(&"clasica", [[&"trio_bumpers", [1]], [&"banco_dianas", [0]], [&"catapulta", [2]]])
	t.module_event.connect(func(tag: StringName, _p: Vector2, _m: TableModule) -> void: events.append(tag))
	await _frames(2)
	var cm := _module_of(t, &"catapulta")
	t.spawn_ball(cm.center() + Vector2(0, -16), Vector2(0, 80))
	await _frames(120)
	var flying := t.ball == null and t.ball_held
	await _wait_for(func() -> bool: return t.ball != null, 900)
	var landed := t.ball != null and t.ball.global_position.distance_to(cm.center()) > 30.0
	_check("Catapulta: la bola vuela (sin física) y aterriza lejos", &"catapult" in events and flying and landed,
			"en vuelo %s, aterrizó %s" % [flying, landed])

	# Riel: la bola entra yendo hacia arriba y sale por un carril de arriba de los flippers.
	events.clear()
	t = _custom_table(&"clasica", [[&"trio_bumpers", [1]], [&"riel", [4]]])
	t.module_event.connect(func(tag: StringName, _p: Vector2, _m: TableModule) -> void: events.append(tag))
	await _frames(2)
	var rm := _module_of(t, &"riel")
	var exit_pos := [Vector2.ZERO]
	t.module_event.connect(func(tag: StringName, p: Vector2, _m: TableModule) -> void:
		if tag == &"rail":
			exit_pos[0] = p)
	t.spawn_ball(rm.center() + Vector2(0, 14), Vector2(0, -300))
	await _wait_for(func() -> bool: return &"rail" in events, 1500)
	var in_inlane: bool = exit_pos[0].y > rm.center().y and (exit_pos[0].x < u(60) or exit_pos[0].x > u(310))
	_check("Riel: lleva la bola y la deja en un carril de los flippers", &"rail" in events and in_inlane,
			"eventos %s" % [events])

	# Ladrillos: romper todo el muro = bonus y +1 multiplicador.
	events.clear()
	t = _custom_table(&"clasica", [[&"trio_bumpers", [1]], [&"ladrillos", [0]]])
	var banks := [0]
	t.bank_completed.connect(func() -> void: banks[0] += 1)
	t.module_event.connect(func(tag: StringName, _p: Vector2, _m: TableModule) -> void: events.append(tag))
	await _frames(2)
	for n in t.get_children():
		if n.has_method("shock"):
			n.shock()
	await _frames(2)
	_check("Ladrillos: romper el muro entero cuenta como banco completo", &"wall" in events and banks[0] == 1 and events.count(&"brick") == 8,
			"%d ladrillos, %d bancos" % [events.count(&"brick"), banks[0]])

	# Bumpers en órbita: se mueven.
	t = _custom_table(&"clasica", [[&"bumpers_orbita", [1]]])
	await _frames(2)
	var p0 := t.bumpers[0].position
	await _frames(60)
	_check("Bumpers en órbita: giran", t.bumpers[0].position.distance_to(p0) > 2.0, "se movió %.1f px" % t.bumpers[0].position.distance_to(p0))

	# Altillo: tercer flipper con el botón derecho.
	t = _custom_table(&"altillo", [[&"trio_bumpers", [0]]])
	await _frames(2)
	_check("Altillo: tiene un tercer flipper", t.flippers.size() == 3 and not t.flippers[2].is_left, "%d flippers" % t.flippers.size())
	main.start_sandbox()
	await _frames(5)


func _test_robot() -> void:
	var bad := []
	for seed in [1000, 1003, 1005]:
		main.stop_sandbox()
		var t := PinballTable.new()
		t.layout = TableGenerator.generate(seed, 1 + seed % 7)
		t.juice_enabled = false
		main.world.add_child(t)
		main.table = t
		var r := TableRobot.new()
		r.table = t
		r.rng.seed = seed
		t.add_child(r)
		t.ball_lost.connect(t.serve_ball)
		t.serve_ball()
		await _frames(240 * 15)
		if r.stuck > 0 or r.escapes > 0 or r.play_time < 8.0:
			bad.append("%d: %s" % [seed, r.summary()])
	_check("Robot: juega 3 mesas generadas sin trabarse ni escaparse", bad.is_empty(), str(bad) if not bad.is_empty() else "ok")
	main.start_sandbox()
	await _frames(5)
