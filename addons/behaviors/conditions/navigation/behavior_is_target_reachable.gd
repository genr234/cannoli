@tool
@icon("res://addons/behaviors/icons/navigation.svg")
class_name BehaviorIsTargetReachable
extends BehaviorCondition
## Succeeds when a navigation path leads to the target.
##
## Asks the navigation map of the actor's world, so the actor does not need a
## navigation agent and nothing is moved. The map must have been synchronized, which
## takes a physics frame after the scene loads.

## The node or position to reach. Bind it to a variable holding a node, a Vector2 or a
## Vector3.
@export var target: Variant = null
## A node to use when [member target] is empty, relative to the actor.
@export var target_path: NodePath = NodePath()
## How far from the target the path may end and still count as reaching it, in world
## units.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:units") var tolerance: float = 1.0


func _on_update(_delta: float) -> Status:
	var position: Variant = BehaviorSpace.resolve_position(self, target, target_path)
	if position == null:
		return Status.FAILURE
	return Status.SUCCESS if BehaviorSpace.is_reachable(actor, position, tolerance) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_path.is_empty() and not bindings.has(&"target") and target == null:
		warnings.append("Is Target Reachable needs a target: bind \"target\" or set a target path.")
	return warnings
