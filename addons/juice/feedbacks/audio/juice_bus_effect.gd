@tool
@icon("res://addons/juice/icons/bus.svg")
class_name JuiceBusEffect
extends JuiceFeedback
## Animates one number of an audio effect on a bus, such as the cutoff of a low pass filter
## for a muffled underwater sound, the wetness of a reverb, or the drive of a distortion.
##
## The effect is found on the named bus by its type (the first one of that type, or the
## slot in [member effect_index]). If the bus has none and [member add_effect_if_missing]
## is on, one is added and removed again on restore. The parameter is any numeric
## property of the effect, for example [code]cutoff_hz[/code], [code]wet[/code],
## [code]drive[/code] or [code]room_size[/code].
##
## Intensity is the share of the change that shows.

## ABSOLUTE runs from [member from_value] to [member to_value]. FROM_CURRENT runs from the
## value the effect had when the play started to [member to_value].
enum Mode { ABSOLUTE, FROM_CURRENT }

@export_group("Effect")
## The audio bus that holds the effect.
@export var bus: StringName = &"Master"
## The type of effect to look for on the bus.
@export_enum("AudioEffectLowPassFilter", "AudioEffectHighPassFilter", "AudioEffectBandPassFilter",
		"AudioEffectReverb", "AudioEffectDelay", "AudioEffectDistortion", "AudioEffectChorus",
		"AudioEffectPhaser", "AudioEffectCompressor", "AudioEffectLimiter", "AudioEffectAmplify",
		"AudioEffectPitchShift", "AudioEffectEQ10") var effect_type: String = "AudioEffectLowPassFilter"
## The slot of the effect on the bus. -1 uses the first effect of the chosen type.
@export_range(-1, 15, 1) var effect_index: int = -1
## Adds the effect to the bus when it has none, and removes it again on restore.
@export var add_effect_if_missing: bool = false
## The effect property to animate.
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, "cutoff_hz,resonance,wet,dry,drive,room_size,damping,feedback_level_db,tap1_level_db,volume_db,pre_gain,post_gain,threshold,ratio,depth,rate_hz,pitch_scale") var parameter: String = "cutoff_hz"

@export_group("Animation")
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE:
	set(value):
		mode = value
		notify_property_list_changed()
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## The parameter at the start for ABSOLUTE.
@export var from_value: float = 20500.0
## The parameter at the end.
@export var to_value: float = 800.0
## Blends the values on a logarithmic scale. Good for frequencies; both values must be above 0.
@export var logarithmic: bool = false

@export_group("State")
## Turns the effect on when the play starts.
@export var enable_on_play: bool = true
## Turns the effect off when a play ends.
@export var disable_on_finish: bool = false
## Puts the parameter and the on/off state back as they were when a play ends.
@export var reset_on_finish: bool = false

var _bus := -1
var _effect: AudioEffect
var _added := false
var _warned := false
var _initial_value := 0.0
var _initial_enabled := true
var _origin := 0.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "from_value" and mode == Mode.FROM_CURRENT:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "bus":
		JuiceAudioBus.apply_bus_hint(property)


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_AUDIO


func _on_initialize() -> void:
	_effect = null
	_added = false
	_warned = false
	_bus = -1


func _on_play(_feedback_intensity: float) -> void:
	if not _prepare():
		return
	if enable_on_play:
		AudioServer.set_bus_effect_enabled(_bus, _slot(), true)
	if not is_retrigger():
		_origin = _effect.get(parameter)
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	if _prepare():
		_apply(progress)


func _on_finished() -> void:
	if _effect == null or not is_instance_valid(_effect):
		return
	if reset_on_finish:
		_effect.set(parameter, _initial_value)
		AudioServer.set_bus_effect_enabled(_bus, _slot(), _initial_enabled)
	elif disable_on_finish:
		AudioServer.set_bus_effect_enabled(_bus, _slot(), false)


func _on_restore() -> void:
	if _effect == null or not is_instance_valid(_effect):
		return
	if _added:
		JuiceAudioBus.remove_effect(_bus, _effect)
		_effect = null
		_added = false
		return
	_effect.set(parameter, _initial_value)
	AudioServer.set_bus_effect_enabled(_bus, _slot(), _initial_enabled)


func _apply(progress: float) -> void:
	var start := _origin if mode == Mode.FROM_CURRENT else from_value
	var shaped := JuiceTween.sample(tween, progress)
	var value: float
	if logarithmic and start > 0.0 and to_value > 0.0:
		value = exp(lerpf(log(start), log(to_value), shaped))
	else:
		value = lerpf(start, to_value, shaped)
	_effect.set(parameter, lerpf(_origin, value, get_intensity()))


# Finds (or adds) the effect. Returns false when there is nothing to drive.
func _prepare() -> bool:
	if _effect != null and is_instance_valid(_effect):
		return true
	_bus = AudioServer.get_bus_index(bus)
	if _bus < 0:
		_warn("there is no bus named '%s'." % bus)
		return false
	var index := JuiceAudioBus.find_effect(_bus, effect_type, effect_index)
	if index >= 0:
		_effect = AudioServer.get_bus_effect(_bus, index)
	elif add_effect_if_missing and ClassDB.can_instantiate(effect_type):
		_effect = ClassDB.instantiate(effect_type)
		AudioServer.add_bus_effect(_bus, _effect)
		_added = true
	else:
		_warn("bus '%s' has no %s." % [bus, effect_type])
		return false
	if not parameter in _effect or not typeof(_effect.get(parameter)) in [TYPE_FLOAT, TYPE_INT]:
		_warn("%s has no numeric property '%s'." % [effect_type, parameter])
		_effect = null
		return false
	_initial_value = _effect.get(parameter)
	_origin = _initial_value
	_initial_enabled = AudioServer.is_bus_effect_enabled(_bus, _slot())
	return true


func _slot() -> int:
	for i in AudioServer.get_bus_effect_count(_bus):
		if AudioServer.get_bus_effect(_bus, i) == _effect:
			return i
	return 0


func _warn(message: String) -> void:
	if not _warned:
		_warned = true
		push_warning("JuiceBusEffect: " + message)


# A freed player must not leave the bus changed.
func _on_released() -> void:
	_on_restore()
