class_name Ball
extends RigidBody2D
## La bola. Cuerpo rígido con detección continua de colisiones (CCD)
## para que no atraviese paredes cuando va muy rápido.
##
## Para "mover" la bola a otro lugar no se la teletransporta: Main crea una
## bola nueva (ver Main.spawn_ball). Teletransportar un cuerpo rígido en Godot
## arrastra contactos del lugar viejo y puede dejarlo del otro lado de una pared.

signal collided(other: Node)

const RADIUS := 8.0

var _material := PhysicsMaterial.new()


func _init() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	mass = 1.0
	gravity_scale = 0.0  # La gravedad la aplicamos nosotros (ajustable en vivo).
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 6
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	physics_material_override = _material
	body_entered.connect(func(body: Node) -> void: collided.emit(body))


func _ready() -> void:
	Tuning.changed.connect(_apply_tuning)
	_apply_tuning()


func _apply_tuning() -> void:
	_material.bounce = Tuning.v("ball_bounce")
	_material.friction = Tuning.v("ball_friction")


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var vel := state.linear_velocity
	vel.y += Tuning.v("gravity") * state.step
	var max_speed := Tuning.v("max_ball_speed")
	if vel.length() > max_speed:
		vel = vel.normalized() * max_speed
	state.linear_velocity = vel


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# El brillo no gira con la bola.
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.80, 0.83, 0.92))
	draw_circle(Vector2(-2.5, -2.5), 3.0, Color(1, 1, 1, 0.9))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color(0.35, 0.38, 0.5), 1.0)
