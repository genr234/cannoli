@tool
@icon("res://addons/juice/icons/sound.svg")
class_name JuiceSound
extends JuiceFeedback
## Plays a sound, or one picked from a list.
##
## Sounds are played by pooled audio players that live under the tree root (see
## [JuiceAudioPool]), so a sound keeps playing when the node that triggered it is freed.
## A sound can be global, or positional: at the play position or following the target,
## as an AudioStreamPlayer2D or AudioStreamPlayer3D depending on the target node.
## Put an [AudioStreamRandomizer] in the list for variations inside one stream.
##
## Intensity scales the volume. Reversed plays can be skipped, since audio cannot
## run backwards. Playing in the editor preview is allowed.

## How a stream is chosen when the list has several.
enum Selection { SEQUENTIAL, RANDOM, SHUFFLE }
## What the volume range is measured in.
enum VolumeUnit { DECIBELS, LINEAR }
## GLOBAL ignores positions. POSITIONAL uses a 2D or 3D player.
enum Space { GLOBAL, POSITIONAL }
## Which positional player to use. AUTO looks at the target node.
enum Dimension { AUTO, TWO_D, THREE_D }

@export_group("Sound")
## The sounds to choose from. One entry plays that sound every time.
@export var streams: Array[AudioStream] = []
## How a sound is picked when there are several. SHUFFLE plays them all before repeating.
@export var selection: Selection = Selection.RANDOM
## Seconds into the sound to start from.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var start_offset: float = 0.0
## The audio bus to play on.
@export var bus: StringName = &"Master"

@export_group("Volume and Pitch")
## Whether the volume range is in decibels or linear gain.
@export var volume_unit: VolumeUnit = VolumeUnit.DECIBELS:
	set(value):
		volume_unit = value
		notify_property_list_changed()
## The lowest volume in decibels. Each play picks a value between lowest and highest.
@export_range(-60.0, 24.0, 0.1, "suffix:dB") var min_volume_db: float = 0.0
## The highest volume in decibels.
@export_range(-60.0, 24.0, 0.1, "suffix:dB") var max_volume_db: float = 0.0
## The lowest linear volume. 1 is full volume.
@export_range(0.0, 4.0, 0.01) var min_volume: float = 1.0
## The highest linear volume.
@export_range(0.0, 4.0, 0.01) var max_volume: float = 1.0
## The lowest pitch scale. 1 is the original pitch.
@export_range(0.05, 4.0, 0.01) var min_pitch: float = 1.0
## The highest pitch scale.
@export_range(0.05, 4.0, 0.01) var max_pitch: float = 1.0
## Multiplies the pitch by [member Engine.time_scale] while the sound plays, so slow motion
## also slows the sound.
@export var pitch_follows_time_scale: bool = false

@export_group("Space")
## GLOBAL plays everywhere at the same volume. POSITIONAL is heard from a position.
@export var space: Space = Space.GLOBAL:
	set(value):
		space = value
		notify_property_list_changed()
## Chooses between a 2D and a 3D player. AUTO uses the target: Node3D is 3D, anything else is 2D.
@export var dimension: Dimension = Dimension.AUTO
## Moves the sound with the target while it plays. Without it the sound stays where it started.
@export var follow_target: bool = false
## The farthest distance the sound can be heard from. 0 uses the engine default.
@export_range(0.0, 10000.0, 0.1, "or_greater") var max_distance: float = 0.0
## The distance a 3D sound is at full volume before it fades.
@export_range(0.1, 100.0, 0.1, "or_greater") var unit_size: float = 10.0
## How strongly a 3D sound is panned left and right.
@export_range(0.0, 3.0, 0.01) var panning_strength: float = 1.0

@export_group("Playback")
## Stops the sounds this feedback started when the player is stopped.
@export var stop_sound_on_stop: bool = true
## The most sounds from this feedback that may play at once. 0 means no limit.
@export_range(0, 32, 1, "or_greater") var max_simultaneous: int = 0
## When the limit is reached, cuts the oldest sound. Otherwise the new sound is skipped.
@export var steal_oldest: bool = true
## When false, nothing plays during a reversed play.
@export var play_when_reversed: bool = true
## Makes this feedback last as long as its longest sound, so the player waits for it.
@export var wait_for_sound: bool = false

var _next_index := 0
var _bag: Array[int] = []
var _last_index := -1


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	match prop_name:
		"bus":
			JuiceAudioBus.apply_bus_hint(property)
		"min_volume_db", "max_volume_db":
			if volume_unit != VolumeUnit.DECIBELS:
				property.usage &= ~PROPERTY_USAGE_EDITOR
		"min_volume", "max_volume":
			if volume_unit != VolumeUnit.LINEAR:
				property.usage &= ~PROPERTY_USAGE_EDITOR
		"dimension", "follow_target", "max_distance", "unit_size", "panning_strength":
			if space != Space.POSITIONAL:
				property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	if not wait_for_sound:
		return 0.0
	var longest := 0.0
	for stream in streams:
		if stream != null:
			longest = maxf(longest, stream.get_length())
	return longest


func _get_category() -> StringName:
	return Juice.CATEGORY_AUDIO


func _has_randomness() -> bool:
	return true


func _has_target() -> bool:
	return space == Space.POSITIONAL


func _on_reset() -> void:
	_next_index = 0
	_bag.clear()
	_last_index = -1


func _on_play(_feedback_intensity: float) -> void:
	if is_reversed() and not play_when_reversed:
		return
	var stream := _pick_stream()
	if stream == null:
		return
	var intensity := get_intensity()
	if intensity <= 0.0:
		return
	var request := JuiceAudioPool.Request.new()
	request.bus = bus
	request.start_offset = start_offset
	request.pitch = randf_range(minf(min_pitch, max_pitch), maxf(min_pitch, max_pitch))
	request.follow_time_scale = pitch_follows_time_scale
	request.max_voices = max_simultaneous
	request.steal_oldest = steal_oldest
	if volume_unit == VolumeUnit.DECIBELS:
		request.volume_db = randf_range(minf(min_volume_db, max_volume_db), maxf(min_volume_db, max_volume_db)) + linear_to_db(intensity)
	else:
		var linear := randf_range(minf(min_volume, max_volume), maxf(min_volume, max_volume)) * intensity
		if linear <= 0.0:
			return
		request.volume_db = linear_to_db(linear)
	if space == Space.POSITIONAL:
		var reference := get_target()
		request.position = get_play_position()
		request.kind = _kind_for(reference)
		request.max_distance = max_distance
		request.unit_size = unit_size
		request.panning_strength = panning_strength
		if follow_target and reference != null:
			request.follow = reference
	var pool := JuiceAudioPool.get_pool(player.get_tree())
	pool.play(self, stream, request)


func _on_stop() -> void:
	if not stop_sound_on_stop or player == null or not player.is_inside_tree():
		return
	JuiceAudioPool.get_pool(player.get_tree()).stop_source(self)


func _kind_for(reference: Node) -> JuiceAudioPool.Kind:
	match dimension:
		Dimension.TWO_D:
			return JuiceAudioPool.Kind.TWO_D
		Dimension.THREE_D:
			return JuiceAudioPool.Kind.THREE_D
	if reference is Node3D:
		return JuiceAudioPool.Kind.THREE_D
	return JuiceAudioPool.Kind.TWO_D


func _pick_stream() -> AudioStream:
	var count := streams.size()
	if count == 0:
		return null
	var index := 0
	match selection:
		Selection.SEQUENTIAL:
			index = _next_index % count
			_next_index = index + 1
		Selection.RANDOM:
			index = randi() % count
		Selection.SHUFFLE:
			if _bag.is_empty():
				for i in count:
					_bag.append(i)
				_bag.shuffle()
				# Do not start a new round with the sound that just ended the last one.
				if count > 1 and _bag.back() == _last_index:
					_bag.reverse()
			index = _bag.pop_back()
	_last_index = index
	return streams[index]
