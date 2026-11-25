class_name TuningPanel
extends CanvasLayer
## Panel para ajustar la física mientras jugás (Tab / Share para mostrarlo).

var _panel := PanelContainer.new()
var _sliders := {}
var _labels := {}


func _init() -> void:
	layer = 10
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -360.0
	_panel.offset_right = -12.0
	_panel.offset_top = 12.0
	_panel.offset_bottom = -12.0
	_panel.visible = false  # Tab / Share para mostrarlo (solo en desarrollo).
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
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "AJUSTE DE FÍSICA  (Tab para ocultar)\nValores base: los objetos los modifican encima."
	title.add_theme_font_size_override("font_size", 15)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(320, 0)
	box.add_child(title)

	for key in Tuning.PARAMS:
		var p: Array = Tuning.PARAMS[key]
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		box.add_child(label)
		var slider := HSlider.new()
		slider.min_value = p[1]
		slider.max_value = p[2]
		slider.step = p[3]
		slider.focus_mode = Control.FOCUS_NONE  # Que las flechas no muevan los sliders.
		slider.custom_minimum_size = Vector2(300, 18)
		slider.value_changed.connect(func(value: float) -> void: Tuning.set_value(key, value))
		box.add_child(slider)
		_sliders[key] = slider
		_labels[key] = label

	var reset := Button.new()
	reset.text = "Restaurar valores por defecto"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void: Tuning.reset_defaults())
	box.add_child(reset)

	var copy := Button.new()
	copy.text = "Copiar valores al portapapeles"
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(Tuning.to_json()))
	box.add_child(copy)


func _ready() -> void:
	Tuning.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for key in _sliders:
		var value := Tuning.v(key)
		_sliders[key].set_value_no_signal(value)
		var shown := ("%.2f" % value) if Tuning.PARAMS[key][3] < 1.0 else ("%d" % int(value))
		_labels[key].text = "%s: %s" % [Tuning.PARAMS[key][4], shown]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()
