@tool
@icon("res://addons/juice/icons/layout.svg")
class_name JuiceControlLayout
extends JuiceFeedback
## Animates the layout of a Control: its anchors, offsets, pivot, size or minimum size.
##
## Pick one [member property] per feedback and use several feedbacks to animate more.
## Controls inside containers have their size and position set by the container, so animate
## [code]custom_minimum_size[/code] there instead. Intensity is the share of the change that
## shows. The original layout is restored on restore.

## What part of the layout is animated.
enum Property { ANCHOR_MIN, ANCHOR_MAX, OFFSET_MIN, OFFSET_MAX, PIVOT_OFFSET, SIZE, MIN_SIZE, POSITION }
## ABSOLUTE runs from [member from_value] to [member to_value]. ADDITIVE adds that value to the
## origin. TO_VALUE runs from the origin to [member to_value].
enum Mode { ABSOLUTE, ADDITIVE, TO_VALUE }

@export_group("Layout")
## What part of the layout to animate. ANCHOR_MIN is the left/top anchor, ANCHOR_MAX the
## right/bottom one, OFFSET_MIN the left/top offset and OFFSET_MAX the right/bottom offset.
@export var property: Property = Property.OFFSET_MIN
## How the values are used.
@export var mode: Mode = Mode.ADDITIVE:
	set(value):
		mode = value
		notify_property_list_changed()
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## Animates the x (horizontal) part.
@export var animate_x: bool = true
## Animates the y (vertical) part.
@export var animate_y: bool = true
## The value at the start of the curve.
@export var from_value: Vector2 = Vector2.ZERO
## The value at the end of the curve.
@export var to_value: Vector2 = Vector2(0.0, 50.0)

var _initial := Vector2.ZERO
var _origin := Vector2.ZERO


func _validate_property(property_info: Dictionary) -> void:
	super._validate_property(property_info)
	if property_info.name == "from_value" and mode == Mode.TO_VALUE:
		property_info.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	var node := get_target() as Control
	if node != null:
		_initial = _read(node)
		_origin = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target() as Control
	if node == null:
		return
	if not is_retrigger():
		_origin = _read(node)
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target() as Control
	if node != null:
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target() as Control
	if node != null:
		_write(node, _initial)


func _apply(node: Control, progress: float) -> void:
	var shaped := JuiceTween.sample(tween, progress)
	var share := get_intensity()
	var current := _read(node)
	var value := current
	for axis in 2:
		if (axis == 0 and not animate_x) or (axis == 1 and not animate_y):
			continue
		var start: float = _origin[axis]
		match mode:
			Mode.ABSOLUTE:
				value[axis] = lerpf(start, lerpf(from_value[axis], to_value[axis], shaped), share)
			Mode.ADDITIVE:
				value[axis] = start + lerpf(from_value[axis], to_value[axis], shaped) * share
			Mode.TO_VALUE:
				value[axis] = start + (to_value[axis] - start) * shaped * share
	_write(node, value)


func _read(node: Control) -> Vector2:
	match property:
		Property.ANCHOR_MIN:
			return Vector2(node.anchor_left, node.anchor_top)
		Property.ANCHOR_MAX:
			return Vector2(node.anchor_right, node.anchor_bottom)
		Property.OFFSET_MIN:
			return Vector2(node.offset_left, node.offset_top)
		Property.OFFSET_MAX:
			return Vector2(node.offset_right, node.offset_bottom)
		Property.PIVOT_OFFSET:
			return node.pivot_offset
		Property.SIZE:
			return node.size
		Property.MIN_SIZE:
			return node.custom_minimum_size
	return node.position


func _write(node: Control, value: Vector2) -> void:
	match property:
		Property.ANCHOR_MIN:
			# Offsets are left alone so the rectangle moves with the anchor, like in the editor's raw mode.
			node.set_anchor(SIDE_LEFT, value.x, true, false)
			node.set_anchor(SIDE_TOP, value.y, true, false)
		Property.ANCHOR_MAX:
			node.set_anchor(SIDE_RIGHT, value.x, true, false)
			node.set_anchor(SIDE_BOTTOM, value.y, true, false)
		Property.OFFSET_MIN:
			node.offset_left = value.x
			node.offset_top = value.y
		Property.OFFSET_MAX:
			node.offset_right = value.x
			node.offset_bottom = value.y
		Property.PIVOT_OFFSET:
			node.pivot_offset = value
		Property.SIZE:
			node.size = value
		Property.MIN_SIZE:
			node.custom_minimum_size = value
		Property.POSITION:
			node.position = value
