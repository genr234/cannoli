@tool
@icon("res://addons/behaviors/icons/audio.svg")
class_name BehaviorPlaySound
extends BehaviorAction
## Plays an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D. Fails when
## the player is missing.

## The audio player, relative to the actor.
@export var player: NodePath = NodePath()
## A variable holding the audio player. Replaces [member player] when set.
@export var player_variable: String = ""
## Plays this stream instead of the one on the player.
@export var stream: AudioStream
## Picks a random pitch scale in [member pitch_range] each time.
@export var randomize_pitch: bool = false
## The lowest and highest pitch scale for [member randomize_pitch].
@export var pitch_range: Vector2 = Vector2(0.9, 1.1)
## Picks a random volume in [member volume_range] each time.
@export var randomize_volume: bool = false
## The lowest and highest volume in decibels for [member randomize_volume].
@export var volume_range: Vector2 = Vector2(-3.0, 0.0)
## Keeps running until the sound stops playing. A looping sound never stops.
@export var wait_for_finish: bool = false

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")

var _player: Node


func _on_start() -> void:
	_player = Targets.resolve(self, player, player_variable) as Node
	if _player == null or not Targets.is_audio_player(_player):
		Targets.warn_once(self, "no audio player found.")
		_player = null
		return
	if stream:
		_player.stream = stream
	if randomize_pitch:
		_player.pitch_scale = randf_range(minf(pitch_range.x, pitch_range.y), maxf(pitch_range.x, pitch_range.y))
	if randomize_volume:
		_player.volume_db = randf_range(minf(volume_range.x, volume_range.y), maxf(volume_range.x, volume_range.y))
	_player.play()


func _on_update(_delta: float) -> Status:
	if _player == null or not is_instance_valid(_player):
		return Status.FAILURE
	if wait_for_finish and _player.playing:
		return Status.RUNNING
	return Status.SUCCESS


func _on_end() -> void:
	_player = null


func _get_graph_text() -> String:
	return stream.resource_path.get_file() if stream else "play"
