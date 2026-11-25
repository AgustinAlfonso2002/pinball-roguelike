class_name PauseMenu
extends Control
## Pausa durante la partida (Options / Esc): seguir o salir al menú.

signal resumed
signal quit_to_menu

var _first: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := UiTheme.label("PAUSA", GameFonts.TITLE_SIZE, UiTheme.PINK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_first = _button(box, "Seguir jugando", func() -> void: resumed.emit())
	_button(box, "Salir al menú", func() -> void: quit_to_menu.emit())
	var note := UiTheme.label("Si salís, al continuar vas a\nempezar esta etapa de nuevo.", GameFonts.BODY_SIZE, UiTheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	panel.resized.connect(func() -> void: panel.position = ((UiTheme.SCREEN - panel.size) * 0.5).floor())
	_first.grab_focus.call_deferred()


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 40)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resumed.emit()
