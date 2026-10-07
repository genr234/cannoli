@tool
@icon("res://addons/behaviors/icons/navigation.svg")
class_name BehaviorSetNavigationTarget
extends BehaviorAction
## Gives the actor's navigation agent a new target position and succeeds at once.
##
## Fails when there is no navigation agent or no target. The actor does not move by
## itself: use this with your own movement code, or use [BehaviorMoveTo] to also walk.

## The node or position to go to. Bind it to a variable holding a node, a Vector2 or a
## Vector3.
@export var target: Variant = null
## A node to use when [member target] is empty, relative to the actor.
@export var target_path: NodePath = NodePath()
## The navigation agent, relative to the actor. Empty uses the first navigation agent
## among the actor's children.
@export var navigation_agent: NodePath = NodePath()


func _on_update(_delta: float) -> Status:
	var agent_node := BehaviorSpace.find_navigation_agent(self, navigation_agent)
	var position: Variant = BehaviorSpace.resolve_position(self, target, target_path)
	if agent_node == null or position == null:
		return Status.FAILURE
	agent_node.target_position = position
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_path.is_empty() and not bindings.has(&"target") and target == null:
		warnings.append("Set Navigation Target needs a target: bind \"target\" or set a target path.")
	return warnings
