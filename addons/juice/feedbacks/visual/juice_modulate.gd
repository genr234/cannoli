@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceModulate
extends JuiceFeedback
## Fades a color over time, such as a hit flash.
##
## It works on any CanvasItem (modulate or self modulate), on Sprite3D and Label3D
## (modulate), on Light2D (color) and on Light3D (light color). It counts as a
## flash, so the accessibility flash multiplier and flash rate cap apply to it.

## ABSOLUTE runs from [member from_color] to [member to_color]. TO_COLOR runs from the
## color the node had to [member to_color].
enum Mode { ABSOLUTE, TO_COLOR }
## Which color of a CanvasItem is animated. Other node types ignore it.
enum CanvasColor { MODULATE, SELF_MODULATE }

@export_group("Color")
## How the colors are used.
@export var mode: Mode = Mode.ABSOLUTE
## Which color of a CanvasItem is animated.
@export var canvas_color: CanvasColor = CanvasColor.MODULATE
## Seconds one play takes.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.2
## The curve of the fade. Null is a straight line.
@export var tween: JuiceTween
## The start color for ABSOLUTE.
@export var from_color: Color = Color.WHITE
## The end color.
@export var to_color: Color = Color(1.0, 0.4, 0.4, 1.0)
## Reads the color from a gradient instead of blending the two colors.
@export var use_gradient: bool = false
## The gradient sampled over the play, used when [member use_gradient] is on.
@export var gradient: Gradient
## Skips the flash when the project's flash rate cap is reached.
@export var respect_flash_cap: bool = true

var _initial := Color.WHITE
var _origin := Color.WHITE
var _suppressed := false


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_FLASH


func _on_initialize() -> void:
	var node := get_target()
	if _is_supported(node):
		_initial = _read(node)
		_origin = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	if not is_retrigger():
		_origin = _read(node)
		_suppressed = respect_flash_cap and not Juice.try_flash()
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
	if _suppressed:
		return
	var shaped := JuiceTween.sample(tween, progress)
	var color: Color
	if use_gradient and gradient != null:
		color = gradient.sample(clampf(shaped, 0.0, 1.0))
	elif mode == Mode.TO_COLOR:
		color = _origin.lerp(to_color, shaped)
	else:
		color = from_color.lerp(to_color, shaped)
	_write(node, _origin.lerp(color, get_intensity()))


func _is_supported(node: Node) -> bool:
	return not _property_for(node).is_empty()


func _property_for(node: Node) -> StringName:
	if node is CanvasItem and not (node is Light2D):
		return &"self_modulate" if canvas_color == CanvasColor.SELF_MODULATE else &"modulate"
	if node is Light2D:
		return &"color"
	if node is Light3D:
		return &"light_color"
	if node is Sprite3D or node is Label3D:
		return &"modulate"
	return &""


func _read(node: Node) -> Color:
	return node.get(_property_for(node))


func _write(node: Node, color: Color) -> void:
	node.set(_property_for(node), color)
