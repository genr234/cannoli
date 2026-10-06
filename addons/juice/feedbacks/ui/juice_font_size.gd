@tool
@icon("res://addons/juice/icons/text.svg")
class_name JuiceFontSize
extends JuiceFeedback
## Animates the font size of a Control with text or of a Label3D.
##
## On Controls it sets a theme override, so the theme itself is not changed, and the
## override is removed again on restore if there was none. Label, Button, LineEdit and the like
## use [code]font_size[/code]; RichTextLabel uses [code]normal_font_size[/code].
## Intensity is the share of the change that shows.

## ABSOLUTE runs from [member from_size] to [member to_size]. FROM_CURRENT runs from the size
## when the play started to [member to_size]. SCALE multiplies the starting size: [member from_size]
## and [member to_size] are then factors, so 1 keeps the size.
enum Mode { ABSOLUTE, FROM_CURRENT, SCALE }

@export_group("Font Size")
## How the values are used.
@export var mode: Mode = Mode.SCALE:
	set(value):
		mode = value
		notify_property_list_changed()
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## The size (or factor for SCALE) at the start. Not used by FROM_CURRENT.
@export_range(0.0, 512.0, 0.1, "or_greater") var from_size: float = 1.0
## The size (or factor for SCALE) at the end.
@export_range(0.0, 512.0, 0.1, "or_greater") var to_size: float = 1.5

var _initial := 16.0
var _initial_had_override := false
var _origin := 16.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "from_size" and mode == Mode.FROM_CURRENT:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	_initial = _read(node)
	_origin = _initial
	if node is Control:
		_initial_had_override = node.has_theme_font_size_override(_theme_name(node))


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	if not is_retrigger():
		_origin = _read(node)
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if _is_supported(node):
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	if node is Control and not _initial_had_override:
		node.remove_theme_font_size_override(_theme_name(node))
	else:
		_write(node, _initial)


func _apply(node: Node, progress: float) -> void:
	var shaped := JuiceTween.sample(tween, progress)
	var value: float
	match mode:
		Mode.ABSOLUTE:
			value = lerpf(from_size, to_size, shaped)
		Mode.FROM_CURRENT:
			value = lerpf(_origin, to_size, shaped)
		_:
			value = _origin * lerpf(from_size, to_size, shaped)
	_write(node, lerpf(_origin, value, get_intensity()))


func _is_supported(node: Node) -> bool:
	return node is Control or node is Label3D


func _theme_name(node: Node) -> StringName:
	return &"normal_font_size" if node is RichTextLabel else &"font_size"


func _read(node: Node) -> float:
	if node is Label3D:
		return float(node.font_size)
	return float(node.get_theme_font_size(_theme_name(node)))


func _write(node: Node, value: float) -> void:
	var size := maxi(roundi(value), 1)
	if node is Label3D:
		node.font_size = size
	else:
		node.add_theme_font_size_override(_theme_name(node), size)
