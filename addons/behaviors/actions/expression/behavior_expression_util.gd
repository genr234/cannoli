@tool
extends RefCounted
## Parses and runs one expression for a task. Used by [BehaviorEvaluateExpression] and
## [BehaviorExpressionCondition].
##
## Not a task. The expression sees every variable on the blackboard (and its parents)
## by name, plus [code]actor[/code], [code]agent[/code], [code]delta[/code] and
## [code]globals[/code], a dictionary of the global variables
## ([code]globals.alarm[/code]). Its base
## instance is the actor, so methods and [code]get_node()[/code] work directly.

# Names the expression parser reads as constants or keywords, never as inputs.
const _RESERVED: PackedStringArray = [
	"self", "true", "false", "null", "PI", "TAU", "INF", "NAN", "and", "or", "not", "in", "is", "as",
]

# Inputs every expression gets, after the variables.
const _BUILT_INS: PackedStringArray = ["actor", "agent", "delta", "globals"]

## What the last [method run] returned.
var result: Variant = null

var _expression := Expression.new()
var _parsed_text: String = ""
var _parsed_names := PackedStringArray()
var _parsed_ok: bool = false


## Runs [param text] for [param task]. Returns false, with a one-time warning, when it
## does not parse or fails while running. The value is in [member result].
func run(task: BehaviorTask, text: String, delta: float) -> bool:
	result = null
	if text.strip_edges().is_empty():
		return false
	var names := _collect_names(task)
	if not _parsed_ok and text == _parsed_text and names == _parsed_names:
		return false
	if text != _parsed_text or names != _parsed_names:
		var inputs := names.duplicate()
		inputs.append_array(_BUILT_INS)
		_parsed_text = text
		_parsed_names = names
		var error := _expression.parse(text, inputs)
		_parsed_ok = error == OK
		if not _parsed_ok:
			_warn(task, "cannot parse \"%s\": %s" % [text, _expression.get_error_text()])
			return false
	var values: Array = []
	for variable in names:
		values.append(task.get_var(StringName(variable)))
	values.append_array([task.actor, task.agent, delta, Behaviors.get_globals().to_dictionary()])
	result = _expression.execute(values, task.actor, false)
	if _expression.has_execute_failed():
		result = null
		_warn(task, "cannot run \"%s\": %s" % [text, _expression.get_error_text()])
		return false
	return true


# Variable names as expression inputs: the agent's blackboard and its parents, minus
# anything that is not an identifier. Sorted so the same set always compares equal.
func _collect_names(task: BehaviorTask) -> PackedStringArray:
	var found: Dictionary[String, bool] = {}
	var board := task.blackboard
	while board:
		for variable in board.get_names():
			var text := String(variable)
			if text.is_valid_ascii_identifier() and not text in _RESERVED and not text in _BUILT_INS:
				found[text] = true
		board = board.parent
	var names := PackedStringArray(found.keys())
	names.sort()
	return names


func _warn(task: BehaviorTask, message: String) -> void:
	# Once per distinct failure, so a broken expression does not flood the log.
	var key := &"_expression_warned"
	if task.has_meta(key) and task.get_meta(key) == message:
		return
	task.set_meta(key, message)
	push_warning("%s: %s" % [task.get_display_name(), message])
