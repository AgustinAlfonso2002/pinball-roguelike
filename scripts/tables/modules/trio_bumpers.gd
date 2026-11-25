extends TableModule
## Tres bumpers en triángulo: la pieza clásica que reparte la bola.

const OFFSETS := [Vector2(-55, -40), Vector2(55, -40), Vector2(0, 50)]


func _init() -> void:
	id = &"trio_bumpers"
	display_name = "Trío de bumpers"
	sizes = ["L"]
	core = true
	weight = 1.2
	events = {&"bumper": {"text": "Golpeá bumpers", "goal": 25}}


func build() -> void:
	for off in OFFSETS:
		var b := table.add_bumper(center() + off * Geom.S)
		b.set_meta("module", self)
		b.set_meta("event", &"bumper")
