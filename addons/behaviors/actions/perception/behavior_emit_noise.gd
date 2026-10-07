@tool
@icon("res://addons/behaviors/icons/ear.svg")
class_name BehaviorEmitNoise
extends BehaviorAction
## Makes a noise at the actor's position that [BehaviorCanHear] conditions can hear.
##
## Succeeds at once.

## How far the noise carries, in world units.
@export_range(0.0, 10000.0, 0.01, "or_greater", "suffix:units") var radius: float = 10.0
## A label that [BehaviorCanHear] can filter by.
@export var tag: StringName = &""


func _on_update(_delta: float) -> Status:
	var position: Variant = BehaviorSpace.get_position(actor)
	if position == null:
		return Status.FAILURE
	Behaviors.emit_noise(actor, position, radius, tag)
	return Status.SUCCESS


func _get_graph_text() -> String:
	return "%s u" % radius
