class_name TitleScreen
extends Control
## Pantalla de inicio: el arcade de noche, animado, con el cartel de neón de
## FICHINLIKE y el menú (Nueva partida / Continuar / Salir).
##
## Fondo: assets/art/menu/arcade_bg.png (480 x 270, hecho con Retro Diffusion),
## dibujado al doble de la interfaz (cada pixel = 4 de pantalla). Sus propios
## píxeles se animan con el shader arcade_bg.gdshader y la máscara
## arcade_fx.png (ver tools/gen_menu_fx.py): pantallas, neón, luces y lámparas.
## Encima se dibujan los halos del neón, el polvo en la luz y el logo.
## Se maneja entero con joystick (cruceta/stick + Cruz) o teclado.

signal chosen(action: String)  ## "new", "continue" o "quit"

const GAME_TITLE := "FICHINLIKE"
const VERSION := "v0.4 · prototipo"
const ART := "res://assets/art/menu/"
const BG_SIZE := Vector2(480, 270)
const BG_SCALE := 2.0  ## Píxeles de interfaz por pixel del fondo.

## Tubos de neón del fondo (en píxeles del fondo): desde, hasta, color, grupo.
## Grupo 0 = rosa, 1 = celeste, 2 = azul (como en la máscara).
const NEON_TUBES := [
	[Vector2(79, 46), Vector2(79, 128), Color(1.0, 0.25, 0.75), 0],
	[Vector2(79, 45), Vector2(121, 63), Color(1.0, 0.25, 0.75), 0],
	[Vector2(216, 85), Vector2(276, 85), Color(1.0, 0.25, 0.75), 0],
	[Vector2(357, 40), Vector2(391, 20), Color(0.2, 0.85, 1.0), 1],
	[Vector2(289, 85), Vector2(306, 77), Color(0.2, 0.85, 1.0), 1],
	[Vector2(0, 135), Vector2(28, 135), Color(0.2, 0.85, 1.0), 1],
	[Vector2(190, 90), Vector2(204, 101), Color(0.3, 0.45, 1.0), 2],
]
## Lámparas principales: foco y ancho del cono de luz al llegar al piso.
const LAMPS := [[Vector2(237, 46), 70.0], [Vector2(160, 73), 45.0], [Vector2(320, 73), 45.0]]

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _logo_on := 0.0  ## Encendido del neón del logo (0 a 1) durante la intro.
var _like_on := 0.0
var _flicker_pink := 1.0
var _flicker_cyan := 1.0
var _next_flicker := 3.0
var _neon := Vector3.ONE  ## Neón del fondo: rosa, celeste, azul.
var _next_bg_flicker := 2.0
var _dust: Array = []
var _buttons: Array[Button] = []
var _busy := false

var _bg := TextureRect.new()
var _bg_mat := ShaderMaterial.new()
var _logo_glow_p := TextureRect.new()
var _logo_glow_c := TextureRect.new()
var _logo_fichin := TextureRect.new()
var _logo_like := TextureRect.new()
var _fade := ColorRect.new()
var _save_label := UiTheme.label("", GameFonts.BODY_SIZE, UiTheme.MUTED)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Fondo animado.
	_bg.texture = Art.tex(ART + "arcade_bg.png")
	_bg.size = BG_SIZE * BG_SCALE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat.shader = load("res://assets/shaders/arcade_bg.gdshader")
	_bg_mat.set_shader_parameter("fx", Art.tex(ART + "arcade_fx.png"))
	_bg_mat.set_shader_parameter("tex_size", BG_SIZE)
	_bg.material = _bg_mat
	add_child(_bg)

	# Halos del neón y polvo, en píxeles del fondo.
	var fx := BackFx.new()
	fx.owner_screen = self
	fx.scale = Vector2.ONE * BG_SCALE
	fx.material = add_mat
	add_child(fx)

	# Sombra del lado del menú para que se lea.
	add_child(_shade())

	# Cartel de neón del logo.
	var logo_pos := Vector2(26, 0)
	for pair in [[_logo_glow_p, "logo_glow_pink.png"], [_logo_glow_c, "logo_glow_cyan.png"], [_logo_fichin, "logo_fichin.png"], [_logo_like, "logo_like.png"]]:
		var tr: TextureRect = pair[0]
		tr.texture = Art.tex(ART + pair[1])
		tr.position = logo_pos
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
	_logo_glow_p.material = add_mat
	_logo_glow_c.material = add_mat

	_build_menu()

	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	for i in 60:
		_dust.append(_new_mote(true))
	_intro()


## Degradé oscuro de izquierda a derecha detrás del logo y los botones.
func _shade() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.01, 0.06, 0.86))
	g.set_color(1, Color(0.03, 0.01, 0.06, 0.0))
	g.add_point(0.32, Color(0.03, 0.01, 0.06, 0.62))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.62, 0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.size = UiTheme.SCREEN
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# --- Menú ---------------------------------------------------------------------------

func _build_menu() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.position = Vector2(60, 236)
	box.custom_minimum_size = Vector2(290, 0)
	add_child(box)

	var has_save := SaveGame.exists()
	var entries := [["NUEVA PARTIDA", "new"], ["CONTINUAR", "continue"], ["SALIR", "quit"]]
	for e in entries:
		var b := Button.new()
		b.text = e[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(290, 40)
		b.add_theme_font_override("font", GameFonts.body())
		b.add_theme_font_size_override("font_size", GameFonts.BODY_SIZE)
		b.add_theme_color_override("font_color", UiTheme.TEXT)
		b.add_theme_color_override("font_hover_color", UiTheme.TEXT)
		b.add_theme_color_override("font_focus_color", UiTheme.BG)
		b.add_theme_color_override("font_hover_pressed_color", UiTheme.BG)
		b.add_theme_color_override("font_pressed_color", UiTheme.BG)
		b.add_theme_color_override("font_disabled_color", Color(UiTheme.MUTED, 0.45))
		b.add_theme_stylebox_override("normal", _menu_box(Color(UiTheme.BG, 0.55), Color(UiTheme.BORDER, 0.9)))
		b.add_theme_stylebox_override("hover", _menu_box(Color(UiTheme.PANEL, 0.85), UiTheme.PINK))
		b.add_theme_stylebox_override("focus", _menu_box(UiTheme.ACCENT, UiTheme.TEXT))
		b.add_theme_stylebox_override("pressed", _menu_box(UiTheme.PINK, UiTheme.TEXT))
		b.add_theme_stylebox_override("disabled", _menu_box(Color(UiTheme.BG, 0.35), Color(UiTheme.BORDER, 0.4)))
		b.focus_entered.connect(_on_focus)
		b.pressed.connect(_on_pressed.bind(e[1]))
		if e[1] == "continue" and not has_save:
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
		box.add_child(b)
		_buttons.append(b)

	_save_label.custom_minimum_size = Vector2(290, 0)
	_save_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_save_label.add_theme_constant_override("outline_size", 2)
	_save_label.text = SaveGame.summary() if has_save else "Sin partida guardada"
	box.add_child(_save_label)

	var version := UiTheme.label(VERSION, GameFonts.BODY_SIZE, UiTheme.MUTED)
	version.position = Vector2(12, 506)
	add_child(version)
	var hint := UiTheme.label("Cruz / Espacio: elegir · F11: pantalla completa", GameFonts.BODY_SIZE, UiTheme.MUTED)
	hint.custom_minimum_size = Vector2(600, 0)
	hint.position = Vector2(UiTheme.SCREEN.x - 612, 506)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 2)
	add_child(hint)


func _menu_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_offset = Vector2(2, 2)
	sb.anti_aliasing = false
	return sb


func _on_focus() -> void:
	if _logo_on >= 1.0:
		Sfx.play("post", 0.5)


func _on_pressed(action: String) -> void:
	if _busy:
		return
	_busy = true
	Sfx.play("launch", 0.8)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	await tw.finished
	chosen.emit(action)


func _intro() -> void:
	for b in _buttons:
		b.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	await get_tree().create_timer(0.5).timeout
	# El neón prende con un par de chispazos.
	for v in [1.0, 0.0, 1.0, 0.2, 1.0]:
		_logo_on = v
		if v > 0.5:
			Sfx.play("post", 0.35, 0.2)
		await get_tree().create_timer(0.07 + _rng.randf() * 0.08).timeout
	await get_tree().create_timer(0.25).timeout
	for v in [1.0, 0.0, 1.0]:
		_like_on = v
		await get_tree().create_timer(0.08).timeout
	var tw2 := create_tween().set_parallel()
	for b in _buttons:
		tw2.tween_property(b, "modulate:a", 1.0, 0.3)
	var first: Button = _buttons[1] if not _buttons[1].disabled else _buttons[0]
	first.grab_focus()


# --- Animación ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	# Parpadeos al azar del logo.
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_next_flicker = _rng.randf_range(3.0, 7.0)
		_flicker(_rng.randf() < 0.6)
	# Parpadeos al azar de un tubo del fondo.
	_next_bg_flicker -= delta
	if _next_bg_flicker <= 0.0:
		_next_bg_flicker = _rng.randf_range(1.5, 5.0)
		_flicker_bg(_rng.randi_range(0, 2))
	var pulse := 0.88 + 0.12 * sin(_t * 2.3)
	var pink := _logo_on * _flicker_pink
	var cyan := _like_on * _flicker_cyan
	_logo_glow_p.modulate.a = pink * pulse
	_logo_glow_c.modulate.a = cyan * pulse
	_logo_fichin.modulate = Color(1, 1, 1).lerp(Color(0.3, 0.25, 0.35), 1.0 - pink)
	_logo_like.modulate = Color(1, 1, 1).lerp(Color(0.3, 0.25, 0.35), 1.0 - cyan)
	_bg_mat.set_shader_parameter("time", _t)
	_bg_mat.set_shader_parameter("neon", _neon)
	# Polvo.
	for m in _dust:
		m.pos += m.vel * delta
		m.life -= delta
		if m.life <= 0.0 or m.pos.y > 235.0:
			var n := _new_mote(false)
			m.pos = n.pos
			m.vel = n.vel
			m.life = n.life
			m.max_life = n.max_life


func _flicker(like_word: bool) -> void:
	for v in [0.15, 1.0, 0.3, 1.0]:
		if like_word:
			_flicker_cyan = v
		else:
			_flicker_pink = v
		await get_tree().create_timer(0.05 + _rng.randf() * 0.07).timeout


func _flicker_bg(group: int) -> void:
	var seq := [0.2, 1.0, 0.1, 0.8, 1.0] if _rng.randf() < 0.5 else [0.4, 1.0]
	for v in seq:
		_neon[group] = v
		await get_tree().create_timer(0.04 + _rng.randf() * 0.08).timeout


func _new_mote(anywhere: bool) -> Dictionary:
	var lamp: Array = LAMPS[_rng.randi_range(0, LAMPS.size() - 1)]
	var top: Vector2 = lamp[0]
	var y := _rng.randf_range(top.y + 6.0, 225.0) if anywhere else _rng.randf_range(top.y + 4.0, top.y + 30.0)
	var k := (y - top.y) / (230.0 - top.y)
	var spread: float = 6.0 + k * float(lamp[1])
	var life := _rng.randf_range(4.0, 9.0)
	return {
		"pos": Vector2(top.x + _rng.randf_range(-spread, spread), y),
		"vel": Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(1.0, 4.0)),
		"life": life, "max_life": life,
	}


## Halos del neón del fondo y polvo flotando en la luz de las lámparas.
## Se dibuja en píxeles del fondo (480 x 270) con mezcla aditiva.
class BackFx extends Control:
	var owner_screen: TitleScreen
	var _glow: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		_glow = gt
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var o := owner_screen
		for tube in TitleScreen.NEON_TUBES:
			var a: Vector2 = tube[0]
			var b: Vector2 = tube[1]
			var on: float = o._neon[tube[3]]
			var c: Color = tube[2]
			var steps := maxi(1, int(a.distance_to(b) / 6.0))
			for i in steps + 1:
				var p := a.lerp(b, float(i) / steps)
				draw_texture_rect(_glow, Rect2(p - Vector2(9, 9), Vector2(18, 18)), false, Color(c, 0.16 * on))
		for lamp in TitleScreen.LAMPS:
			var p: Vector2 = lamp[0]
			var k := 0.85 + 0.15 * sin(o._t * 5.0 + p.x)
			draw_texture_rect(_glow, Rect2(p - Vector2(22, 14), Vector2(44, 28)), false, Color(1.0, 0.6, 0.25, 0.22 * k))
		for m in o._dust:
			var k: float = sin(PI * m.life / m.max_life)
			draw_rect(Rect2(m.pos.floor(), Vector2.ONE), Color(1.0, 0.9, 0.65, 0.45 * k))
