extends Node
## Autoprueba de física sin ventana:
##   godot --headless --path . --fixed-fps 60 -- --selftest
## Mide golpes de flipper, bumper, slingshot y lanzador, y dispara la bola
## a máxima velocidad en muchas direcciones para verificar que no atraviese
## las paredes.

var main: Node2D
var _failed := 0


func _ready() -> void:
	main.infinite_balls = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["OK   " if ok else "FALLA", name, detail])
	if not ok:
		_failed += 1


func _run() -> void:
	await _frames(10)
	await _test_respawn()
	await _test_launch()
	await _test_flipper(true)
	await _test_flipper(false)
	await _test_bumper()
	await _test_sling()
	await _test_tunneling()
	await _test_rest_on_flipper()
	await _test_random_play()
	print("RESULTADO: %d fallas" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _test_launch() -> void:
	main.new_game()
	await _frames(20)
	Input.action_press("launch")
	await _frames(int(1.1 * 240))
	Input.action_release("launch")
	var left_lane := false
	var min_y := 9999.0
	for i in int(2.0 * 240):
		await get_tree().physics_frame
		min_y = minf(min_y, main.ball.global_position.y)
		if main.ball.global_position.x < main.LANE_X - 20.0:
			left_lane = true
	_check("Lanzador saca la bola del carril", left_lane, "altura mínima alcanzada y=%.0f" % min_y)


func _flipper_ball_pos(left: bool, along: float) -> Vector2:
	var pivot: Vector2 = main.LEFT_PIVOT if left else main.RIGHT_PIVOT
	var ang := deg_to_rad(Flipper.SWING_DEG)
	var d := Vector2(cos(ang), sin(ang)) if left else Vector2(-cos(ang), sin(ang))
	var n := Vector2(d.y, -d.x) if left else Vector2(-d.y, d.x)
	var half := Flipper.BASE_RADIUS - (Flipper.BASE_RADIUS - Flipper.TIP_RADIUS) * (along / Flipper.LENGTH)
	return pivot + d * along + n * (half + Ball.RADIUS + 0.5)


func _test_flipper(left: bool) -> void:
	# La bola cae sobre el flipper en reposo y se golpea justo al tocarlo.
	var action := "flipper_left" if left else "flipper_right"
	for along in [20.0, 35.0, 50.0]:
		main.new_game()
		await _frames(30)
		var contact := _flipper_ball_pos(left, along)
		main.spawn_ball(contact + Vector2(0.0, -40.0))
		var landed := false
		for i in 240:
			await get_tree().physics_frame
			if main.ball.global_position.y >= contact.y - 2.0:
				landed = true
				break
		Input.action_press(action)
		var best := Vector2.ZERO
		for i in int(0.15 * 240):
			await get_tree().physics_frame
			if main.ball.linear_velocity.length() > best.length():
				best = main.ball.linear_velocity
		Input.action_release(action)
		var side := "izquierdo" if left else "derecho"
		_check("Flipper %s golpea fuerte (a %d px del pivote)" % [side, int(along)],
				landed and best.length() > 700.0 and best.y < 0.0,
				"velocidad %d px/s, dirección %s" % [int(best.length()), str(best.normalized().snapped(Vector2(0.01, 0.01)))])
		await _frames(30)


func _test_bumper() -> void:
	main.new_game()
	await _frames(10)
	var b: Bumper = main.bumpers[0]
	var before: int = main.score
	main.spawn_ball(b.global_position + Vector2(0, 60), Vector2(0, -500))
	var best := 0.0
	for i in int(0.2 * 240):
		await get_tree().physics_frame
		best = maxf(best, main.ball.linear_velocity.length())
	_check("Bumper despide la bola y suma puntos", main.score > before and best >= Tuning.v("bumper_kick") * 0.8,
			"velocidad %d px/s, puntos +%d" % [int(best), main.score - before])


func _test_sling() -> void:
	main.new_game()
	await _frames(10)
	var s: Slingshot = main.slings[0]
	var mid := (s.edge_a + s.edge_b) * 0.5
	var before: int = main.score
	main.spawn_ball(mid + s.kick_normal * 40.0, -s.kick_normal * 400.0)
	var best := 0.0
	for i in int(0.2 * 240):
		await get_tree().physics_frame
		best = maxf(best, main.ball.linear_velocity.length())
	_check("Slingshot patea la bola", main.score > before, "velocidad %d px/s, puntos +%d" % [int(best), main.score - before])


func _test_tunneling() -> void:
	var escapes := 0
	var trials := 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for t in trials:
		main.new_game()
		var dir := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var start := Vector2(rng.randf_range(60.0, 300.0), rng.randf_range(60.0, 420.0))
		main.spawn_ball(start, dir * Tuning.v("max_ball_speed"))
		for i in int(0.6 * 240):
			await get_tree().physics_frame
			var p: Vector2 = main.ball.global_position
			if p.x < -2.0 or p.x > main.TABLE_W + 2.0 or p.y < -102.0:
				escapes += 1
				break
	_check("La bola no atraviesa paredes a velocidad máxima", escapes == 0, "%d escapes en %d disparos" % [escapes, trials])


func _test_rest_on_flipper() -> void:
	# Con el flipper levantado, la bola debería quedar atrapada (cradle).
	main.new_game()
	await _frames(10)
	Input.action_press("flipper_left")
	await _frames(20)
	main.spawn_ball(main.LEFT_PIVOT + Vector2(40, -60))
	await _frames(int(1.5 * 240))
	var p: Vector2 = main.ball.global_position
	var still: bool = main.ball.linear_velocity.length() < 40.0 and p.y < main.DRAIN_Y - 50.0
	Input.action_release("flipper_left")
	_check("La bola queda atrapada con el flipper levantado", still,
			"posición %s, velocidad %d px/s" % [str(p.round()), int(main.ball.linear_velocity.length())])


func _test_random_play() -> void:
	# Juego al azar: lanzar, flippers y sacudones. Verifica que no haya
	# escapes y que se pierdan bolas hasta el fin del juego sin errores.
	main.infinite_balls = false
	main.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var escapes := 0
	var max_score := 0
	for i in int(40.0 * 240):
		if i % 30 == 0:
			for a in ["flipper_left", "flipper_right"]:
				if rng.randf() < 0.5:
					Input.action_press(a)
				else:
					Input.action_release(a)
		if main.ball_in_lane():
			if i % 400 < 250:
				Input.action_press("launch")
			else:
				Input.action_release("launch")
		if i % 997 == 0:
			Input.action_press("nudge_left")
		elif i % 997 == 2:
			Input.action_release("nudge_left")
		await get_tree().physics_frame
		var p: Vector2 = main.ball.global_position
		if p.x < -2.0 or p.x > main.TABLE_W + 2.0 or p.y < -102.0:
			escapes += 1
		max_score = maxi(max_score, main.score)
		if main.game_over:
			break
	for a in ["flipper_left", "flipper_right", "launch", "nudge_left"]:
		Input.action_release(a)
	_check("Partida al azar de 40 s sin escapes y sumando puntos", escapes == 0 and max_score > 0,
			"puntaje %d, fin del juego: %s, escapes: %d" % [max_score, str(main.game_over), escapes])
	main.infinite_balls = true


func _test_respawn() -> void:
	# Después de perder la bola, la nueva tiene que quedar quieta en el carril.
	var ok_count := 0
	for x in [40.0, 184.0, 231.0, 330.0]:
		main.new_game()
		await _frames(5)
		main.spawn_ball(Vector2(x, main.DRAIN_Y - 5.0), Vector2(0, 600))
		await _frames(int(1.0 * 240))
		if main.ball_in_lane() and main.ball.linear_velocity.length() < 30.0:
			ok_count += 1
	_check("La bola reaparece quieta en el carril del lanzador", ok_count == 4, "%d de 4" % ok_count)
