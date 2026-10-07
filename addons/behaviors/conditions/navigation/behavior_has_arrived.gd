@tool
@icon("res://addons/behaviors/icons/navigation.svg")
class_name BehaviorHasArrived
extends BehaviorCondition
## Succeeds when the actor is within a distance of a target position.
##
## With [member use_navigation_agent] it checks the navigation agent's own target
## instead, and the actor has arrived when the agent has no path left. In 3D the
## height is ignored.

## The node or position to check. Bind it to a variable holding a node, a Vector2 or a
## Vector3.
@export var target: Variant = null
## A node to use when [member target] is empty, relative to the actor.
@export var target_path: NodePath = NodePath()
## How close counts as arrived, in world units.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:units") var distance: float = 0.5
## Asks the navigation agent whether its navigation is finished, and ignores the
## target.
@export var use_navigation_agent: bool = false
## The navigation agent, relative to the actor. Empty uses the first navigation agent
## among the actor's children.
@export var navigation_agent: NodePath = NodePath()


func _on_update(_delta: float) -> Status:
	if use_navigation_agent:
		var agent_node := BehaviorSpace.find_navigation_agent(self, navigation_agent)
		if agent_node == null:
			return Status.FAILURE
		return Status.SUCCESS if agent_node.is_navigation_finished() else Status.FAILURE
	var position: Variant = BehaviorSpace.resolve_position(self, target, target_path)
	if position == null:
		return Status.FAILURE
	var flat := actor is Node3D
	return Status.SUCCESS if BehaviorSpace.distance_between(BehaviorSpace.get_position(actor), position, flat) <= distance else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not use_navigation_agent and target_path.is_empty() and not bindings.has(&"target") and target == null:
		warnings.append("Has Arrived needs a target: bind \"target\" or set a target path.")
	return warnings
