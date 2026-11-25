class_name HitEvent
extends RefCounted
## Un golpe que da puntos (bumper, slingshot, diana, bonus...).
##
## Antes de sumarse, pasa por todos los objetos (Item.on_hit), que pueden
## modificar sus valores. Puntaje final:
##     base × (multiplicador de la bola + mult_add) × xmult

var source: StringName  ## &"bumper", &"sling", &"target", &"bank", &"post"
var base := 0.0  ## Puntos base del golpe.
var mult_add := 0.0  ## Suma al multiplicador (ej.: +1).
var xmult := 1.0  ## Multiplica el total (ej.: ×1,5).
var position := Vector2.ZERO
var node: Node = null


func _init(p_source: StringName, p_base: float, p_position: Vector2, p_node: Node = null) -> void:
	source = p_source
	base = p_base
	position = p_position
	node = p_node


func total(ball_multiplier: float) -> float:
	return base * (ball_multiplier + mult_add) * xmult
