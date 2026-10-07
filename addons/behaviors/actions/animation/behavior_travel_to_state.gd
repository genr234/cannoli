@tool
@icon("res://addons/behaviors/icons/animation.svg")
class_name BehaviorTravelToState
extends BehaviorAction
## Moves an AnimationTree state machine to a state. Fails when the tree or the state
## machine is missing.

## The AnimationTree, relative to the actor.
@export var tree: NodePath = NodePath()
## A variable holding the AnimationTree. Replaces [member tree] when set.
@export var tree_variable: String = ""
## The parameter that holds the state machine playback.
@export var playback_path: String = "parameters/playback"
## The state to go to.
@export var state: StringName = &""
## Jumps straight to the state instead of following the transitions.
@export var jump: bool = false
## Keeps running until the state machine is in the state.
@export var wait_until_reached: bool = false

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")

var _playback: AnimationNodeStateMachinePlayback


func _on_start() -> void:
	var animation_tree := Targets.resolve(self, tree, tree_variable) as AnimationTree
	_playback = null
	if animation_tree == null or not playback_path in animation_tree:
		Targets.warn_once(self, "no AnimationTree with \"%s\"." % playback_path)
		return
	_playback = animation_tree.get(playback_path) as AnimationNodeStateMachinePlayback
	if _playback == null:
		return
	if jump:
		_playback.start(state)
	else:
		_playback.travel(state)


func _on_update(_delta: float) -> Status:
	if _playback == null:
		return Status.FAILURE
	if wait_until_reached and _playback.get_current_node() != state:
		return Status.RUNNING
	return Status.SUCCESS


func _on_end() -> void:
	_playback = null


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(state).is_empty():
		warnings.append("Travel To State has no state.")
	return warnings


func _get_graph_text() -> String:
	return String(state)
