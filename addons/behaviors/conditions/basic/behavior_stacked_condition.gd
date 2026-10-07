@tool
@icon("res://addons/behaviors/icons/stacked_condition.svg")
class_name BehaviorStackedCondition
extends BehaviorCondition
## Checks several conditions in one node. With [constant Mode.SEQUENCE] every
## one must succeed. With [constant Mode.SELECTOR] the first success wins.

## How the stacked tasks combine.
enum Mode {
	## Like an "and": fails at the first failure.
	SEQUENCE,
	## Like an "or": succeeds at the first success.
	SELECTOR,
}

## The stacked tasks. Edit them in place in the inspector.
@export var conditions: Array[BehaviorCondition] = []
## How the stacked tasks combine.
@export var mode: Mode = Mode.SEQUENCE
## Lists the stacked tasks on the node in the graph.
@export var graph_label: bool = true

var _index: int = 0


func _get_inline_tasks() -> Array[BehaviorTask]:
	var tasks: Array[BehaviorTask] = []
	for task in conditions:
		if task:
			tasks.append(task)
	return tasks


func _on_start() -> void:
	_index = 0


func _on_update(delta: float) -> Status:
	while _index < conditions.size():
		var task := conditions[_index]
		if task == null:
			_index += 1
			continue
		var result := task.tick(delta)
		if result == Status.RUNNING:
			return result
		_index += 1
		if mode == Mode.SEQUENCE and result == Status.FAILURE:
			return result
		if mode == Mode.SELECTOR and result == Status.SUCCESS:
			return result
	return Status.SUCCESS if mode == Mode.SEQUENCE else Status.FAILURE


func _abort_children() -> void:
	if _index < conditions.size() and conditions[_index]:
		conditions[_index].abort()


func _get_graph_text() -> String:
	if not graph_label:
		return ""
	var names := PackedStringArray()
	for task in conditions:
		if task:
			names.append(task.get_display_name())
	return "\n".join(names)
