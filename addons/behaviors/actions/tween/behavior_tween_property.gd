@tool
@icon("res://addons/behaviors/icons/tween.svg")
class_name BehaviorTweenProperty
extends BehaviorAction
## Animates a property to a value over time. Fails when the target or the property is
## missing.

## The node to animate, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the object to animate. Replaces [member target] when set.
@export var target_variable: String = ""
## The property, such as [code]modulate[/code] or [code]position:x[/code].
@export var property: String = ""
## When set, the final value is read from this variable when the task starts and
## [member value] is ignored.
@export var source_variable: String = ""
## The type of [member value].
@export var value_type: Variant.Type = TYPE_FLOAT:
	set(new_type):
		value_type = new_type
		value = BehaviorVariable._convert(value, new_type)
		notify_property_list_changed()
## How long the animation takes.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var duration: float = 1.0
## The curve of the animation.
@export var transition: Tween.TransitionType = Tween.TRANS_LINEAR
## How the curve eases.
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
## Adds the final value to the current one instead of replacing it.
@export var relative: bool = false
## Keeps running until the tween ends, and stops it when interrupted. When false, the
## task succeeds right away and the tween finishes on its own.
@export var wait_for_finish: bool = true

## The final value.
var value: Variant = 0.0

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")

var _tween: Tween


func _get_property_list() -> Array[Dictionary]:
	return [{"name": "value", "type": value_type, "usage": PROPERTY_USAGE_DEFAULT}]


func _on_start() -> void:
	_tween = null
	var object := Targets.resolve(self, target, target_variable)
	if object == null or property.is_empty() or actor == null:
		return
	if not Targets.has_property(object, property):
		Targets.warn_once(self, "%s has no property \"%s\"." % [object, property])
		return
	var final: Variant = get_var(StringName(source_variable)) if not source_variable.is_empty() else value
	var current: Variant = object.get_indexed(NodePath(property))
	# Tweens refuse mismatched types, such as an int property with a float value.
	if current != null and typeof(final) != typeof(current):
		final = BehaviorVariable._convert(final, typeof(current))
	var tween := (object as Node).create_tween() if object is Node else actor.create_tween()
	var step := tween.tween_property(object, NodePath(property), final, duration)
	step.set_trans(transition).set_ease(easing)
	if relative:
		step.as_relative()
	_tween = tween


func _on_update(_delta: float) -> Status:
	if _tween == null:
		return Status.FAILURE
	if wait_for_finish and _tween.is_valid() and _tween.is_running():
		return Status.RUNNING
	return Status.SUCCESS


func _on_end() -> void:
	if wait_for_finish and _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if property.is_empty():
		warnings.append("Tween Property has no property.")
	return warnings


func _get_graph_text() -> String:
	var final := source_variable if not source_variable.is_empty() else var_to_str(value)
	return "%s → %s (%ss)" % [property, final, duration]
