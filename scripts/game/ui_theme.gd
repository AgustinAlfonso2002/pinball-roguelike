class_name UiTheme
## Tema visual de la interfaz. La interfaz se arma en 960 x 540 (SCREEN) y se
## dibuja al doble: cada pixel de las fuentes ocupa 2 x 2 de pantalla.

## Tamaño de la pantalla de la interfaz.
const SCREEN := Vector2(960, 540)

# Paleta "arcade de barrio" (misma que tools/gen_art.py).
const BG := Color8(22, 13, 38)
const PANEL := Color8(35, 20, 54)
const BORDER := Color8(71, 37, 95)
const ACCENT := Color8(255, 216, 74)
const PINK := Color8(255, 63, 164)
const CYAN := Color8(53, 227, 255)
const TEXT := Color8(255, 246, 240)
const MUTED := Color8(168, 150, 190)
const GOOD := Color8(76, 224, 138)
const BAD := Color8(232, 59, 79)


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = GameFonts.body()
	t.default_font_size = GameFonts.BODY_SIZE
	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("panel", "Panel", _box(PANEL, BORDER, 1))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 1, 6))

	t.set_stylebox("normal", "Button", _box(Color(0.15, 0.16, 0.25), BORDER, 1, 4))
	t.set_stylebox("hover", "Button", _box(Color(0.2, 0.21, 0.33), BORDER, 1, 4))
	t.set_stylebox("pressed", "Button", _box(Color(0.25, 0.26, 0.4), ACCENT, 1, 4))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), PINK, 2, 4))
	t.set_stylebox("disabled", "Button", _box(Color(0.1, 0.1, 0.15), Color(0.2, 0.2, 0.28), 1, 4))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.55))
	t.set_font_size("font_size", "Button", GameFonts.BODY_SIZE)

	t.set_stylebox("background", "ProgressBar", _box(Color(0.05, 0.05, 0.08), BORDER, 1))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, ACCENT, 0))
	return t


static func _box(bg: Color, border: Color, width: int, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = false
	return sb


## Etiqueta con la fuente pixel del tamaño pedido (15 = texto, 20 = título, 40 = enorme).
static func label(text: String, size := GameFonts.BODY_SIZE, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", GameFonts.for_size(size))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
