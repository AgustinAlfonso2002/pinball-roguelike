extends Node
## Punto de entrada: arma la pantalla y maneja el flujo de la run (cartel de
## inicio, partidas, duelo, tienda...).
##
## La pantalla mide 1920 x 1080 (Godot la escala a la ventana) y mezcla tres
## tamaños de pixel, como los juegos de pixel art modernos:
##   - Fondos ilustrados: 480 x 270, cada pixel = 4 de pantalla.
##   - Mesa de pinball: 640 x 360, cada pixel = 3 de pantalla.
##   - Interfaz y textos: 960 x 540, cada pixel = 2 de pantalla (más finos).
##
## Estructura:
##   Main
##   ├── SubViewportContainer 1920 x 1080 (x3, shader de pixel nítido)
##   │   └── SubViewport 640 x 360
##   │       └── World (Node2D)  → la mesa de cada partida
##   ├── CanvasLayer (escala x2) → UI 960 x 540: menú, HUD, carteles, tienda, pausa
##   └── TuningPanel / DebugPanel (solo en desarrollo)

const GAME_SIZE := Vector2i(640, 360)
const SCREEN_SIZE := Vector2i(1920, 1080)

var world := Node2D.new()
var ui := Control.new()
var hud := Hud.new()
var session: GameSession = null
var table: PinballTable = null  ## Mesa suelta, solo para la autoprueba.

var _container := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _last_session := {}
var _abort := false
var _pause: PauseMenu = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.03, 0.03, 0.05))
	_viewport.size = GAME_SIZE
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.physics_object_picking = false
	_container.stretch = true
	_container.stretch_shrink = SCREEN_SIZE.x / GAME_SIZE.x
	_container.size = Vector2(SCREEN_SIZE)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_container.material = Art.sharp_material(Vector2(GAME_SIZE))
	_container.add_child(_viewport)
	add_child(_container)
	_viewport.add_child(world)

	var ui_layer := CanvasLayer.new()
	ui_layer.scale = Vector2(SCREEN_SIZE) / UiTheme.SCREEN
	add_child(ui_layer)
	ui.size = UiTheme.SCREEN
	ui.theme = UiTheme.make()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui)
	hud.visible = false
	ui.add_child(hud)
	var keeper := FocusKeeper.new()
	keeper.root = ui
	ui.add_child(keeper)

	if OS.is_debug_build():
		var tuning := TuningPanel.new()
		tuning.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(tuning)
		var debug := DebugPanel.new()
		debug.main = self
		debug.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(debug)

	var args := OS.get_cmdline_user_args()
	if "--robot" in args:
		var runner := RobotRunner.new()
		runner.world = world
		var i := args.find("--robot")
		if args.size() > i + 1 and args[i + 1].is_valid_int():
			runner.tables = int(args[i + 1])
		if args.size() > i + 2 and args[i + 2].is_valid_float():
			runner.seconds = float(args[i + 2])
		add_child(runner)
		return
	if "--selftest" in args:
		start_sandbox()
		var test: Node = load("res://tests/self_test.gd").new()
		test.main = self
		add_child(test)
		return
	_run_loop()


func _exit_tree() -> void:
	TableParts.cleanup()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		var full := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- Flujo del juego -----------------------------------------------------------

func _run_loop() -> void:
	while true:
		var title := TitleScreen.new()
		ui.add_child(title)
		var action: String = await title.chosen
		title.queue_free()
		if action == "quit":
			get_tree().quit()
			return
		var phase := "stage"
		if action == "continue":
			phase = SaveGame.load_run()
			if phase == "":
				await CardScreen.open(ui, "NO SE PUDO CARGAR", "La partida guardada está dañada o es de otra versión.", ["Volver"], UiTheme.BAD)
				continue
		else:
			if SaveGame.exists():
				var c := await CardScreen.open(ui, "¿NUEVA PARTIDA?",
						"Ya tenés una partida guardada:\n%s\n\nSi empezás una nueva, se borra." % SaveGame.summary(),
						["Volver", "Empezar de nuevo"], UiTheme.BAD)
				if c == 0:
					continue
			SaveGame.delete()
			Run.new_run()
		await _play_run(phase)


## Juega la run desde la fase indicada hasta perderla, salir al menú o terminarla.
func _play_run(phase: String) -> void:
	_abort = false
	while true:
		if phase == "shop":
			SaveGame.save("shop")
			await _shop()
			Run.next_night()
		phase = "stage"
		SaveGame.save("stage")
		var result := await _play_stage()
		if result == "abort":
			return
		if result == "lost":
			SaveGame.delete()
			await _run_over()
			return
		if Run.stage < Run.DUEL_STAGE:
			Run.stage += 1
			continue
		# Terminó la noche.
		if Run.is_final_night():
			var choice := await CardScreen.open(ui, "¡CAMPEÓN DEL ARCADE!",
					"Le ganaste a todos en las siete noches.\n\nPodés seguir en el modo infinito, con objetivos que crecen sin límite.",
					["Modo infinito", "Volver al menú"], UiTheme.GOOD)
			if choice == 1:
				SaveGame.delete()
				return
			Run.endless = true
		phase = "shop"


## Juega la etapa actual (partida o duelo): "won", "lost" o "abort".
func _play_stage() -> String:
	var duel := Run.is_duel()
	var target := Run.current_target()
	var rival: Rival = Run.create_rival() if duel else null
	var balls := maxi(1, int(Run.stat(&"balls_per_game")))

	var body: String
	if duel and rival:
		body = "%s\n\"%s\"\n\nTrampa: %s. %s\n\nSu puntaje sube en vivo hasta %s. Superalo antes de quedarte sin bolas (%d)." % [
			rival.display_name, rival.intro_line, rival.sabotage_name, rival.sabotage_description,
			Fmt.score(target), balls]
	else:
		body = "Objetivo: %s puntos\nBolas: %d" % [Fmt.score(target), balls]
	var layout := Run.night_layout()
	body += "\n\nMesa: %s" % layout.describe()
	await CardScreen.open(ui, Run.stage_title().to_upper(), body, ["¡A jugar!"],
			rival.color if rival else UiTheme.ACCENT)

	session = GameSession.new()
	session.setup(world, duel, target, rival)
	session.layout = layout
	add_child(session)
	hud.session = session
	hud.visible = true
	var won: bool = await session.finished
	hud.visible = false
	_close_pause()

	if _abort:
		session.queue_free()
		session = null
		Engine.time_scale = 1.0
		return "abort"

	var reward := 0
	var base_reward := int(Run.stat(&"duel_reward" if duel else &"game_reward"))
	if won:
		reward = base_reward + int(session.balls_left * Run.stat(&"coins_per_ball_left"))
		Run.add_coins(reward)

	_last_session = {
		"score": session.score, "target": target, "hits": session.hits,
		"best": session.best_hit, "rival": rival, "extra": session.extra_rewards.duplicate(),
		"balls_left": session.balls_left,
	}
	session.queue_free()
	session = null
	Engine.time_scale = 1.0

	if won:
		var lines := ["Puntaje: %s / %s" % [Fmt.score(_last_session.score), Fmt.score(target)]]
		if rival:
			lines.append("%s: \"%s\"" % [rival.display_name, rival.defeat_line])
		lines.append("")
		lines.append("+%d fichas (%d por ganar + %d por bolas sin usar)" % [reward, base_reward, reward - base_reward])
		for extra in _last_session.extra:
			lines.append(extra)
		lines.append("Fichas: %d" % Run.coins)
		await CardScreen.open(ui, "¡LE GANASTE!" if duel else "¡OBJETIVO SUPERADO!", "\n".join(lines),
				["Ir a la tienda" if duel else "Continuar"], UiTheme.GOOD)
		return "won"
	return "lost"


func _run_over() -> void:
	var s := _last_session
	var lines := []
	if s.rival:
		lines.append("%s: \"%s\"" % [s.rival.display_name, s.rival.victory_line])
		lines.append("")
	lines.append("Llegaste a: %s" % Run.stage_title())
	lines.append("Puntaje: %s de %s" % [Fmt.score(s.score), Fmt.score(s.target)])
	lines.append("Mejor golpe: %s · Golpes: %d" % [Fmt.score(s.best), s.hits])
	await CardScreen.open(ui, "FIN DE LA RUN", "\n".join(lines), ["Volver al menú"], UiTheme.BAD)


func _shop() -> void:
	var shop := ShopScreen.new()
	ui.add_child(shop)
	await shop.closed
	shop.queue_free()


# --- Pausa ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and session and not session.done and not _pause:
		get_viewport().set_input_as_handled()
		_open_pause()


func _open_pause() -> void:
	_pause = PauseMenu.new()
	ui.add_child(_pause)
	get_tree().paused = true
	_pause.resumed.connect(_close_pause)
	_pause.quit_to_menu.connect(func() -> void:
		_close_pause()
		_abort = true
		if session:
			session.abort())


func _close_pause() -> void:
	get_tree().paused = false
	if _pause:
		_pause.queue_free()
		_pause = null


# --- Autoprueba ------------------------------------------------------------------

## Mesa suelta, sin partida (bolas infinitas). La usa tests/self_test.gd.
func start_sandbox() -> void:
	stop_sandbox()
	table = PinballTable.new()
	table.juice_enabled = false
	world.add_child(table)
	table.ball_lost.connect(func() -> void: table.serve_ball())
	table.serve_ball()


func stop_sandbox() -> void:
	if table:
		table.queue_free()
		table = null
