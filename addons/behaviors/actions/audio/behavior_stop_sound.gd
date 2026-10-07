@tool
@icon("res://addons/behaviors/icons/audio.svg")
class_name BehaviorStopSound
extends BehaviorAction
## Stops an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D. Fails when
## the player is missing.

## The audio player, relative to the actor.
@export var player: NodePath = NodePath()
## A variable holding the audio player. Replaces [member player] when set.
@export var player_variable: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var audio := Targets.resolve(self, player, player_variable)
	if audio == null or not Targets.is_audio_player(audio):
		return Status.FAILURE
	audio.stop()
	return Status.SUCCESS


func _get_graph_text() -> String:
	return "stop"
