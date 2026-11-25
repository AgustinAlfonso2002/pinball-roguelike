class_name Art
## Carga de imágenes del juego.
##
## Las texturas se crean desde la imagen importada (ImageTexture): se ven
## igual en el editor, en el juego exportado y en el renderizador por software
## que usa la autoprueba.

static var _cache := {}


static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var src: Texture2D = load(path)
	var img: Image = src.get_image() if src else null
	var t: Texture2D = ImageTexture.create_from_image(img) if img else src
	_cache[path] = t
	return t


## Material que dibuja pixel art nítido a cualquier escala (assets/shaders/sharp_pixels.gdshader).
## El nodo que lo use tiene que tener texture_filter = LINEAR.
static func sharp_material(tex_size: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/sharp_pixels.gdshader")
	m.set_shader_parameter("tex_size", tex_size)
	return m


static func json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
