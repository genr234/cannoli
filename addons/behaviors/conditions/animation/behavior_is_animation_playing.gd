@tool
@icon("res://addons/behaviors/icons/animation.svg")
class_name BehaviorIsAnimationPlaying
extends BehaviorCondition
## Succeeds when an AnimationPlayer is playing, optionally a specific animation.

## The AnimationPlayer, relative to the actor.
@export var player: NodePath = NodePath()
## A variable holding the AnimationPlayer. Replaces [member player] when set.
@export var player_variable: String = ""
## The animation that must be playing. Empty accepts any.
@export var animation: StringName = &""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var animation_player := Targets.resolve(self, player, player_variable) as AnimationPlayer
	if animation_player == null or not animation_player.is_playing():
		return Status.FAILURE
	if String(animation).is_empty() or animation_player.current_animation == animation:
		return Status.SUCCESS
	return Status.FAILURE


func _get_graph_text() -> String:
	return String(animation) if not String(animation).is_empty() else "any animation"
