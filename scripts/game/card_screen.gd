class_name CardScreen
extends Control
## Cartel centrado con título, texto y botones (intros, resultados, fin de run).
## Se usa con: var choice = await CardScreen.open(parent, titulo, texto, botones)

signal chosen(index: int)


static func open(parent: Node, title: String, body: String, buttons: Array, title_color := UiTheme.ACCENT) -> int:
	var card := CardScreen.new()
	parent.add_child(card)
	card._build(title, body, buttons, title_color)
	var index: int = await card.chosen
	card.queue_free()
	return index


func _build(title: String, body: String, buttons: Array, title_color: Color) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var t := UiTheme.label(title, GameFonts.TITLE_SIZE, title_color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b := UiTheme.label(body, GameFonts.BODY_SIZE)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(596, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(b)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var first: Button = null
	for i in buttons.size():
		var btn := Button.new()
		btn.text = buttons[i]
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(func() -> void: chosen.emit(i))
		row.add_child(btn)
		if not first:
			first = btn

	# Centrar el panel cuando ya tenga su tamaño.
	panel.resized.connect(func() -> void: panel.position = ((UiTheme.SCREEN - panel.size) * 0.5).floor())
	# Bloqueo breve para no aceptar sin querer con un botón que se venía apretando.
	for btn in row.get_children():
		btn.disabled = true
	await get_tree().create_timer(0.35, true, false, true).timeout
	for btn in row.get_children():
		btn.disabled = false
	if first:
		first.grab_focus()
