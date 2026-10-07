@tool
@icon("res://addons/behaviors/icons/floor.svg")
class_name BehaviorIsOnFloor
extends BehaviorCondition
## Succeeds when a [CharacterBody2D] or [CharacterBody3D] is standing on the floor.
##
## The result is from the body's last [code]move_and_slide()[/code]. Fails when the node is
## not a character body.

## The body, relative to the actor. Empty uses the actor.
@export var body_path: NodePath = NodePath()


func _on_update(_delta: float) -> Status:
	var body := get_node_from_actor(body_path)
	if body is CharacterBody2D:
		return Status.SUCCESS if (body as CharacterBody2D).is_on_floor() else Status.FAILURE
	if body is CharacterBody3D:
		return Status.SUCCESS if (body as CharacterBody3D).is_on_floor() else Status.FAILURE
	return Status.FAILURE
