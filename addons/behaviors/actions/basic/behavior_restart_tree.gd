@tool
@icon("res://addons/behaviors/icons/restart_tree.svg")
class_name BehaviorRestartTree
extends BehaviorAction
## Restarts an agent's tree from its root, then succeeds. Restarting this agent
## happens after the current tick.

## The agent to restart, or a node with agents, relative to the actor. Empty
## restarts this agent.
@export var target: NodePath = NodePath()


func _on_update(_delta: float) -> Status:
	var target_agent := agent
	if not target.is_empty():
		var agents := Behaviors.get_agents(get_node_from_actor(target))
		target_agent = agents[0] if not agents.is_empty() else null
	if target_agent == null:
		return Status.FAILURE
	if target_agent == agent:
		target_agent.restart.call_deferred()
	else:
		target_agent.restart()
	return Status.SUCCESS
