@tool
@icon("res://addons/behaviors/icons/stop_tree.svg")
class_name BehaviorStopTree
extends BehaviorAction
## Stops or pauses another agent's tree, then succeeds.

## The agent to stop, or a node with agents, relative to the actor.
@export var target: NodePath = NodePath()
## Pauses instead of stopping, so starting it again resumes it.
@export var pause: bool = false


func _on_update(_delta: float) -> Status:
	var agents := Behaviors.get_agents(get_node_from_actor(target))
	if agents.is_empty():
		return Status.FAILURE
	var target_agent := agents[0]
	if target_agent == agent and not pause:
		target_agent.stop.call_deferred()
	else:
		target_agent.stop(pause)
	return Status.SUCCESS
