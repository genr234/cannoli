@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceFlash
extends JuiceFeedback
## Flashes the whole screen with a color, such as a white hit flash or a red damage pulse.
##
## It draws on a [JuiceScreenOverlay] that is found or created in the viewport, so no setup is
## needed. The flash rises over [member attack], holds, then falls over [member release]. It
## respects the accessibility flash multiplier and flash rate cap.

@export_group("Flash")
## The color of the flash. Its alpha is the strongest the flash gets.
@export var color: Color = Color(1.0, 1.0, 1.0, 0.8)
## Seconds the flash takes to reach full strength.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var attack: float = 0.03
## Seconds the flash stays at full strength.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var hold: float = 0.0
## Seconds the flash takes to fade out.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var release: float = 0.2
## The easing used for the rise and the fall. Null is a straight line.
@export var tween: JuiceTween
## The canvas layer of the overlay. Higher draws on top.
@export var overlay_layer: int = 100
## Skips the flash when the project's flash rate cap is reached.
@export var respect_flash_cap: bool = true

var _overlay: JuiceScreenOverlay
var _suppressed := false


func _get_duration() -> float:
	return attack + hold + release


func _get_category() -> StringName:
	return Juice.CATEGORY_FLASH


func _has_target() -> bool:
	return false


func _on_play(_feedback_intensity: float) -> void:
	if not is_retrigger():
		_suppressed = respect_flash_cap and not Juice.try_flash()
	_overlay = JuiceScreenOverlay.get_overlay(player, &"flash", overlay_layer)
	if _get_duration() <= 0.0:
		_draw(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	_draw(progress)


func _on_finished() -> void:
	_clear()


func _on_stop() -> void:
	_clear()


func _on_restore() -> void:
	_clear()


func _draw(progress: float) -> void:
	if _overlay == null or not is_instance_valid(_overlay) or _suppressed:
		return
	var total := _get_duration()
	var strength := 1.0
	if total > 0.0:
		var time := clampf(progress, 0.0, 1.0) * total
		if time < attack:
			strength = JuiceTween.sample(tween, time / attack)
		elif time > attack + hold and release > 0.0:
			strength = 1.0 - JuiceTween.sample(tween, (time - attack - hold) / release)
		elif time > attack + hold:
			strength = 0.0
	var alpha := clampf(color.a * strength * get_intensity(), 0.0, 1.0)
	_overlay.color = Color(color.r, color.g, color.b, alpha)


func _clear() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.clear()
