@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuiceScaleShaker
extends JuiceTransformShaker
## Shakes the scale of a [Node2D], [Node3D] or [Control].
##
## Listens to [code]juice_scale_shake[/code], sent by [JuiceScaleShake]. The amplitude is
## added to the scale, so 0.2 swings between 0.8 and 1.2 times the rest scale. The direction
## is not normalized by default, so every axis gets the full amplitude.
##
## Event [code]juice_scale_shake[/code] payload keys: see [JuiceTransformShaker].

const EVENT := &"juice_scale_shake"


func _init() -> void:
	shake_duration = 0.5
	amplitude = 0.2
	direction = Vector3.ONE
	alt_direction = Vector3.ZERO
	normalize_direction = false
	directional_noise = 0.0


func _get_events() -> Array[StringName]:
	return [EVENT]


func _get_property(node: Node) -> String:
	if node is Node2D or node is Control or node is Node3D:
		return "scale"
	return ""


func _convert(node: Node, offset: Vector3) -> Variant:
	if node is Node3D:
		return offset
	return Vector2(offset.x, offset.y)
