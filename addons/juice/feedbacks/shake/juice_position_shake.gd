@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuicePositionShake
extends JuiceNodeShake
## Shakes the position of the nodes that have a [JuicePositionShaker] on the same channel.
##
## Broadcasts [code]juice_position_shake[/code]. Payload keys: see [JuiceTransformShaker].


func _init() -> void:
	duration = 0.5
	amplitude = 8.0
	direction = Vector3(1.0, 1.0, 0.0)


func _get_event() -> StringName:
	return JuicePositionShaker.EVENT
