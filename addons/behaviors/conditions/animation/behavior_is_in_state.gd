@tool
@icon("res://addons/behaviors/icons/animation.svg")
class_name BehaviorIsInState
extends BehaviorCondition
## Succeeds when an AnimationTree state machine is in a state.

## The AnimationTree, relative to the actor.
@export var tree: NodePath = NodePath()
## A variable holding the AnimationTree. Replaces [member tree] when set.
@export var tree_variable: String = ""
## The parameter that holds the state machine playback.
@export var playback_path: String = "parameters/playback"
## The state to check.
@export var state: StringName = &""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var animation_tree := Targets.resolve(self, tree, tree_variable) as AnimationTree
	if animation_tree == null or not playback_path in animation_tree:
		return Status.FAILURE
	var playback := animation_tree.get(playback_path) as AnimationNodeStateMachinePlayback
	if playback == null:
		return Status.FAILURE
	return Status.SUCCESS if playback.get_current_node() == state else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(state).is_empty():
		warnings.append("Is In State has no state.")
	return warnings


func _get_graph_text() -> String:
	return String(state)
