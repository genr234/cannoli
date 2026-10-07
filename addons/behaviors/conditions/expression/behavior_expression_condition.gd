@tool
@icon("res://addons/behaviors/icons/expression.svg")
class_name BehaviorExpressionCondition
extends BehaviorCondition
## Succeeds when a Godot expression gives a result that is set: not null, false, zero
## or empty.
##
## The expression sees every variable by name, plus [code]actor[/code],
## [code]agent[/code], [code]delta[/code] and [code]globals[/code] (a dictionary of the global
## variables, as in [code]globals.alarm[/code]). Methods of the actor can be called
## directly. For example [code]health < 20 and not is_hidden[/code]. A parse or run
## error pushes a warning and fails the condition.

## The expression to check.
@export_multiline var expression: String = ""

const Util := preload("res://addons/behaviors/actions/expression/behavior_expression_util.gd")

var _util := Util.new()


func _on_update(delta: float) -> Status:
	if not _util.run(self, expression, delta):
		return Status.FAILURE
	return Status.SUCCESS if Behaviors.is_set(_util.result) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if expression.strip_edges().is_empty():
		warnings.append("Expression Condition has no expression.")
	return warnings


func _get_graph_text() -> String:
	var text := expression.strip_edges().replace("\n", " ")
	return text.substr(0, 31) + "…" if text.length() > 32 else text
