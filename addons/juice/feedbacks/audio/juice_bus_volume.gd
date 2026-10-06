@tool
@icon("res://addons/juice/icons/bus.svg")
class_name JuiceBusVolume
extends JuiceFeedback
## Animates the volume of an audio bus, for ducking the music under a sound, fading a
## bus out, or muting it.
##
## Use a curve such as [method JuiceTween.make_there_and_back] to duck and return, or tick
## [member reset_on_finish]. Intensity is the share of the change that shows. The bus
## volume and mute state are put back on restore.

## ABSOLUTE runs from [member from_db] to [member to_db]. FROM_CURRENT runs from the
## volume the bus had when the play started to [member to_db].
enum Mode { ABSOLUTE, FROM_CURRENT }

@export_group("Bus")
## The audio bus to change.
@export var bus: StringName = &"Master"
## How the values are used.
@export var mode: Mode = Mode.FROM_CURRENT:
	set(value):
		mode = value
		notify_property_list_changed()
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## The volume at the start for ABSOLUTE.
@export_range(-80.0, 24.0, 0.1, "suffix:dB") var from_db: float = 0.0
## The volume at the end.
@export_range(-80.0, 24.0, 0.1, "suffix:dB") var to_db: float = -12.0
## Blends loudness in linear gain instead of decibels, which sounds more even near silence.
@export var interpolate_linear: bool = false

@export_group("Mute")
## Unmutes the bus when the play starts.
@export var unmute_on_play: bool = true
## Mutes the bus when a play ends.
@export var mute_on_finish: bool = false
## Puts the volume and mute state back as they were when a play ends.
@export var reset_on_finish: bool = false

var _bus := -1
var _warned := false
var _initial_db := 0.0
var _initial_mute := false
var _origin := 0.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "from_db" and mode == Mode.FROM_CURRENT:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "bus":
		JuiceAudioBus.apply_bus_hint(property)


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_AUDIO


func _on_initialize() -> void:
	_warned = false
	_resolve()


func _on_play(_feedback_intensity: float) -> void:
	if not _resolve():
		return
	if unmute_on_play:
		AudioServer.set_bus_mute(_bus, false)
	if not is_retrigger():
		_origin = AudioServer.get_bus_volume_db(_bus)
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	if _resolve():
		_apply(progress)


func _on_finished() -> void:
	if not _resolve():
		return
	if reset_on_finish:
		AudioServer.set_bus_volume_db(_bus, _initial_db)
		AudioServer.set_bus_mute(_bus, _initial_mute)
	elif mute_on_finish:
		AudioServer.set_bus_mute(_bus, true)


func _on_restore() -> void:
	if _resolve():
		AudioServer.set_bus_volume_db(_bus, _initial_db)
		AudioServer.set_bus_mute(_bus, _initial_mute)


func _apply(progress: float) -> void:
	var start := _origin if mode == Mode.FROM_CURRENT else from_db
	var shaped := JuiceTween.sample(tween, progress)
	var value: float
	if interpolate_linear:
		value = maxf(linear_to_db(lerpf(db_to_linear(start), db_to_linear(to_db), shaped)), -80.0)
	else:
		value = lerpf(start, to_db, shaped)
	AudioServer.set_bus_volume_db(_bus, lerpf(_origin, value, get_intensity()))


# Looks the bus up again each time, since buses can be added or removed at runtime.
func _resolve() -> bool:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		if not _warned:
			_warned = true
			push_warning("JuiceBusVolume: there is no bus named '%s'." % bus)
		return false
	if index != _bus:
		_bus = index
		_initial_db = AudioServer.get_bus_volume_db(_bus)
		_initial_mute = AudioServer.is_bus_mute(_bus)
		_origin = _initial_db
	return true


# A freed player must not leave the bus changed.
func _on_released() -> void:
	_on_restore()
