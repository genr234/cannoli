@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceFade
extends JuiceFeedback
## Fades the whole screen to a color or back from it, such as a scene transition.
##
## It draws on a [JuiceScreenOverlay] of its own that is found or created in the viewport.
## FADE_OUT covers the screen and keeps it covered until the feedback is restored. FADE_IN
## starts covered and ends clear.

## Which way the fade goes.
enum Mode {
	## From clear to [member color].
	FADE_OUT,
	## From [member color] to clear.
	FADE_IN,
}

@export_group("Fade")
## Which way the fade goes.
@export var mode: Mode = Mode.FADE_OUT
## Seconds one fade takes.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the fade. Null is a straight line.
@export var tween: JuiceTween
## The color the screen fades to or from. Its alpha is the most it covers.
@export var color: Color = Color(0.0, 0.0, 0.0, 1.0)
## The canvas layer of the overlay. Higher draws on top.
@export var overlay_layer: int = 110
## Takes the overlay away when the fade ends, also after FADE_OUT.
@export var clear_when_finished: bool = false

var _overlay: JuiceScreenOverlay


func _get_duration() -> float:
	return duration


func _has_target() -> bool:
	return false


func _on_play(_feedback_intensity: float) -> void:
	_overlay = JuiceScreenOverlay.get_overlay(player, &"fade", overlay_layer)
	if duration <= 0.0:
		_draw(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	_draw(progress)


func _on_finished() -> void:
	if clear_when_finished:
		_clear()


func _on_restore() -> void:
	_clear()


func _draw(progress: float) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var shaped := JuiceTween.sample(tween, progress)
	if mode == Mode.FADE_IN:
		shaped = 1.0 - shaped
	var alpha := clampf(color.a * shaped * get_intensity(), 0.0, 1.0)
	_overlay.color = Color(color.r, color.g, color.b, alpha)


func _clear() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.clear()
