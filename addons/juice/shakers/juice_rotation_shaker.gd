@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuiceRotationShaker
extends JuiceTransformShaker
## Shakes the rotation of a [Node2D], [Node3D] or [Control].
##
## Listens to [code]juice_rotation_shake[/code], sent by [JuiceRotationShake]. The amplitude
## is in degrees. 2D nodes and controls turn around z, so the default direction is z.
##
## Event [code]juice_rotation_shake[/code] payload keys: see [JuiceTransformShaker].

const EVENT := &"juice_rotation_shake"


func _init() -> void:
	shake_duration = 0.5
	amplitude = 10.0
	direction = Vector3(0.0, 0.0, 1.0)
	alt_direction = Vector3(0.0, 0.0, -1.0)


func _get_events() -> Array[StringName]:
	return [EVENT]


func _get_property(node: Node) -> String:
	if node is Node2D or node is Control or node is Node3D:
		return "rotation"
	return ""


func _convert(node: Node, offset: Vector3) -> Variant:
	if node is Node3D:
		return Vector3(deg_to_rad(offset.x), deg_to_rad(offset.y), deg_to_rad(offset.z))
	return deg_to_rad(offset.z)
