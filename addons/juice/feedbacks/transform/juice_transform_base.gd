@tool
@abstract
class_name JuiceTransformBase
extends JuiceFeedback
## The shared part of [JuicePosition], [JuiceRotation] and [JuiceScale].
##
## It animates a Vector3 on the target, one curve per axis. A subclass only says how
## to read and write that vector for each node type.
##
## Intensity is the share of the effect that shows: 0 leaves the target alone and 1 is the
## full effect. Reversed plays run the curves from right to left.

## ABSOLUTE sets the value to the remapped curve. ADDITIVE adds the remapped curve to the
## origin. TO_DESTINATION moves from the origin to [member destination].
enum Mode { ABSOLUTE, ADDITIVE, TO_DESTINATION }
## EACH_PLAY takes the origin from the target each time a play starts. INITIAL always
## uses the value found when the player initialized.
enum Origin { EACH_PLAY, INITIAL }

@export_group("Animation")
## How the curve values are used.
@export var mode: Mode = Mode.ADDITIVE:
	set(value):
		mode = value
		# A destination should be reached and kept, so the untouched default curve becomes an ease.
		if mode == Mode.TO_DESTINATION and _default_tween != null and tween_x == _default_tween:
			var ease := JuiceTween.make_ease_in_out()
			tween_x = ease
			tween_y = ease
			tween_z = ease
		notify_property_list_changed()
## Where ADDITIVE and TO_DESTINATION start from.
@export var origin: Origin = Origin.EACH_PLAY
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
@export_subgroup("Axes")
## Animates the x axis.
@export var animate_x: bool = true
## Animates the y axis.
@export var animate_y: bool = true
## Animates the z axis. 2D nodes and controls ignore it, except rotation which uses only z.
@export var animate_z: bool = true
## The curve of the x axis. New feedbacks go out and back. Null is a straight line.
@export var tween_x: JuiceTween
## The curve of the y axis. Null is a straight line.
@export var tween_y: JuiceTween
## The curve of the z axis. Null is a straight line.
@export var tween_z: JuiceTween
@export_subgroup("Values")
## What a curve value of 0 maps to.
@export var remap_zero: Vector3 = Vector3.ZERO
## What a curve value of 1 maps to.
@export var remap_one: Vector3 = Vector3.ONE
## The end value for TO_DESTINATION.
@export var destination: Vector3 = Vector3.ONE

var _initial := Vector3.ZERO
var _origin := Vector3.ZERO
var _default_tween: JuiceTween


# New feedbacks punch out and come back, so playing one twice never drifts the target.
func _init() -> void:
	_default_tween = JuiceTween.make_there_and_back()
	tween_x = _default_tween
	tween_y = _default_tween
	tween_z = _default_tween


# --- Subclass hooks --------------------------------------------------------

## Return true if [param node] can be animated by this feedback.
func _is_supported(_node: Node) -> bool:
	return false


## Reads the current value of [param node] as a Vector3.
func _read(_node: Node) -> Vector3:
	return Vector3.ZERO


## Writes [param value] to [param node].
func _write(_node: Node, _value: Vector3) -> void:
	pass


# --- JuiceFeedback ---------------------------------------------------------

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name in ["remap_zero", "remap_one"] and mode == Mode.TO_DESTINATION:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "destination" and mode != Mode.TO_DESTINATION:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _on_initialize() -> void:
	var node := get_target()
	if _is_supported(node):
		_initial = _read(node)
		_origin = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	if origin == Origin.INITIAL:
		_origin = _initial
	elif not is_retrigger():
		_origin = _read(node)
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if _is_supported(node):
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if _is_supported(node):
		_write(node, _initial)


func _apply(node: Node, progress: float) -> void:
	var value := _read(node)
	var share := get_intensity()
	for axis in 3:
		if not _animates(axis):
			continue
		var curve_value := JuiceTween.sample(_tween_for(axis), progress)
		var start: float = _origin[axis]
		match mode:
			Mode.ABSOLUTE:
				value[axis] = lerpf(start, lerpf(remap_zero[axis], remap_one[axis], curve_value), share)
			Mode.ADDITIVE:
				value[axis] = start + lerpf(remap_zero[axis], remap_one[axis], curve_value) * share
			Mode.TO_DESTINATION:
				value[axis] = start + (destination[axis] - start) * curve_value * share
	_write(node, value)


func _animates(axis: int) -> bool:
	match axis:
		0:
			return animate_x
		1:
			return animate_y
	return animate_z


func _tween_for(axis: int) -> JuiceTween:
	match axis:
		0:
			return tween_x
		1:
			return tween_y
	return tween_z
