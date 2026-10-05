class_name QuestExpressionCondition
extends QuestCondition
## True when a Godot [Expression] evaluates to a true value.
##
## The expression runs on a [QuestExpressionContext], so its helpers can be called
## directly, for example [code]counter("", "wolves") >= 3 and is_state("intro", "successful")[/code].
## It is checked when the condition starts, on every quest message and at an interval.

## The expression to evaluate.
@export_multiline var expression := ""
## Seconds between checks. 0 disables polling.
@export var check_interval := 0.5
## Also check whenever any quest message is sent.
@export var check_on_messages := true

var _expression: Expression
var _context: QuestExpressionContext
var _parse_failed := false
var _generation := 0
var _manager: QuestManager


func get_editor_name() -> String:
	return "Expression: " + expression.strip_edges() if not expression.strip_edges().is_empty() else "Expression"


func set_runtime_references(p_quest: Quest, p_node: QuestNode) -> void:
	super.set_runtime_references(p_quest, p_node)
	_context = null
	_expression = null
	_parse_failed = false


func start_checking(true_callback: Callable) -> void:
	super.start_checking(true_callback)
	if not _parse():
		return
	if evaluate():
		set_true()
		return
	_generation += 1
	_manager = Quests.get_manager()
	if check_on_messages and _manager != null and not _manager.message_sent.is_connected(_on_message_sent):
		_manager.message_sent.connect(_on_message_sent)
	if check_interval > 0.0:
		_poll(_generation)


func stop_checking() -> void:
	super.stop_checking()
	_generation += 1
	if _manager != null and is_instance_valid(_manager) and _manager.message_sent.is_connected(_on_message_sent):
		_manager.message_sent.disconnect(_on_message_sent)
	_manager = null


## Evaluates the expression now. Errors are reported once and count as false.
func evaluate() -> bool:
	if not _parse():
		return false
	var result: Variant = _expression.execute([], _context, false)
	if _expression.has_execute_failed():
		push_warning("Quests: Expression '%s' failed: %s" % [expression, _expression.get_error_text()])
		return false
	return bool(result)


func _parse() -> bool:
	if _expression != null:
		return true
	if _parse_failed or expression.strip_edges().is_empty():
		return false
	_context = QuestExpressionContext.new(quest)
	var parsed := Expression.new()
	var error := parsed.parse(expression)
	if error != OK:
		_parse_failed = true
		push_warning("Quests: Can't parse expression '%s': %s" % [expression, parsed.get_error_text()])
		return false
	_expression = parsed
	return true


func _poll(generation: int) -> void:
	var tree := QuestSceneLookup.get_tree()
	while tree != null and is_checking and generation == _generation:
		await tree.create_timer(check_interval).timeout
		if not is_checking or generation != _generation:
			return
		if evaluate():
			set_true()
			return


func _on_message_sent(_args: QuestMessageArgs) -> void:
	if is_checking and evaluate():
		set_true()
