@tool
@icon("res://addons/juice/icons/environment.svg")
class_name JuiceScreenEffect
extends JuiceFeedback
## Screen-wide effects drawn by a shader: vignette, chromatic aberration, lens distortion
## and punch zoom.
##
## The effects are drawn by one [JuiceScreenEffects] layer per viewport, created when needed.
## Each feedback adds its value to the layer, so two of them can run at the same time without
## overwriting each other. By default the value is taken away again when the play ends, which
## suits a quick punch. Turn off [member revert_when_finished] to keep the end value until the
## feedback is restored.

## The effect to drive.
enum Effect {
	## Darkens the screen edges. 1 is fully dark at the corners.
	VIGNETTE,
	## Splits the red and blue channels apart towards the edges. Around 0.01 to 0.05 is visible.
	CHROMATIC_ABERRATION,
	## Bends the picture. Positive bulges, negative pinches. Around 0.2 to 1 is visible.
	LENS_DISTORTION,
	## Zooms into the center. 0.1 shows 10 percent less of the picture.
	ZOOM_PUNCH,
}

@export_group("Screen Effect")
## The effect to drive.
@export var effect: Effect = Effect.VIGNETTE:
	set(value):
		effect = value
		notify_property_list_changed()
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.4
## The curve of the change. Null is a straight line. A rise and fall curve makes a pulse.
@export var tween: JuiceTween
## The amount at curve position 0.
@export var from_amount: float = 0.0
## The amount at curve position 1.
@export var to_amount: float = 0.6
## Takes the amount away again when the play ends.
@export var revert_when_finished: bool = true
## The color of the vignette.
@export var vignette_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## The canvas layer of the effects. Higher draws on top.
@export var overlay_layer: int = 90

var _effects: JuiceScreenEffects
var _key := 0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "vignette_color" and effect != Effect.VIGNETTE:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_FLASH if effect == Effect.CHROMATIC_ABERRATION else Juice.CATEGORY_OTHER


func _has_target() -> bool:
	return false


func _on_initialize() -> void:
	_key = get_instance_id()


func _on_play(_feedback_intensity: float) -> void:
	_effects = JuiceScreenEffects.get_for(player, overlay_layer)
	if _effects == null:
		return
	if effect == Effect.VIGNETTE:
		_effects.set_value(&"vignette_color", vignette_color)
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	_apply(progress)


func _on_finished() -> void:
	if revert_when_finished:
		_clear()


func _on_skip_to_end() -> void:
	if revert_when_finished:
		_clear()


func _on_stop() -> void:
	_clear()


func _on_restore() -> void:
	_clear()


func _apply(progress: float) -> void:
	if _effects == null or not is_instance_valid(_effects):
		return
	var shaped := JuiceTween.sample(tween, progress)
	_effects.set_contribution(_param(), _key, lerpf(from_amount, to_amount, shaped) * get_intensity())


func _clear() -> void:
	if _effects != null and is_instance_valid(_effects):
		_effects.clear_contributions(_key)


func _param() -> StringName:
	match effect:
		Effect.CHROMATIC_ABERRATION:
			return JuiceScreenEffects.PARAM_CHROMATIC
		Effect.LENS_DISTORTION:
			return JuiceScreenEffects.PARAM_LENS
		Effect.ZOOM_PUNCH:
			return JuiceScreenEffects.PARAM_ZOOM
	return JuiceScreenEffects.PARAM_VIGNETTE
