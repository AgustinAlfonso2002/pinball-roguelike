class_name SaveGame
## Partida guardada (un solo espacio), en user://partida.json.
##
## Se guarda sola al empezar cada partida/duelo y al entrar a la tienda.
## "Continuar" retoma desde ese punto. Se borra al perder la run.

const PATH := "user://partida.json"


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


## phase: "stage" (empezar la etapa actual) o "shop" (entrar a la tienda).
static func save(phase: String) -> void:
	var d := Run.to_dict()
	d["phase"] = phase
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


## Carga la partida en Run. Devuelve la fase ("stage"/"shop") o "" si falló.
static func load_run() -> String:
	var d = _read()
	if d == null:
		return ""
	Run.from_dict(d)
	return String(d.get("phase", "stage"))


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)


## Texto corto para el menú: "Noche 3 · Partida 2 de 2 · 14 fichas".
static func summary() -> String:
	var d = _read()
	if d == null:
		return ""
	var n := int(d.get("night", 1))
	var st := int(d.get("stage", 0))
	var where := ("Tienda (noche %d)" % n) if String(d.get("phase", "")) == "shop" else (
			("Noche %d · Duelo" % n) if st == Run.DUEL_STAGE else ("Noche %d · Partida %d de 2" % [n, st + 1]))
	return "%s · %d fichas" % [where, int(d.get("coins", 0))]


static func _read():
	if not exists():
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if d is Dictionary else null
