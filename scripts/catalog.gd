class_name Catalog
## Carga todos los scripts .gd de una carpeta (objetos, rivales...).
## Funciona en el editor y en el juego exportado (donde los archivos
## aparecen como .gd.remap o .gdc).


static func load_scripts(dir: String) -> Array[Script]:
	var names := {}
	for file in DirAccess.get_files_at(dir):
		var name := file
		if name.ends_with(".remap"):
			name = name.trim_suffix(".remap")
		if name.ends_with(".gdc"):
			name = name.trim_suffix(".gdc") + ".gd"
		if name.ends_with(".gd"):
			names[name] = true
	var keys := names.keys()
	keys.sort()
	var scripts: Array[Script] = []
	for name in keys:
		var script := load(dir.path_join(name)) as Script
		if script:
			scripts.append(script)
	return scripts
