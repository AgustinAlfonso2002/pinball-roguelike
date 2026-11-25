extends TableModule
## Muro de ladrillos que se rompen. Los de arriba aguantan dos golpes.
## Cada ladrillo vuelve a aparecer al rato; si rompés el muro entero:
## bonus grande y +1 al multiplicador de la bola (como el banco de dianas),
## y el muro se reconstruye en cascada.

const COLS := 4
const ROWS := 2
const BRICK := Vector2(28, 12)
const GAP := 4.0
const BRICK_POINTS := 60.0
const RESPAWN := 9.0

var _bricks: Array = []
var _rebuilding := false


func _init() -> void:
	id = &"ladrillos"
	display_name = "Muro de ladrillos"
	sizes = ["M"]
	weight = 1.0
	events = {
		&"brick": {"text": "Rompé ladrillos", "goal": 16},
		&"wall": {"text": "Rompé el muro entero", "goal": 1, "big": true},
	}


func build() -> void:
	var size := BRICK * Geom.S
	var total := Vector2(COLS * BRICK.x + (COLS - 1) * GAP, ROWS * BRICK.y + (ROWS - 1) * GAP) * Geom.S
	var origin := center() - total * 0.5
	for row in ROWS:
		for col in COLS:
			var b := Brick.new()
			b.module = self
			b.max_hp = 2 if row == 0 else 1
			b.size = size
			b.position = origin + Vector2(col * (BRICK.x + GAP), row * (BRICK.y + GAP)) * Geom.S + size * 0.5
			table.add_child(b)
			b.restore(false)
			_bricks.append(b)


func on_brick_broken(b: Brick) -> void:
	score(&"brick", BRICK_POINTS, b.global_position)
	event(&"brick", b.global_position)
	TableFx.burst(table, b.global_position, b.color(), 12, 110.0)
	table.rumble(0.25, 0.15, 0.06)
	for other in _bricks:
		if other.alive:
			b.respawn_at = RESPAWN
			return
	# ¡Muro entero!
	_rebuilding = true
	for other in _bricks:
		other.respawn_at = -1.0
	Sfx.play("bank_complete", 1.0, 0.0)
	table.hitstop(1.2)
	table.start_shake(0.25)
	TableFx.ring(table, center(), Color(1.0, 0.8, 0.4), u(70), 0.5)
	score(&"bank", Run.stat(&"bank_bonus"), center() + Vector2(0, -8))
	event(&"wall", center())
	table.bank_completed.emit()
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	for other in _bricks:
		while _ball_overlaps(other):
			await get_tree().create_timer(0.2).timeout
			if not is_inside_tree():
				return
		other.restore(true)
		await get_tree().create_timer(0.08).timeout
		if not is_inside_tree():
			return
	_rebuilding = false


func _physics_process(delta: float) -> void:
	if _rebuilding:
		return
	for b in _bricks:
		if not b.alive and b.respawn_at > 0.0:
			b.respawn_at -= delta
			if b.respawn_at <= 0.0:
				if _ball_overlaps(b):
					b.respawn_at = 0.3
				else:
					b.restore(true)


func _ball_overlaps(b: Brick) -> bool:
	var ball := table.ball
	if not ball:
		return false
	var r := Rect2(b.global_position - b.size * 0.5, b.size).grow(Ball.RADIUS + 1.0)
	return r.has_point(ball.global_position)


## Un ladrillo: cuerpo estático que se apaga al romperse.
class Brick extends StaticBody2D:
	var module
	var max_hp := 1
	var hp := 1
	var size := Vector2.ONE
	var alive := true
	var respawn_at := -1.0
	var _shape := CollisionShape2D.new()
	var _flash := 0.0
	var _pop := 0.0

	func _ready() -> void:
		var rect := RectangleShape2D.new()
		rect.size = size
		_shape.shape = rect
		add_child(_shape)
		var mat := PhysicsMaterial.new()
		mat.bounce = 0.55
		physics_material_override = mat

	func color() -> Color:
		return Color(1.0, 0.55, 0.3) if max_hp > 1 else Color(1.0, 0.8, 0.35)

	func restore(animated: bool) -> void:
		alive = true
		hp = max_hp
		respawn_at = -1.0
		_shape.set_deferred("disabled", false)
		_pop = 1.0 if animated else 0.0
		if animated and module:
			TableFx.ring(module.table, global_position, color(), 10.0, 0.25)

	func ball_hit(_ball: Ball) -> void:
		_hurt()

	## Onda de la catapulta: rompe el ladrillo de una.
	func shock() -> void:
		hp = 1
		_hurt()

	func _hurt() -> void:
		if not alive:
			return
		hp -= 1
		_flash = 1.0
		if hp > 0:
			Sfx.play("target", 0.6)
			return
		alive = false
		_shape.set_deferred("disabled", true)
		Sfx.play("target", 1.0)
		module.on_brick_broken(self)

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta * 6.0)
		_pop = maxf(0.0, _pop - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		if not alive:
			draw_rect(Rect2(-size * 0.5, size), Color(color(), 0.12), false, 1.0)
			return
		var s := size * (1.0 + 0.3 * _pop)
		var base := color().darkened(0.25 if hp < max_hp else 0.0)
		draw_rect(Rect2(-s * 0.5, s), base.lerp(Color.WHITE, _flash))
		draw_rect(Rect2(-s * 0.5, s), base.darkened(0.5), false, 1.0)
		if hp < max_hp:
			# Rajadura.
			draw_line(Vector2(-s.x * 0.2, -s.y * 0.5), Vector2(0, 0), Color(0.2, 0.1, 0.05), 1.0)
			draw_line(Vector2(0, 0), Vector2(s.x * 0.15, s.y * 0.5), Color(0.2, 0.1, 0.05), 1.0)
