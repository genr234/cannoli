@tool
@icon("res://addons/behaviors/icons/start_tree.svg")
class_name BehaviorStartTree
extends BehaviorAction
## Starts another agent's tree, and succeeds once it started or, with
## [member wait_for_completion], once it finished.

## The agent to start, or a node with agents, relative to the actor.
@export var target: NodePath = NodePath()
## Keeps running until the started tree finishes.
@export var wait_for_completion: bool = false
## Copies this agent's variables into the started agent first.
@export var synchronize_variables: bool = false

var _target_agent: BehaviorAgent
var _complete: bool = false


func _on_start() -> void:
	_complete = false
	var agents := Behaviors.get_agents(get_node_from_actor(target))
	_target_agent = agents[0] if not agents.is_empty() else null
	if _target_agent == null:
		return
	if synchronize_variables and blackboard:
		for variable in blackboard.get_names():
			_target_agent.set_variable(variable, blackboard.get_value(variable))
	if wait_for_completion:
		_target_agent.finished.connect(_on_target_finished, CONNECT_ONE_SHOT)
	_target_agent.start()


func _on_update(_delta: float) -> Status:
	if _target_agent == null:
		return Status.FAILURE
	if wait_for_completion and not _complete:
		return Status.RUNNING
	return Status.SUCCESS


func _on_end() -> void:
	if is_instance_valid(_target_agent) and _target_agent.finished.is_connected(_on_target_finished):
		_target_agent.finished.disconnect(_on_target_finished)
	_target_agent = null


func _on_target_finished(_status: Status) -> void:
	_complete = true
