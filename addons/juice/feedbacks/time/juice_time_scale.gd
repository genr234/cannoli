@tool
@icon("res://addons/juice/icons/time.svg")
class_name JuiceTimeScale
extends JuiceFeedback
## Slows down or speeds up the whole game for a moment, such as a slow motion on a kill.
##
## It changes [member Engine.time_scale] through [JuiceTimeScaleStack], so several time
## feedbacks can overlap safely: the strongest one wins and the original speed returns
## when the last one ends. The feedback runs in unscaled time, so a slow motion does not
## stretch itself. Nothing happens in the editor preview.

## What the feedback does to time.
enum Mode {
	## Blends to [member time_scale], holds it for [member duration], then blends back.
	CHANGE_FOR_DURATION,
	## Blends to [member time_scale] over [member ramp_in] and keeps it until a RESET plays.
	SET,
	## Removes every time scale change and returns to normal speed at once.
	RESET,
}

@export_group("Time Scale")
## What to do.
@export var mode: Mode = Mode.CHANGE_FOR_DURATION:
	set(value):
		mode = value
		notify_property_list_changed()
## The speed to reach. 0.5 is half speed, 2 is double speed. Intensity scales the change from 1.
@export_range(0.0, 4.0, 0.01, "or_greater") var time_scale: float = 0.3
## Seconds the speed is held, not counting the ramps.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## Seconds to blend into the new speed. 0 jumps to it.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var ramp_in: float = 0.0
## Seconds to blend back to normal speed. 0 jumps back.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var ramp_out: float = 0.1
## The easing of the ramps. Null is a straight line.
@export var ramp_tween: JuiceTween
## Also puts the speed back when the player is stopped, in SET mode. CHANGE_FOR_DURATION
## always does.
@export var reset_on_stop: bool = false

var _key := 0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "timescale_mode":
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["time_scale", "ramp_in", "ramp_tween"] and mode == Mode.RESET:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["duration", "ramp_out"] and mode != Mode.CHANGE_FOR_DURATION:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "reset_on_stop" and mode != Mode.SET:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	match mode:
		Mode.CHANGE_FOR_DURATION:
			return ramp_in + duration + ramp_out
		Mode.SET:
			return ramp_in
	return 0.0


func _get_category() -> StringName:
	return Juice.CATEGORY_TIME


func _has_target() -> bool:
	return false


func _on_initialize() -> void:
	# The feedback must not be slowed by the slow motion it creates.
	timescale_mode = Juice.TimeMode.UNSCALED
	_key = get_instance_id()


func _on_play(_feedback_intensity: float) -> void:
	timescale_mode = Juice.TimeMode.UNSCALED
	if mode == Mode.RESET:
		JuiceTimeScaleStack.clear()
		return
	if _get_duration() <= 0.0:
		_apply_weight(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	if mode == Mode.RESET:
		return
	var total := _get_duration()
	if total <= 0.0:
		return
	var time := clampf(progress, 0.0, 1.0) * total
	var weight := 1.0
	if mode == Mode.CHANGE_FOR_DURATION and ramp_out > 0.0 and time > ramp_in + duration:
		weight = 1.0 - JuiceTween.sample(ramp_tween, (time - ramp_in - duration) / ramp_out)
	elif mode == Mode.CHANGE_FOR_DURATION and time > ramp_in + duration:
		weight = 0.0
	elif time < ramp_in:
		weight = JuiceTween.sample(ramp_tween, time / ramp_in)
	_apply_weight(weight)


func _on_finished() -> void:
	if mode == Mode.CHANGE_FOR_DURATION:
		JuiceTimeScaleStack.remove_entry(_key)


func _on_skip_to_end() -> void:
	if mode == Mode.CHANGE_FOR_DURATION:
		JuiceTimeScaleStack.remove_entry(_key)


func _on_stop() -> void:
	if mode == Mode.CHANGE_FOR_DURATION or reset_on_stop:
		JuiceTimeScaleStack.remove_entry(_key)


func _on_restore() -> void:
	JuiceTimeScaleStack.remove_entry(_key)


func _apply_weight(weight: float) -> void:
	var target_scale := lerpf(1.0, time_scale, get_intensity())
	JuiceTimeScaleStack.set_entry(_key, lerpf(1.0, target_scale, weight))
