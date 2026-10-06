@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceFlicker
extends JuiceFeedback
## Switches a color on and off quickly, like a damaged light or an invulnerability blink.
##
## For [CanvasItem], [Sprite3D] and [Label3D] it flickers the modulate. For lights it flickers
## the light color. For other 3D nodes it flickers the albedo of the material, or a
## shader uniform or instance uniform when [member parameter] is set. It counts as a flash, so
## the accessibility flash multiplier and flash rate cap apply to it.

## What the flicker does to the color.
enum Style {
	## Alternates between the normal color and [member flicker_color].
	COLOR,
	## Alternates between the normal color and the same color with zero alpha.
	INVISIBLE,
}

@export_group("Flicker")
## How the color changes.
@export var style: Style = Style.COLOR
## Seconds the whole flicker lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## Seconds each state (flicker color, normal color) is shown.
@export_range(0.01, 2.0, 0.005, "or_greater", "suffix:s") var period: float = 0.05
## The color shown during the flicker state, used by the COLOR style.
@export var flicker_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Uses self_modulate instead of modulate on a [CanvasItem].
@export var use_self_modulate: bool = false
## Skips the flicker when the project's flash rate cap is reached.
@export var respect_flash_cap: bool = true
@export_group("Material")
## The shader uniform to flicker on 3D and shader-material targets. Empty uses the natural color.
@export var parameter: StringName = &""
## Treats [member parameter] as an instance uniform of a 3D node.
@export var use_instance_parameter: bool = false
## Edits a private copy of the material, so other nodes sharing it do not flicker too.
@export var duplicate_material: bool = true

var _channel: JuiceColorChannel
var _bound_node: Node
var _suppressed := false


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_FLASH


func _on_initialize() -> void:
	_bind()


func _on_play(_feedback_intensity: float) -> void:
	_bind()
	if not is_retrigger():
		_suppressed = respect_flash_cap and not Juice.try_flash()
	if duration <= 0.0 and _channel != null:
		_channel.reset()


func _on_progress(progress: float) -> void:
	if _channel == null or not _channel.is_bound() or _suppressed:
		return
	var step := floori(maxf(progress, 0.0) * duration / maxf(period, 0.001))
	if progress >= 1.0 or progress <= 0.0 or step % 2 == 1:
		_channel.reset()
		return
	var color := _flicker_value()
	_channel.write(_channel.initial.lerp(color, clampf(get_intensity(), 0.0, 1.0)))


func _on_finished() -> void:
	if _channel != null:
		_channel.reset()


func _on_restore() -> void:
	if _channel != null:
		_channel.restore()


func _flicker_value() -> Color:
	if style == Style.INVISIBLE:
		return Color(_channel.initial.r, _channel.initial.g, _channel.initial.b, 0.0)
	return flicker_color


func _bind() -> void:
	var node := get_target()
	if node == _bound_node and _channel != null and _channel.is_bound():
		return
	if _channel != null:
		_channel.restore()
	_bound_node = node
	_channel = JuiceColorChannel.new()
	_channel.bind(node, parameter, use_instance_parameter, use_self_modulate, false, duplicate_material)
