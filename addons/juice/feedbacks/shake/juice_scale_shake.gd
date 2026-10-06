@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuiceScaleShake
extends JuiceNodeShake
## Shakes the scale of the nodes that have a [JuiceScaleShaker] on the same channel.
##
## Broadcasts [code]juice_scale_shake[/code]. Payload keys: see [JuiceTransformShaker].


func _init() -> void:
	duration = 0.5
	amplitude = 0.2
	direction = Vector3.ONE
	alt_direction = Vector3.ZERO
	normalize_direction = false
	directional_noise = 0.0


func _get_event() -> StringName:
	return JuiceScaleShaker.EVENT
