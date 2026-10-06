@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuicePropertyShake
extends JuiceFeedback
## Shakes a number, vector or color property on the nodes that have a [JuicePropertyShaker].
##
## The shaker says which node and property to shake. This feedback says how: the curve, the
## two values it maps to, and how long it takes. Intensity scales the change.
##
## Broadcasts [code]juice_property_shake[/code]. Payload keys: [code]duration[/code], [code]curve[/code],
## [code]remap_zero[/code], [code]remap_one[/code], [code]relative[/code], [code]amount[/code].

@export_group("Property Shake")
## Seconds the shake lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve over the shake. Empty is a bump that rises and falls.
@export var curve: Curve
## The value at curve value 0. Its type must match the property.
@export var remap_zero: Variant = 0.0
## The value at curve value 1. Its type must match the property.
@export var remap_one: Variant = 1.0
## Adds the remapped value to the property instead of moving the property to it.
@export var relative: bool = false


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_SHAKE


func _has_channel() -> bool:
	return true


func _has_range() -> bool:
	return true


func _has_randomness() -> bool:
	return true


func _on_play(feedback_intensity: float) -> void:
	broadcast(JuicePropertyShaker.EVENT, {
		"duration": get_feedback_duration(),
		"curve": curve,
		"remap_zero": remap_zero,
		"remap_one": remap_one,
		"relative": relative,
		"amount": feedback_intensity,
	})


func _on_stop() -> void:
	broadcast(JuicePropertyShaker.EVENT, {"stop": true})


func _on_restore() -> void:
	broadcast(JuicePropertyShaker.EVENT, {"restore": true})
