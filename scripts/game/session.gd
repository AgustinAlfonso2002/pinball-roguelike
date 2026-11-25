class_name GameSession
extends Node
## Una partida (o un duelo): crea la mesa, suma los puntos pasando cada golpe
## por los objetos, maneja las bolas y decide si ganaste o perdiste.
##
## Partida: al llegar al puntaje objetivo ya ganaste, pero seguís jugando con
## la bola actual hasta perderla; las bolas que no usaste dan fichas extra.
## Perdés si te quedás sin bolas antes de llegar al objetivo.
## Duelo: igual, pero el objetivo es el puntaje final del rival, que sube en
## vivo y te sabotea hasta que pierdas la última bola que juegues.

signal finished(won: bool)
signal objectives_changed

## Depuración: las bolas perdidas no se descuentan (panel F2).
static var debug_infinite_balls := false
signal message_posted(text: String, color: Color)

var is_duel := false
var target := 0.0
var rival: Rival = null

var score := 0.0
var multiplier := 1.0  ## Multiplicador de la bola: +1 por banco completo; vuelve a 1 al perder la bola.
var bonus_mult := 0.0  ## Suma al multiplicador por toda la partida (premio de objetivos).
var balls_total := 3
var balls_left := 3
var hits := 0
var elapsed := 0.0  ## Segundos de juego (respetan la cámara lenta).
var rival_score := 0.0
var done := false
var won := false
var target_reached := false  ## Ya ganaste: se juega hasta perder la bola actual.
var best_hit := 0.0
var extra_rewards: Array[String] = []  ## Los objetos agregan líneas al resumen.
var buffs: Array = []  ## Potenciadores temporales: {name, xmult, until}

var table: PinballTable
var layout: TableLayout = null  ## Mesa a jugar (null = la clásica).
var objectives: Array[TableObjective] = []
var _world: Node


func setup(world: Node, duel: bool, p_target: float, p_rival: Rival = null) -> void:
	_world = world
	is_duel = duel
	target = p_target
	rival = p_rival


func _ready() -> void:
	_build_table()
	balls_total = maxi(1, int(Run.stat(&"balls_per_game")))
	balls_left = balls_total
	Run.notify(&"on_game_start", [self])
	Run.notify(&"on_table_built", [self, table])
	if rival:
		rival.start(self)
	table.serve_ball()


func _build_table() -> void:
	if layout == null:
		layout = TableGenerator.default_layout()
	table = PinballTable.new()
	table.layout = layout
	_world.add_child(table)
	table.hit.connect(_on_hit)
	table.ball_lost.connect(_on_ball_lost)
	table.ball_launched.connect(func(power: float) -> void: Run.notify(&"on_ball_launched", [self, power]))
	table.flipper_swung.connect(func(left: bool, up: bool) -> void: Run.notify(&"on_flipper", [self, left, up]))
	table.bank_completed.connect(_on_bank_completed)
	table.module_event.connect(_on_module_event)
	objectives = TableGenerator.objectives(layout, hash([layout.seed, Run.stage]), Run.night, target)
	objectives_changed.emit()


## Cambia la mesa en medio de la partida (panel F2: "mesa al azar").
func replace_table(new_layout: TableLayout) -> void:
	if done:
		return
	var old := table
	old.hit.disconnect(_on_hit)
	old.ball_lost.disconnect(_on_ball_lost)
	old.queue_free()
	layout = new_layout
	_build_table()
	Run.notify(&"on_table_built", [self, table])
	table.serve_ball()


func _exit_tree() -> void:
	if is_instance_valid(table):
		table.queue_free()


func _process(delta: float) -> void:
	if done:
		return
	elapsed += delta
	for i in range(buffs.size() - 1, -1, -1):
		if elapsed >= buffs[i].until:
			message("%s terminó" % buffs[i].name)
			buffs.remove_at(i)
	Run.notify(&"on_tick", [self, delta])
	if rival:
		# El rival sigue saboteando hasta que pierdas la bola, aunque ya le hayas ganado.
		rival.tick(self, delta)
		rival_score = target * rival.progress(elapsed)
	if table.input_enabled:
		if Input.is_action_just_pressed("use_item_1"):
			_use_consumable(0)
		if Input.is_action_just_pressed("use_item_2"):
			_use_consumable(1)


# --- Puntaje -----------------------------------------------------------------------

func _on_hit(source: StringName, base: float, pos: Vector2, node: Node) -> void:
	if done:
		return
	var evt := HitEvent.new(source, base, pos, node)
	Run.notify(&"on_hit", [self, evt])
	for b in buffs:
		evt.xmult *= b.xmult
	var points := evt.total(multiplier + bonus_mult)
	score += points
	hits += 1
	best_hit = maxf(best_hit, points)
	Run.notify(&"after_hit", [self, evt, points])
	var big := source == &"bank"
	var color := Color(0.55, 1.0, 0.6) if big else (Color(1.0, 0.55, 0.9) if evt.xmult > 1.0 or evt.mult_add > 0.0 else Color(1.0, 0.85, 0.4))
	table.show_text("+" + Fmt.score(points), pos, color, GameFonts.WORLD_BIG if big else GameFonts.SMALL_SIZE)
	_check_win()


func _on_bank_completed() -> void:
	multiplier += 1.0
	Run.notify(&"on_bank_completed", [self])
	message("¡Multiplicador ×%s!" % Fmt.mult(multiplier + bonus_mult), Color(0.55, 1.0, 0.6))


func _on_module_event(tag: StringName, pos: Vector2, module: TableModule) -> void:
	if done:
		return
	var changed := false
	for o in objectives:
		var before := o.progress
		if o.track(tag, module, elapsed):
			_grant(o, pos)
		if o.progress != before:
			changed = true
	if changed:
		objectives_changed.emit()


func _grant(o: TableObjective, pos: Vector2) -> void:
	Sfx.play("bank_complete", 1.2, 0.0)
	table.rumble(0.4, 0.5, 0.2)
	match o.reward:
		TableObjective.Reward.COINS:
			Run.add_coins(o.reward_value)
		TableObjective.Reward.MULT:
			bonus_mult += o.reward_value
		TableObjective.Reward.POINTS:
			score += o.reward_value
			table.show_text("+" + Fmt.score(o.reward_value), pos, Color(0.55, 1.0, 0.6), GameFonts.WORLD_BIG)
			_check_win()
	extra_rewards.append("Objetivo: %s (%s)" % [o.label, o.reward_text()])
	message("¡Objetivo cumplido!\n%s" % o.reward_text(), Color(0.55, 1.0, 0.6))


func _check_win() -> void:
	if done or target_reached or score < target:
		return
	target_reached = true
	Sfx.play("bank_complete", 1.0, 0.0)
	table.rumble(0.5, 0.6, 0.25)
	var unused := balls_left - 1
	var title := "¡Le ganaste a %s!" % rival.display_name if is_duel and rival else "¡OBJETIVO SUPERADO!"
	if unused > 0:
		message("%s\nSeguí jugando esta bola.\n+%d fichas por las bolas sin usar" % [title, unused], Color(0.55, 1.0, 0.6))
	else:
		message("%s\nSeguí jugando esta bola." % title, Color(0.55, 1.0, 0.6))


# --- Bolas --------------------------------------------------------------------------

func _on_ball_lost() -> void:
	if done:
		return
	if target_reached:
		# Ya ganaste: perder la bola en juego cierra la partida.
		balls_left -= 1
		Run.notify(&"on_ball_lost", [self])
		_finish(true)
		return
	if Run.try_save_ball(self):
		table.serve_ball()
		return
	if debug_infinite_balls:
		message("Bola perdida (bolas infinitas)", Color(0.6, 0.63, 0.75))
		table.serve_ball()
		return
	balls_left -= 1
	multiplier = 1.0
	Run.notify(&"on_ball_lost", [self])
	if balls_left <= 0:
		Sfx.play("game_over", 1.0, 0.0)
		_finish(false)
	else:
		Sfx.play("drain", 1.0, 0.0)
		message("Bola perdida")
		table.serve_ball()


func _finish(p_won: bool) -> void:
	done = true
	won = p_won
	table.input_enabled = false
	for f in table.flippers:
		f.enabled = false
	if p_won:
		Sfx.play("drain", 1.0, 0.0)
		message("Fin de la partida", Color(0.55, 1.0, 0.6))
	else:
		if is_duel:
			rival_score = target
		message("Sin bolas", Color(1.0, 0.4, 0.4))
	Run.notify(&"on_game_end", [self, won])
	await get_tree().create_timer(1.6, true, false, true).timeout
	finished.emit(won)


## Corta la partida sin resultado (salir al menú desde la pausa).
func abort() -> void:
	if not done:
		done = true
		table.input_enabled = false
		finished.emit(false)


# --- Depuración ----------------------------------------------------------------

## Gana la partida al instante (panel F2).
func debug_win() -> void:
	if not done:
		score = maxf(score, target)
		target_reached = true
		_finish(true)


## Pierde la bola actual (panel F2).
func debug_lose_ball() -> void:
	if not done and table.ball_in_play():
		table.remove_ball()
		table.ball_held = false
		table.ball_lost.emit()


# --- Ayudas para objetos y rivales ---------------------------------------------

func message(text: String, color := Color.WHITE) -> void:
	message_posted.emit(text, color)


func rival_says(text: String) -> void:
	if rival and text != "":
		message_posted.emit("%s: %s" % [rival.display_name, text], rival.color)


## Texto flotante en la mesa.
func popup(text: String, pos: Vector2, color := Color.WHITE) -> void:
	table.show_text(text, pos, color)


## Potenciador temporal: todos los puntos ×xmult durante `seconds` segundos de juego.
func add_buff(buff_name: String, xmult: float, seconds: float) -> void:
	buffs.append({"name": buff_name, "xmult": xmult, "until": elapsed + seconds})
	message("%s: puntos ×%s por %d s" % [buff_name, Fmt.mult(xmult), int(seconds)], Color(1.0, 0.55, 0.9))


func _use_consumable(index: int) -> void:
	var result := Run.use_consumable(index, self)
	if result != "":
		message(result, Color(0.5, 0.8, 1.0))
