@tool
@icon("res://addons/behaviors/icons/subtree.svg")
class_name BehaviorSubtree
extends BehaviorDecorator
## Runs another [BehaviorTree] in place of this task.
##
## The other tree's tasks run as if they were part of this one. Its variables that
## share a name with a variable of this tree use this tree's value. The rest belong
## to the subtree. [member variable_overrides] gives this reference its own values,
## so two references to the same tree can behave differently.

## The tree to run.
@export var tree: BehaviorTree
## Values for the subtree's variables, for this reference only.
@export var variable_overrides: Dictionary[StringName, Variant] = {}

var _board: BehaviorBlackboard


func max_children() -> int:
	return 0


func _build() -> void:
	children = []
	_board = null
	if tree == null or tree.root == null or blackboard == null:
		return
	if _is_recursive():
		push_error("Subtree \"%s\" runs itself and was skipped." % tree.resource_path)
		return
	_board = BehaviorBlackboard.new([], actor, blackboard)
	for variable in tree.variables:
		if variable and not blackboard.has_value(variable.name):
			_board.declare(variable)
	for variable in variable_overrides:
		_board.set_local(variable, variable_overrides[variable])
	children = [tree.instantiate()]


func _get_child_blackboard() -> BehaviorBlackboard:
	return _board if _board else blackboard


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tree == null:
		warnings.append("Subtree has no tree.")
	elif tree.root == null:
		warnings.append("The subtree's tree is empty.")
	return warnings


func _get_graph_text() -> String:
	if tree == null:
		return ""
	return tree.resource_path.get_file().get_basename() if not tree.resource_path.is_empty() else tree.resource_name


func _is_recursive() -> bool:
	var parent := get_parent_task()
	while parent:
		if parent is BehaviorSubtree and (parent as BehaviorSubtree).tree == tree:
			return true
		parent = parent.get_parent_task()
	return agent != null and agent.tree == tree
