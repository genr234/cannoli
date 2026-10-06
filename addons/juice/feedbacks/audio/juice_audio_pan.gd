@tool
@icon("res://addons/juice/icons/sound.svg")
class_name JuiceAudioPan
extends JuiceFeedback
## Animates the left/right pan of the sound of an audio player.
##
## Godot players have no pan of their own, so this drives the [code]pan[/code] of an
## [AudioEffectPanner] on the player's bus (or on [member bus_override]). Everything on that bus is
## panned, so give the sound its own bus if other sounds share it. When the bus has no panner and
## [member add_effect_if_missing] is on, one is added and removed again on restore.
## For positional sounds, moving the node is usually the better pan.
##
## Intensity is the share of the change that shows.

## ABSOLUTE runs from [member from_pan] to [member to_pan]. FROM_CURRENT runs from the pan
## the effect had when the play started to [member to_pan].
enum Mode { ABSOLUTE, FROM_CURRENT }

@export_group("Pan")
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE:
	set(value):
		mode = value
		notify_property_list_changed()
## The bus to pan. Empty uses the bus the target player plays on.
@export var bus_override: StringName = &""
## Adds a panner to the bus when it has none, and removes it again on restore.
@export var add_effect_if_missing: bool = true
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## The pan at the start for ABSOLUTE. -1 is full left and 1 full right.
@export_range(-1.0, 1.0, 0.01) var from_pan: float = -1.0
## The pan at the end.
@export_range(-1.0, 1.0, 0.01) var to_pan: float = 1.0

var _bus := -1
var _effect: AudioEffectPanner
var _added := false
var _initial := 0.0
var _origin := 0.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "from_pan" and mode == Mode.FROM_CURRENT:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "bus_override":
		JuiceAudioBus.apply_bus_hint(property)


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_AUDIO


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	_effect = null
	_added = false
	_bus = -1


func _on_play(_feedback_intensity: float) -> void:
	if not _prepare():
		return
	if not is_retrigger():
		_origin = _effect.pan
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	if _prepare():
		_apply(progress)


func _on_restore() -> void:
	if _effect == null:
		return
	_effect.pan = _initial
	if _added:
		JuiceAudioBus.remove_effect(_bus, _effect)
		_effect = null
		_added = false


func _apply(progress: float) -> void:
	var start := _origin if mode == Mode.FROM_CURRENT else from_pan
	var value := lerpf(start, to_pan, JuiceTween.sample(tween, progress))
	_effect.pan = clampf(lerpf(_origin, value, get_intensity()), -1.0, 1.0)


# Finds (or adds) the panner. Returns false when there is nothing to drive.
func _prepare() -> bool:
	if _effect != null and is_instance_valid(_effect):
		return true
	var bus_name := bus_override
	if bus_name == &"":
		var node := get_target()
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			bus_name = node.get("bus")
	_bus = AudioServer.get_bus_index(bus_name)
	if _bus < 0:
		return false
	var index := JuiceAudioBus.find_effect(_bus, "AudioEffectPanner")
	if index >= 0:
		_effect = AudioServer.get_bus_effect(_bus, index)
	elif add_effect_if_missing:
		_effect = AudioEffectPanner.new()
		AudioServer.add_bus_effect(_bus, _effect)
		_added = true
	else:
		return false
	_initial = _effect.pan
	_origin = _initial
	return true
