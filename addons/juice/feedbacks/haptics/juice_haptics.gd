@tool
@icon("res://addons/juice/icons/haptics.svg")
class_name JuiceHaptics
extends JuiceFeedback
## Vibrates gamepads and phones.
##
## PRESET plays one of the ready made gestures, PATTERN plays your own [JuiceHapticPattern], and
## CONTINUOUS holds a vibration whose strength follows a curve over time. Gamepads are driven
## with [method Input.start_joy_vibration] (one device or all connected ones) and phones with
## [method Input.vibrate_handheld]. Nothing happens in the editor, and on platforms
## without vibration.
##
## Intensity scales the strength. Because haptics are a comfort setting, the haptics
## accessibility multiplier applies too. A reversed play runs the pattern backwards.

## PRESET plays a ready made gesture. PATTERN plays [member pattern]. CONTINUOUS follows
## [member amplitude_curve].
enum Mode { PRESET, PATTERN, CONTINUOUS }

# How often a continuous vibration is refreshed, in milliseconds.
const _REFRESH_MSEC := 50

@export_group("Haptics")
## What kind of vibration to play.
@export var mode: Mode = Mode.PRESET:
	set(value):
		mode = value
		notify_property_list_changed()
## The ready made gesture to play, for PRESET.
@export var preset: JuiceHapticPattern.Preset = JuiceHapticPattern.Preset.MEDIUM_IMPACT
## The pattern to play, for PATTERN.
@export var pattern: JuiceHapticPattern
## Seconds a CONTINUOUS vibration lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var continuous_duration: float = 0.5
## The strength over the vibration, from left (start) to right (end), for CONTINUOUS. Null means constant.
@export var amplitude_curve: Curve
## Strength of the light buzz motor of a gamepad, for CONTINUOUS.
@export_range(0.0, 1.0, 0.01) var weak: float = 1.0
## Strength of the heavy rumble motor of a gamepad, for CONTINUOUS.
@export_range(0.0, 1.0, 0.01) var strong: float = 1.0

@export_group("Devices")
## Vibrates gamepads.
@export var use_joypads: bool = true
## The gamepad to vibrate. -1 vibrates every connected gamepad.
@export_range(-1, 7, 1, "or_greater") var joypad_device: int = -1
## Vibrates the phone or tablet.
@export var use_handheld: bool = true

var _step := -1
var _last_refresh := 0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "preset" and mode != Mode.PRESET:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "pattern" and mode != Mode.PATTERN:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["continuous_duration", "amplitude_curve", "weak", "strong"] and mode != Mode.CONTINUOUS:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "joypad_device" and not use_joypads:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	if mode == Mode.CONTINUOUS:
		return continuous_duration
	var current := _get_pattern()
	return current.get_duration() if current != null else 0.0


func _get_category() -> StringName:
	return Juice.CATEGORY_HAPTICS


func _on_reset() -> void:
	_step = -1
	_last_refresh = 0


func _on_play(_feedback_intensity: float) -> void:
	_step = -1
	_last_refresh = 0


func _on_progress(progress: float) -> void:
	if Engine.is_editor_hint():
		return
	if mode == Mode.CONTINUOUS:
		_progress_continuous(progress)
	else:
		_progress_pattern(progress)


func _on_finished() -> void:
	_stop_vibration()


func _on_skip_to_end() -> void:
	_stop_vibration()


func _on_stop() -> void:
	_stop_vibration()


func _get_pattern() -> JuiceHapticPattern:
	if mode == Mode.PRESET:
		return JuiceHapticPattern.preset(preset)
	return pattern


func _progress_pattern(progress: float) -> void:
	var current := _get_pattern()
	if current == null:
		return
	var total := current.get_duration()
	if total <= 0.0:
		return
	var time := clampf(progress, 0.0, 1.0) * total
	var index := current.get_step_index(time)
	if index < 0 or index == _step:
		return
	_step = index
	var step := current.steps[index]
	if step.is_silent():
		_stop_joypads()
		return
	# How long the step still lasts in real seconds, counting toward the end of the play.
	var step_start := current.get_step_start(index)
	var left := (time - step_start) if is_reversed() else (step_start + step.duration - time)
	var real_left := maxf(left, 0.0) * (get_feedback_duration() / total)
	_vibrate(step.weak, step.strong, maxf(real_left, 0.02))


func _progress_continuous(progress: float) -> void:
	var now := Time.get_ticks_msec()
	var final_frame := progress <= 0.0 or progress >= 1.0
	if not final_frame and now - _last_refresh < _REFRESH_MSEC:
		return
	_last_refresh = now
	var level := 1.0
	if amplitude_curve != null:
		level = amplitude_curve.sample_baked(clampf(progress, 0.0, 1.0))
	if level <= 0.01:
		_stop_joypads()
		return
	_vibrate(weak * level, strong * level, float(_REFRESH_MSEC * 2) / 1000.0)


# Sends the strengths (before intensity) to every enabled device for [param seconds].
func _vibrate(weak_strength: float, strong_strength: float, seconds: float) -> void:
	var share := get_intensity()
	var w := clampf(weak_strength * share, 0.0, 1.0)
	var s := clampf(strong_strength * share, 0.0, 1.0)
	if w <= 0.0 and s <= 0.0:
		return
	if use_joypads:
		for device in _devices():
			Input.start_joy_vibration(device, w, s, seconds)
	if use_handheld and OS.has_feature("mobile"):
		Input.vibrate_handheld(maxi(roundi(seconds * 1000.0), 1), maxf(w, s))


func _stop_vibration() -> void:
	if Engine.is_editor_hint():
		return
	_stop_joypads()
	_step = -1


func _stop_joypads() -> void:
	if not use_joypads:
		return
	for device in _devices():
		Input.stop_joy_vibration(device)


func _devices() -> Array[int]:
	if joypad_device >= 0:
		return [joypad_device]
	return Input.get_connected_joypads()
