@tool
@icon("res://addons/behaviors/icons/expression.svg")
class_name BehaviorEvaluateExpression
extends BehaviorAction
## Runs a Godot expression and can store its result in a variable.
##
## The expression sees every variable by name, plus [code]actor[/code],
## [code]agent[/code], [code]delta[/code] and [code]globals[/code] (a dictionary of the global
## variables, as in [code]globals.alarm[/code]). Methods of the actor can be called
## directly. For example [code]health - 10[/code], [code]get_node("Gun").ammo[/code]
## or [code]global_position.distance_to(target.global_position)[/code].
## Variables whose names are not valid identifiers are not available. Read globals
## through [code]globals[/code] instead of the [code]global/[/code] prefix. A parse or
## run error pushes a warning and fails the task.

## The expression to run.
@export_multiline var expression: String = ""
## The variable that receives the result. Empty keeps nothing.
@export var store_in: String = ""
## Fails the task when the result is null, false, zero or empty.
@export var fail_on_false: bool = false

const Util := preload("res://addons/behaviors/actions/expression/behavior_expression_util.gd")

var _util := Util.new()


func _on_update(delta: float) -> Status:
	if not _util.run(self, expression, delta):
		return Status.FAILURE
	if not store_in.is_empty():
		set_var(StringName(store_in), _util.result)
	if fail_on_false and not Behaviors.is_set(_util.result):
		return Status.FAILURE
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if expression.strip_edges().is_empty():
		warnings.append("Evaluate Expression has no expression.")
	return warnings


func _get_graph_text() -> String:
	var text := expression.strip_edges().replace("\n", " ")
	if text.length() > 32:
		text = text.substr(0, 31) + "…"
	return "%s = %s" % [store_in, text] if not store_in.is_empty() else text
