extends TableModule
## Banco de 3 dianas: al bajar las tres, +1 al multiplicador de la bola.

const SPACING := 34.0


func _init() -> void:
	id = &"banco_dianas"
	display_name = "Banco de dianas"
	sizes = ["M"]
	weight = 1.2
	events = {
		&"target": {"text": "Bajá dianas", "goal": 9},
		&"bank": {"text": "Completá el banco de dianas", "goal": 2, "big": true},
	}


func build() -> void:
	for i in [-1, 0, 1]:
		var t := table.add_target(center() + Vector2(i * SPACING, 0) * Geom.S)
		t.set_meta("module", self)
