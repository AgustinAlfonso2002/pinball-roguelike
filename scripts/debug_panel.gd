class_name DebugPanel
extends CanvasLayer
## Panel de depuración (F2). Solo existe en builds de desarrollo.
##
## Permite darte cualquier objeto, sumar fichas, ganar la partida, perder la
## bola, bolas infinitas y cambiar de noche, para probar objetos sin jugar.

const KIND_FILTERS := ["Todos", "Pasivos", "Bolas", "Consumibles"]

var main: Node

var _panel := PanelContainer.new()
var _state := Label.new()
var _filter := OptionButton.new()
var _catalog := VBoxContainer.new()
var _owned := VBoxContainer.new()
var _note := Label.new()
var _infinite := CheckBox.new()
var _table_info := Label.new()
var _chassis := OptionButton.new()
var _robot := CheckBox.new()
var _timer := 0.0


func _init() -> void:
	layer = 11
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 12.0
	_panel.offset_right = 372.0
	_panel.offset_top = 12.0
	_panel.offset_bottom = -12.0
	_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.065, 0.1, 0.97)
	bg.border_color = Color(0.3, 0.33, 0.5)
	bg.set_border_width_all(1)
	bg.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)

	box.add_child(_title("DEPURACIÓN  (F2 para ocultar)"))
	_state.add_theme_font_size_override("font_size", 13)
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_state)

	box.add_child(_row([
		_button("+10 fichas", func() -> void: Run.add_coins(10)),
		_button("Ganar partida", _win),
		_button("Perder bola", _lose_ball),
	]))
	box.add_child(_row([
		_button("Noche −1", func() -> void: _change_night(-1)),
		_button("Noche +1", func() -> void: _change_night(1)),
		_button("Ir al duelo", _go_to_duel),
	]))
	_infinite.text = "Bolas infinitas"
	_infinite.focus_mode = Control.FOCUS_NONE
	_infinite.toggled.connect(func(on: bool) -> void: GameSession.debug_infinite_balls = on)
	box.add_child(_infinite)

	box.add_child(_title("MESA"))
	_table_info.add_theme_font_size_override("font_size", 13)
	_table_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_table_info)
	_chassis.add_item("Chasis al azar")
	for id in TableParts.chassis_ids():
		_chassis.add_item(TableParts.chassis(id).display_name)
		_chassis.set_item_metadata(_chassis.item_count - 1, id)
	_chassis.focus_mode = Control.FOCUS_NONE
	box.add_child(_row([_chassis, _button("Mesa al azar", _random_table)]))
	_robot.text = "Robot juega (mirá cómo juega la mesa)"
	_robot.focus_mode = Control.FOCUS_NONE
	_robot.toggled.connect(func(_on: bool) -> void: _sync_robot())
	box.add_child(_robot)

	box.add_child(_title("OBJETOS DEL CATÁLOGO"))
	for f in KIND_FILTERS:
		_filter.add_item(f)
	_filter.focus_mode = Control.FOCUS_NONE
	_filter.item_selected.connect(func(_i: int) -> void: _refresh_catalog())
	box.add_child(_filter)
	_note.add_theme_font_size_override("font_size", 12)
	_note.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note)
	box.add_child(_catalog)

	box.add_child(_title("TUS OBJETOS"))
	box.add_child(_owned)


func _ready() -> void:
	Run.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.3
		_refresh_state()
	_sync_robot()


# --- Acciones ------------------------------------------------------------------

func _session() -> GameSession:
	var s = main.session if main else null
	return s if s and is_instance_valid(s) else null


func _win() -> void:
	var s := _session()
	if s:
		s.debug_win()


func _lose_ball() -> void:
	var s := _session()
	if s:
		s.debug_lose_ball()


## Genera una mesa nueva al azar (con el chasis elegido) y la pone en la partida.
func _random_table() -> void:
	var s := _session()
	if not s:
		return
	var forced: StringName = &""
	if _chassis.selected > 0:
		forced = _chassis.get_item_metadata(_chassis.selected)
	var layout := TableGenerator.generate(randi() & 0x7fffffff, Run.night, forced)
	layout.night = Run.night
	Run.debug_layout = layout
	s.replace_table(layout)
	s.message("Depuración: mesa nueva", Color(1.0, 0.7, 0.4))
	_refresh_state()


## Pone o saca el robot de la mesa actual.
func _sync_robot() -> void:
	var s := _session()
	if not s or not is_instance_valid(s.table):
		return
	var has := s.table.has_node("Robot")
	if _robot.button_pressed and not has:
		var r := TableRobot.new()
		r.name = "Robot"
		r.table = s.table
		r.rng.randomize()
		s.table.add_child(r)
	elif not _robot.button_pressed and has:
		s.table.get_node("Robot").queue_free()


func _change_night(delta: int) -> void:
	if not Run.active:
		return
	Run.night = maxi(1, Run.night + delta)
	Run.changed.emit()


## La próxima etapa que se juegue será el duelo de la noche actual.
func _go_to_duel() -> void:
	if not Run.active:
		return
	var s := _session()
	if s and not Run.is_duel():
		Run.stage = Run.DUEL_STAGE - 1  # al ganar esta partida, sigue el duelo
		s.debug_win()
	elif not s:
		Run.stage = Run.DUEL_STAGE
	Run.changed.emit()


func _give(id: StringName) -> void:
	if not Run.active:
		return
	var item := Items.create(id)
	Run.add_item(item)  # sin chequear lugar ni fichas, para poder probar combinaciones
	var s := _session()
	if s:
		item.on_game_start(s)
		if s.table.ball:
			item.configure_ball(s.table.ball)
		s.message("Depuración: %s" % item.display_name, Color(1.0, 0.7, 0.4))


func _remove(item: Item) -> void:
	Run.remove_item(item)


# --- Interfaz ------------------------------------------------------------------

func _refresh() -> void:
	_refresh_state()
	_refresh_catalog()
	_refresh_owned()


func _refresh_state() -> void:
	if not Run.active:
		_state.text = "No hay una run en curso."
		return
	var s := _session()
	var lines := [
		"%s · Fichas: %d" % [Run.stage_title(), Run.coins],
		"Pasivos %d/%d · Consumibles %d/%d" % [Run.passives.size(), Run.PASSIVE_SLOTS, Run.consumables.size(), Run.CONSUMABLE_SLOTS],
	]
	if s:
		lines.append("Puntaje %s / %s · Mult ×%s · Bolas %d" % [Fmt.score(s.score), Fmt.score(s.target), Fmt.mult(s.multiplier), s.balls_left])
		lines.append("Velocidad de la bola: %d px/s" % int(s.table.ball_speed()))
		var l := s.layout
		var objs := []
		for o in s.objectives:
			objs.append("· %s → %s%s" % [o.text(), o.reward_text(), " (cumplido)" if o.done else ""])
		_table_info.text = "%s\nSemilla %d\n%s" % [l.describe(), l.seed, "\n".join(objs)]
		if s.table.has_node("Robot"):
			_table_info.text += "\nRobot: " + (s.table.get_node("Robot") as TableRobot).summary()
	else:
		_table_info.text = "Empezá una partida para generar mesas."
	_state.text = "\n".join(lines)


func _refresh_catalog() -> void:
	for c in _catalog.get_children():
		c.queue_free()
	_note.text = "" if Run.active else "Empezá una run (botón Empezar) para poder darte objetos."
	var ids := Items.ids()
	ids.sort()
	var kind_filter := _filter.selected - 1  # -1 = todos
	for id in ids:
		var p := Items.proto(id)
		if kind_filter >= 0 and p.kind != kind_filter:
			continue
		var label := Label.new()
		label.text = "%s  (%s, %d)" % [p.display_name, Item.KIND_NAMES[p.kind], p.price]
		label.tooltip_text = p.description
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Item.RARITY_COLORS[p.rarity])
		var give := _button("Dar", _give.bind(id))
		give.disabled = not Run.active
		_catalog.add_child(_row([label, give]))


func _refresh_owned() -> void:
	for c in _owned.get_children():
		c.queue_free()
	if Run.all_items().is_empty():
		_owned.add_child(_small("Ninguno."))
		return
	for item in Run.all_items():
		var label := _small("%s  (%s)" % [item.display_name, Item.KIND_NAMES[item.kind]])
		label.tooltip_text = item.get_description()
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_owned.add_child(_row([label, _button("Quitar", _remove.bind(item))]))


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	return l


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	return l


## Los botones no toman el foco: así Espacio y las flechas siguen yendo al juego.
func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


func _row(children: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for c in children:
		row.add_child(c)
	return row
