@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuicePositionShaker
extends JuiceTransformShaker
## Shakes the position of a [Node2D], [Node3D] or [Control].
##
## Listens to [code]juice_position_shake[/code], sent by [JuicePositionShake]. The offset
## is added to [code]position[/code] and removed again after the shake, so other movement
## of the node keeps working. Amplitude is in pixels or units along [member direction].
##
## Event [code]juice_position_shake[/code] payload keys: see [JuiceTransformShaker].

const EVENT := &"juice_position_shake"


func _init() -> void:
	shake_duration = 0.5
	amplitude = 8.0
	direction = Vector3(1.0, 1.0, 0.0)


func _get_events() -> Array[StringName]:
	return [EVENT]


func _get_property(node: Node) -> String:
	if node is Node2D or node is Control or node is Node3D:
		return "position"
	return ""


func _convert(node: Node, offset: Vector3) -> Variant:
	if node is Node3D:
		return offset
	return Vector2(offset.x, offset.y)
