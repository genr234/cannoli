@tool
@icon("res://addons/behaviors/icons/area.svg")
class_name BehaviorHasEnteredArea
extends BehaviorAreaCondition
## Succeeds once after a body or an area has entered an [Area2D] or [Area3D].
##
## Put it under a composite with a conditional abort to react the moment something
## enters.


func _get_graph_text() -> String:
	return String(group)
