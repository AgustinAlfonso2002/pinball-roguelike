class_name Hud
extends Control
## HUD de la partida (interfaz de 960 x 540, la mesa ocupa el centro): puntaje, objetivo, bolas, fichas,
## rival del duelo, objetos y mensajes.

var session: GameSession = null:
	set(value):
		session = value
		if session:
			session.message_posted.connect(show_message)

var _stage := UiTheme.label("", GameFonts.BODY_SIZE, UiTheme.MUTED)
var _score := UiTheme.label("0", GameFonts.HUGE_SIZE, UiTheme.TEXT)
var _target := UiTheme.label("", GameFonts.BODY_SIZE)
var _target_bar := ProgressBar.new()
var _mult := UiTheme.label("", GameFonts.BODY_SIZE)
var _balls := UiTheme.label("Bolas", GameFonts.BODY_SIZE)
var _pips := Pips.new()
var _coins := UiTheme.label("", GameFonts.BODY_SIZE, UiTheme.ACCENT)
var _buffs := UiTheme.label("", GameFonts.BODY_SIZE, Color(1.0, 0.55, 0.9))
var _help := UiTheme.label("", GameFonts.BODY_SIZE, UiTheme.MUTED)
var _objectives := VBoxContainer.new()

var _rival_box := VBoxContainer.new()
var _rival_name := UiTheme.label("", GameFonts.BODY_SIZE)
var _rival_score := UiTheme.label("", GameFonts.BODY_SIZE)
var _rival_bar := ProgressBar.new()
var _rival_info := UiTheme.label("", GameFonts.BODY_SIZE, UiTheme.MUTED)
var _items := UiTheme.label("", GameFonts.BODY_SIZE)

var _msg := UiTheme.label("", GameFonts.BODY_SIZE)
var _msg_time := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := VBoxContainer.new()
	left.position = Vector2(16, 12)
	left.custom_minimum_size = Vector2(290, 0)
	left.add_theme_constant_override("separation", 2)
	add_child(left)
	var balls_row := HBoxContainer.new()
	balls_row.add_theme_constant_override("separation", 6)
	balls_row.add_child(_balls)
	balls_row.add_child(_pips)
	for c in [_stage, _score, _target, _target_bar, _mult, balls_row, _coins, _buffs]:
		left.add_child(c)
	_target_bar.custom_minimum_size = Vector2(290, 8)
	_target_bar.show_percentage = false
	_buffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_help.position = Vector2(16, 370)
	_help.size = Vector2(310, 160)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.text = "Flippers: Z/M · L1/R1\nLanzar: Espacio · Cruz\nSacudir: flechas · cruceta\nObjeto 1: E · Círculo\nObjeto 2: Q · Cuadrado"
	add_child(_help)

	var right := VBoxContainer.new()
	right.position = Vector2(654, 12)
	right.custom_minimum_size = Vector2(290, 0)
	right.add_theme_constant_override("separation", 2)
	add_child(right)
	right.add_child(_rival_box)
	for c in [_rival_name, _rival_score, _rival_bar, _rival_info]:
		_rival_box.add_child(c)
	_rival_bar.custom_minimum_size = Vector2(290, 8)
	_rival_bar.show_percentage = false
	_rival_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rival_info.custom_minimum_size = Vector2(290, 0)
	_objectives.add_theme_constant_override("separation", 0)
	right.add_child(_objectives)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	right.add_child(spacer)
	right.add_child(_items)
	_items.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_items.custom_minimum_size = Vector2(290, 0)

	# Mensajes, centrados sobre la mesa.
	_msg.position = Vector2(330, 225)
	_msg.size = Vector2(300, 90)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_color_override("font_outline_color", Color.BLACK)
	_msg.add_theme_constant_override("outline_size", 4)
	add_child(_msg)


func show_message(text: String, color := Color.WHITE, duration := 2.0) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", color)
	_msg_time = duration


func _process(delta: float) -> void:
	if _msg_time > 0.0:
		_msg_time -= delta / maxf(Engine.time_scale, 0.05)
		if _msg_time <= 0.0:
			_msg.text = ""
	if not session or not is_instance_valid(session):
		return

	_stage.text = Run.stage_title()
	_score.text = Fmt.score(session.score)
	_target.text = ("Superá a: %s" if session.is_duel else "Objetivo: %s") % Fmt.score(session.target)
	if session.target_reached:
		_target.text += " (superado)"
		_target.add_theme_color_override("font_color", UiTheme.GOOD)
	else:
		_target.add_theme_color_override("font_color", UiTheme.TEXT)
	_target_bar.max_value = session.target
	_target_bar.value = minf(session.score, session.target)
	_mult.text = "Multiplicador ×%s" % Fmt.mult(session.multiplier + session.bonus_mult)
	_pips.set_counts(session.balls_left, session.balls_total)
	_coins.text = "Fichas: %d" % Run.coins
	var buff_lines := []
	for b in session.buffs:
		buff_lines.append("%s ×%s (%d s)" % [b.name, Fmt.mult(b.xmult), ceili(b.until - session.elapsed)])
	_buffs.text = "\n".join(buff_lines)

	_rival_box.visible = session.is_duel and session.rival != null
	if _rival_box.visible:
		var r := session.rival
		_rival_name.text = r.display_name
		_rival_name.add_theme_color_override("font_color", r.color)
		_rival_score.text = "Puntaje: %s / %s" % [Fmt.score(session.rival_score), Fmt.score(session.target)]
		_rival_bar.max_value = session.target
		_rival_bar.value = session.rival_score
		_rival_info.text = "Trampa: %s. %s" % [r.sabotage_name, r.sabotage_description]

	_items.text = _items_text()
	_update_objectives()


## Objetivos de la mesa: texto y premio, en verde cuando se cumplen.
func _update_objectives() -> void:
	var objs := session.objectives
	var want := 1 + objs.size() * 2 if not objs.is_empty() else 0
	if _objectives.get_child_count() != want:
		for c in _objectives.get_children():
			c.queue_free()
		if objs.is_empty():
			return
		_objectives.add_child(UiTheme.label("OBJETIVOS EXTRA", GameFonts.BODY_SIZE, UiTheme.ACCENT))
		for o in objs:
			var l := UiTheme.label("", GameFonts.BODY_SIZE)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(290, 0)
			_objectives.add_child(l)
			var r := UiTheme.label("", GameFonts.BODY_SIZE, UiTheme.MUTED)
			r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			r.custom_minimum_size = Vector2(290, 0)
			_objectives.add_child(r)
	for i in objs.size():
		var o: TableObjective = objs[i]
		var l: Label = _objectives.get_child(1 + i * 2)
		var r: Label = _objectives.get_child(2 + i * 2)
		if l.is_queued_for_deletion():
			return
		l.text = ("» " if o.done else "· ") + o.text()
		l.add_theme_color_override("font_color", UiTheme.GOOD if o.done else UiTheme.TEXT)
		r.text = "   " + o.reward_text()
		r.add_theme_color_override("font_color", UiTheme.GOOD if o.done else UiTheme.MUTED)


func _items_text() -> String:
	var lines := ["OBJETOS  (%d/%d)" % [Run.passives.size(), Run.PASSIVE_SLOTS]]
	for item in Run.passives:
		lines.append("· " + item.display_name)
	if Run.ball_item:
		lines.append("Bola: " + Run.ball_item.display_name)
	if not Run.consumables.is_empty():
		lines.append("")
		var keys := ["E/Círculo", "Q/Cuadrado"]
		for i in Run.consumables.size():
			lines.append("[%s] %s" % [keys[i], Run.consumables[i].display_name])
	return "\n".join(lines)



## Bolas restantes dibujadas como círculos (llenos = disponibles).
class Pips extends Control:
	var left := 0
	var total := 0

	func _init() -> void:
		custom_minimum_size = Vector2(110, 22)

	func set_counts(p_left: int, p_total: int) -> void:
		if p_left != left or p_total != total:
			left = p_left
			total = p_total
			queue_redraw()

	func _draw() -> void:
		for i in total:
			var c := Vector2(8 + i * 18, 12)
			if i < left:
				draw_circle(c, 6.0, UiTheme.TEXT)
			else:
				draw_arc(c, 5.5, 0.0, TAU, 16, UiTheme.MUTED, 1.0)
