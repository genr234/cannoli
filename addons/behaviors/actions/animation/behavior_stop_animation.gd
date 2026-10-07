@tool
@icon("res://addons/behaviors/icons/animation.svg")
class_name BehaviorStopAnimation
extends BehaviorAction
## Stops or pauses an AnimationPlayer. Fails when the player is missing.

## The AnimationPlayer, relative to the actor.
@export var player: NodePath = NodePath()
## A variable holding the AnimationPlayer. Replaces [member player] when set.
@export var player_variable: String = ""
## Pauses instead of stopping, so playing again continues from here.
@export var pause: bool = false
## When stopping, goes back to the start instead of keeping the current pose.
@export var reset: bool = false

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var animation_player := Targets.resolve(self, player, player_variable) as AnimationPlayer
	if animation_player == null:
		return Status.FAILURE
	if pause:
		animation_player.pause()
	else:
		animation_player.stop(not reset)
	return Status.SUCCESS


func _get_graph_text() -> String:
	return "pause" if pause else "stop"
