@tool
@icon("res://addons/behaviors/icons/conditional_evaluator.svg")
class_name BehaviorConditionalEvaluator
extends BehaviorDecorator
## Checks a condition before running its child. If the condition fails, the child
## does not run and this task fails. With [member reevaluate], the condition is
## checked every tick and failing it stops the child.

## The condition to check. Edit it in place in the inspector.
@export var condition: BehaviorCondition
## Checks the condition every tick while the child runs.
@export var reevaluate: bool = false
## Shows the condition's name on the task in the graph.
@export var graph_label: bool = true

var _checked: bool = false


func _get_inline_tasks() -> Array[BehaviorTask]:
	return [condition] if condition else []


func _execute(delta: float) -> Status:
	if condition and (not _checked or reevaluate):
		_checked = true
		var result := condition.tick(delta)
		if result == Status.RUNNING:
			return result
		if result != Status.SUCCESS:
			_abort_children()
			return Status.FAILURE
	return super(delta)


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if condition == null:
		warnings.append("Conditional Evaluator has no condition.")
	return warnings


func _get_graph_text() -> String:
	return condition.get_display_name() if condition and graph_label else ""


func _on_end() -> void:
	_checked = false
