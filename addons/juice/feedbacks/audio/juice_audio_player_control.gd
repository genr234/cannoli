@tool
@icon("res://addons/juice/icons/sound.svg")
class_name JuiceAudioPlayerControl
extends JuiceFeedback
## Plays, pauses, resumes or stops an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D
## that is already in your scene.
##
## ONE_SHOT plays a copy of the player, so the original keeps going and the same player
## can overlap itself. Optionally the stream, volume and pitch are randomized before
## playing. Intensity scales the volume. Everything the feedback changed is put back on restore.

## What to do to the audio player.
enum Mode { PLAY, PAUSE, RESUME, STOP, ONE_SHOT }

@export_group("Audio Player")
## What to do to the audio player.
@export var mode: Mode = Mode.PLAY:
	set(value):
		mode = value
		notify_property_list_changed()
## Seconds into the sound to start from, for PLAY and ONE_SHOT.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var from_position: float = 0.0
## Streams to pick from at random instead of the player's own stream. Empty keeps the player's stream.
@export var random_streams: Array[AudioStream] = []
## Picks a random volume each play.
@export var randomize_volume: bool = false:
	set(value):
		randomize_volume = value
		notify_property_list_changed()
## The lowest random volume in decibels.
@export_range(-60.0, 24.0, 0.1, "suffix:dB") var min_volume_db: float = 0.0
## The highest random volume in decibels.
@export_range(-60.0, 24.0, 0.1, "suffix:dB") var max_volume_db: float = 0.0
## Picks a random pitch each play.
@export var randomize_pitch: bool = false:
	set(value):
		randomize_pitch = value
		notify_property_list_changed()
## The lowest random pitch scale.
@export_range(0.05, 4.0, 0.01) var min_pitch: float = 1.0
## The highest random pitch scale.
@export_range(0.05, 4.0, 0.01) var max_pitch: float = 1.0
## Lets intensity raise or lower the volume.
@export var scale_volume_with_intensity: bool = true
## Stops the player when this feedback is stopped. Only for PLAY and ONE_SHOT.
@export var stop_on_stop: bool = true

var _initial_stream: AudioStream
var _initial_volume := 0.0
var _initial_pitch := 1.0
var _initial_paused := false
var _clones: Array[Node] = []


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	var plays := mode == Mode.PLAY or mode == Mode.ONE_SHOT
	if prop_name in ["from_position", "random_streams", "randomize_volume", "randomize_pitch", "scale_volume_with_intensity", "stop_on_stop"] and not plays:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["min_volume_db", "max_volume_db"] and not (plays and randomize_volume):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["min_pitch", "max_pitch"] and not (plays and randomize_pitch):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_category() -> StringName:
	return Juice.CATEGORY_AUDIO


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	var node := get_target()
	if _is_audio_player(node):
		_initial_stream = node.get("stream")
		_initial_volume = node.get("volume_db")
		_initial_pitch = node.get("pitch_scale")
		_initial_paused = node.get("stream_paused")


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_audio_player(node):
		return
	match mode:
		Mode.PLAY:
			_prepare(node)
			node.call("play", from_position)
		Mode.PAUSE:
			node.set("stream_paused", true)
		Mode.RESUME:
			node.set("stream_paused", false)
			if not node.get("playing"):
				node.call("play", from_position)
		Mode.STOP:
			node.call("stop")
		Mode.ONE_SHOT:
			_play_one_shot(node)


func _on_stop() -> void:
	if not stop_on_stop:
		return
	if mode == Mode.PLAY:
		var node := get_target()
		if _is_audio_player(node):
			node.call("stop")
	elif mode == Mode.ONE_SHOT:
		for clone in _clones:
			if is_instance_valid(clone):
				clone.call("stop")
				clone.queue_free()
		_clones.clear()


func _on_restore() -> void:
	var node := get_target()
	if _is_audio_player(node):
		node.set("stream", _initial_stream)
		node.set("volume_db", _initial_volume)
		node.set("pitch_scale", _initial_pitch)
		node.set("stream_paused", _initial_paused)


func _prepare(node: Node) -> void:
	if not random_streams.is_empty():
		var stream: AudioStream = random_streams[randi() % random_streams.size()]
		if stream != null:
			node.set("stream", stream)
	if randomize_volume:
		node.set("volume_db", randf_range(minf(min_volume_db, max_volume_db), maxf(min_volume_db, max_volume_db)))
	if randomize_pitch:
		node.set("pitch_scale", randf_range(minf(min_pitch, max_pitch), maxf(min_pitch, max_pitch)))
	if scale_volume_with_intensity:
		node.set("volume_db", float(node.get("volume_db")) + linear_to_db(maxf(get_intensity(), 0.0001)))
	node.set("stream_paused", false)


func _play_one_shot(node: Node) -> void:
	var parent := node.get_parent()
	if parent == null:
		return
	var clone := node.duplicate(0)
	# Keep the original's own settings: the copy gets the randomization instead.
	_prepare(clone)
	_clones.append(clone)
	clone.set("autoplay", false)
	clone.connect("finished", _on_clone_finished.bind(clone))
	parent.add_child.call_deferred(clone)
	clone.tree_entered.connect(_start_clone.bind(clone), CONNECT_ONE_SHOT)


func _start_clone(clone: Node) -> void:
	clone.call("play", from_position)


func _on_clone_finished(clone: Node) -> void:
	_clones.erase(clone)
	clone.queue_free()


func _is_audio_player(node: Node) -> bool:
	return node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D
