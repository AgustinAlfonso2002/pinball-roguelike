class_name Hud
extends CanvasLayer
## Puntaje, bolas restantes, mensajes y ayuda de controles.

var _score_label := Label.new()
var _info_label := Label.new()
var _msg_label := Label.new()
var _help_label := Label.new()
var _msg_time := 0.0


func _init() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_score_label.position = Vector2(32, 24)
	_score_label.add_theme_font_size_override("font_size", 40)
	root.add_child(_score_label)

	_info_label.position = Vector2(32, 80)
	_info_label.add_theme_font_size_override("font_size", 18)
	_info_label.modulate = Color(0.8, 0.85, 1.0)
	root.add_child(_info_label)

	_help_label.position = Vector2(32, 430)
	_help_label.add_theme_font_size_override("font_size", 15)
	_help_label.modulate = Color(0.7, 0.72, 0.8)
	_help_label.text = """CONTROLES          teclado  /  joystick PS4
Flipper izquierdo  Z, Shift izq.  /  L1, L2
Flipper derecho    M, Shift der.  /  R1, R2
Lanzar (mantener)  Espacio  /  Cruz
Sacudir la mesa    Flechas  /  Cruceta o stick derecho
Soltar bola test   B  /  Triángulo
Cámara lenta       T  /  Cuadrado
Panel de ajuste    Tab  /  Share
Reiniciar          R  /  Options"""
	root.add_child(_help_label)

	_msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_msg_label.position = Vector2(440, 300)
	_msg_label.size = Vector2(400, 60)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 36)
	_msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_msg_label.add_theme_constant_override("outline_size", 8)
	root.add_child(_msg_label)


func set_stats(score: int, balls: int, speed: float, slowmo: bool, joypads: int) -> void:
	_score_label.text = "%d" % score
	var lines := "Bolas: %d\nVelocidad de la bola: %d px/s\nFPS: %d" % [balls, int(speed), Engine.get_frames_per_second()]
	if slowmo:
		lines += "\nCÁMARA LENTA (x0.25)"
	lines += "\nJoysticks conectados: %d" % joypads
	_info_label.text = lines


func show_message(text: String, duration := 1.5) -> void:
	_msg_label.text = text
	_msg_time = duration


func _process(delta: float) -> void:
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_msg_label.text = ""
