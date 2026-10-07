@tool
@icon("res://addons/behaviors/icons/animation.svg")
class_name BehaviorPlayAnimation
extends BehaviorAction
## Plays an animation on an AnimationPlayer. Fails when the player or the animation is
## missing.

## The AnimationPlayer, relative to the actor.
@export var player: NodePath = NodePath()
## A variable holding the AnimationPlayer. Replaces [member player] when set.
@export var player_variable: String = ""
## The animation to play.
@export var animation: StringName = &""
## The blend time in seconds. -1 uses the player's default.
@export_range(-1.0, 10.0, 0.01, "or_greater", "suffix:s") var custom_blend: float = -1.0
## The playback speed. Negative plays backwards.
@export_range(-4.0, 4.0, 0.01, "or_less", "or_greater") var speed: float = 1.0
## Starts at the end, so the animation plays backwards from there.
@export var from_end: bool = false
## Keeps running until the animation stops playing. An animation that loops never
## stops, and a different animation taking over fails the task.
@export var wait_for_finish: bool = false

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")

var _player: AnimationPlayer


func _on_start() -> void:
	_player = Targets.resolve(self, player, player_variable) as AnimationPlayer
	if _player == null or not _player.has_animation(animation):
		Targets.warn_once(self, "no AnimationPlayer with animation \"%s\"." % animation)
		_player = null
		return
	_player.play(animation, custom_blend, speed, from_end)


func _on_update(_delta: float) -> Status:
	if _player == null or not is_instance_valid(_player):
		return Status.FAILURE
	if not wait_for_finish:
		return Status.SUCCESS
	if _player.current_animation == animation and _player.is_playing():
		return Status.RUNNING
	# Finished animations clear current_animation or leave it stopped.
	if _player.is_playing():
		return Status.FAILURE
	return Status.SUCCESS


func _on_end() -> void:
	_player = null


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(animation).is_empty():
		warnings.append("Play Animation has no animation.")
	return warnings


func _get_graph_text() -> String:
	return String(animation)
