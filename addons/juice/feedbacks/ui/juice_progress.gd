@tool
@icon("res://addons/juice/icons/progress.svg")
class_name JuiceProgress
extends JuiceFeedback
## Animates the value of a Range over time, such as a health bar, a loading bar or a slider.
##
## It works on ProgressBar, TextureProgressBar, Slider, SpinBox and ScrollBar. Values can be
## given as a ratio (0 is the minimum, 1 the maximum) so the feedback keeps working when the
## range is changed. Intensity is the share of the change that shows.

## ABSOLUTE runs from [member from_value] to [member to_value]. FROM_CURRENT runs from the value
## the range had when the play started to [member to_value].
enum Mode { ABSOLUTE, FROM_CURRENT }

@export_group("Progress")
## How the values are used.
@export var mode: Mode = Mode.FROM_CURRENT:
	set(value):
		mode = value
		notify_property_list_changed()
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## Reads the values as a ratio from 0 (minimum) to 1 (maximum) instead of raw values.
@export var use_ratio: bool = true
## The value at the start for ABSOLUTE.
@export var from_value: float = 0.0
## The value at the end.
@export var to_value: float = 1.0
## Sends the value_changed signal while animating. Turn it off to keep other code from reacting each frame.
@export var emit_value_changed: bool = true

var _initial := 0.0
var _origin := 0.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "from_value" and mode == Mode.FROM_CURRENT:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	var node := get_target()
	if node is Range:
		_initial = node.value
		_origin = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target() as Range
	if node == null:
		return
	if not is_retrigger():
		_origin = node.value
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target() as Range
	if node != null:
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target() as Range
	if node != null:
		_write(node, _initial)


func _apply(node: Range, progress: float) -> void:
	var start := _origin if mode == Mode.FROM_CURRENT else _to_raw(node, from_value)
	var end := _to_raw(node, to_value)
	var value := lerpf(start, end, JuiceTween.sample(tween, progress))
	_write(node, lerpf(_origin, value, get_intensity()))


func _to_raw(node: Range, value: float) -> float:
	if use_ratio:
		return lerpf(node.min_value, node.max_value, value)
	return value


func _write(node: Range, value: float) -> void:
	if emit_value_changed:
		node.value = value
	else:
		node.set_value_no_signal(value)
