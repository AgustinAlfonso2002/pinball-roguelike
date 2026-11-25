class_name GameFonts
## Fuentes pixel del juego (licencia OFL, ver assets/fonts/OFL-*.txt).
##
## Se cargan en tiempo de ejecución desde el .ttf (importado como "keep") con
## suavizado y hinting apagados: así se dibujan nítidas, píxel por píxel.
## Usar siempre estos tamaños, que coinciden con la grilla de cada fuente.

## Cada fuente tiene una grilla de píxeles propia (unidades por em / tamaño de
## un pixel del diseño). Solo en múltiplos exactos de esa grilla cada pixel de
## la letra cae entero en la pantalla; en otros tamaños se pierden líneas
## (por ejemplo, la barra de la "e"). Grillas: Jersey 15 = 27, Jersey 10 =
## 18,67 (entero recién en 56), Micro 5 = 11.
##
## Interfaz (960 x 540, cada unidad = 2 píxeles de pantalla):
const BODY_SIZE := 27  ## Textos generales (Jersey 15 a 1x).
const TITLE_SIZE := 56  ## Títulos (Jersey 10 a 3x).
const HUGE_SIZE := 54  ## Puntaje grande (Jersey 15 a 2x).
## Mesa (640 x 360, cada unidad = 3 píxeles de pantalla):
const SMALL_SIZE := 11  ## Puntos flotantes (Micro 5 a 1x).
const WORLD_BIG := 22  ## Carteles sobre la mesa (Micro 5 a 2x).

static var _cache := {}


static func body() -> FontFile:
	return _load("Jersey15-Regular.ttf")


static func title() -> FontFile:
	return _load("Jersey10-Regular.ttf")


static func small() -> FontFile:
	return _load("Micro5-Regular.ttf")


## Fuente para un tamaño de la lista de arriba (o un múltiplo de su grilla).
static func for_size(size: int) -> FontFile:
	if size % 27 == 0:
		return body()
	if size % 56 == 0:
		return title()
	if size % 11 == 0:
		return small()
	push_warning("GameFonts: el tamaño %d no coincide con la grilla de ninguna fuente" % size)
	return body()


static func _load(file: String) -> FontFile:
	if _cache.has(file):
		return _cache[file]
	var f := FontFile.new()
	f.data = FileAccess.get_file_as_bytes("res://assets/fonts/" + file)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.allow_system_fallback = false
	_cache[file] = f
	return f
