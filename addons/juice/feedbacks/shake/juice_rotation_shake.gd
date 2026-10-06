@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuiceRotationShake
extends JuiceNodeShake
## Shakes the rotation of the nodes that have a [JuiceRotationShaker] on the same channel.
##
## The amplitude is in degrees. Broadcasts [code]juice_rotation_shake[/code]. Payload keys: see
## [JuiceTransformShaker].


func _init() -> void:
	duration = 0.5
	amplitude = 10.0
	direction = Vector3(0.0, 0.0, 1.0)
	alt_direction = Vector3(0.0, 0.0, -1.0)


func _get_event() -> StringName:
	return JuiceRotationShaker.EVENT
