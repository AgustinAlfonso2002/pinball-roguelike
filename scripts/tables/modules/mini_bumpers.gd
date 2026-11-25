extends TableModule
## Par de bumpers chicos: entran en lugares chicos y hacen rebotar la bola
## entre ellos como un flipper loco.

const RADIUS := 12.0
const OFFSETS := [Vector2(-15, -10), Vector2(15, 10)]


func _init() -> void:
	id = &"mini_bumpers"
	display_name = "Mini bumpers"
	sizes = ["S"]
	weight = 1.0
	events = {&"mini": {"text": "Golpeá los mini bumpers", "goal": 15}}


func build() -> void:
	var flip := 1.0 if rng.randf() < 0.5 else -1.0
	for off in OFFSETS:
		var b := table.add_bumper(center() + Vector2(off.x * flip, off.y) * Geom.S, u(RADIUS))
		b.set_meta("module", self)
		b.set_meta("event", &"mini")
