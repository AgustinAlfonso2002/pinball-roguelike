class_name FloatingText
extends Node2D
## Texto que sube y se desvanece (puntos de cada impacto).

const DURATION := 0.8
const RISE_SPEED := 22.0

var text := ""
var color := Color.WHITE
var font_size := 16
var _life := 0.0


func _init(p_text: String, p_color := Color.WHITE, p_size := GameFonts.SMALL_SIZE) -> void:
	text = p_text
	color = p_color
	font_size = p_size
	z_index = 10
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	_life += delta
	position.y -= RISE_SPEED * delta
	if _life >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - clampf((_life - DURATION * 0.5) / (DURATION * 0.5), 0.0, 1.0)
	var font := GameFonts.for_size(font_size)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-width * 0.5, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, alpha))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))
