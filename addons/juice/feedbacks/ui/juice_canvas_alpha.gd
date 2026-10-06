@tool
@icon("res://addons/juice/icons/alpha.svg")
class_name JuiceCanvasAlpha
extends JuiceFeedback
## Fades a CanvasItem and everything under it by animating its alpha.
##
## It changes the alpha of [code]modulate[/code] (or [code]self_modulate[/code]), which
## already applies to all child items, so it works like a canvas group. Optionally the
## controls in the tree stop blocking the mouse while the alpha is at or under a limit,
## so an invisible menu cannot be clicked. Intensity is the share of the change that shows.
## The original alpha and mouse filters are restored on restore.

## ABSOLUTE runs from [member from_alpha] to [member to_alpha]. FROM_CURRENT runs from the
## alpha the node had when the play started to [member to_alpha].
enum Mode { ABSOLUTE, FROM_CURRENT }
## Which color of the node is faded.
enum ColorSource { MODULATE, SELF_MODULATE }

@export_group("Alpha")
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE:
	set(value):
		mode = value
		notify_property_list_changed()
## Which color of the node is faded.
@export var color_source: ColorSource = ColorSource.MODULATE
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve of the fade. Null is a straight line.
@export var tween: JuiceTween
## The alpha at the start for ABSOLUTE.
@export_range(0.0, 1.0, 0.01) var from_alpha: float = 0.0
## The alpha at the end.
@export_range(0.0, 1.0, 0.01) var to_alpha: float = 1.0

@export_group("Input")
## Makes every Control under the target ignore the mouse while the alpha is at or below [member block_limit].
@export var ignore_mouse_when_hidden: bool = false
## The alpha at or under which the controls ignore the mouse.
@export_range(0.0, 1.0, 0.01) var block_limit: float = 0.0

var _initial := 1.0
var _origin := 1.0
var _filters := {}
var _ignoring := false


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "from_alpha" and mode == Mode.FROM_CURRENT:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "block_limit" and not ignore_mouse_when_hidden:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	var node := get_target() as CanvasItem
	if node == null:
		return
	_initial = _read(node)
	_origin = _initial
	_filters.clear()
	_ignoring = false


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target() as CanvasItem
	if node == null:
		return
	if not is_retrigger():
		_origin = _read(node)
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target() as CanvasItem
	if node != null:
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target() as CanvasItem
	if node == null:
		return
	_write(node, _initial)
	_set_ignoring(node, false)


func _apply(node: CanvasItem, progress: float) -> void:
	var start := _origin if mode == Mode.FROM_CURRENT else from_alpha
	var value := lerpf(start, to_alpha, JuiceTween.sample(tween, progress))
	var alpha := clampf(lerpf(_origin, value, get_intensity()), 0.0, 1.0)
	_write(node, alpha)
	if ignore_mouse_when_hidden:
		_set_ignoring(node, alpha <= block_limit)


func _read(node: CanvasItem) -> float:
	return (node.self_modulate if color_source == ColorSource.SELF_MODULATE else node.modulate).a


func _write(node: CanvasItem, alpha: float) -> void:
	if color_source == ColorSource.SELF_MODULATE:
		var color := node.self_modulate
		color.a = alpha
		node.self_modulate = color
	else:
		var color := node.modulate
		color.a = alpha
		node.modulate = color


# Switches the mouse filters of all controls in the tree, remembering the originals.
func _set_ignoring(node: CanvasItem, ignoring: bool) -> void:
	if ignoring == _ignoring:
		return
	_ignoring = ignoring
	if ignoring:
		_filters.clear()
		_collect(node)
		for control: Control in _filters.keys():
			if is_instance_valid(control):
				control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		for control: Control in _filters.keys():
			if is_instance_valid(control):
				control.mouse_filter = _filters[control]
		_filters.clear()


func _collect(node: Node) -> void:
	if node is Control:
		_filters[node] = node.mouse_filter
	for child in node.get_children():
		_collect(child)
