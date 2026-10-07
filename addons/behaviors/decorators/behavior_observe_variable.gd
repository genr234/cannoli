@tool
@icon("res://addons/behaviors/icons/observe.svg")
class_name BehaviorObserveVariable
extends BehaviorDecorator
## Runs its child only while a variable passes a check, and reacts the moment it
## changes.
##
## When the check fails at the start, the child does not run and this task fails.
## With [member abort_type] SELF, the running child is stopped as soon as the check
## stops passing. With LOWER_PRIORITY, a change of the check's result interrupts
## tasks to the right of this one while they run, and the tree goes back here. The
## variable is only checked again after it changes, so observers are cheap.

## The variable to check. Use [code]global/[/code] for global variables.
@export var variable: String = ""
## How to compare the variable with [member value].
@export var operator: Behaviors.Operator = Behaviors.Operator.IS_SET:
	set(new_operator):
		operator = new_operator
		notify_property_list_changed()
## The type of [member value].
@export var value_type: Variant.Type = TYPE_FLOAT:
	set(new_type):
		value_type = new_type
		value = BehaviorVariable._convert(value, new_type)
		notify_property_list_changed()
## Which running tasks a change can interrupt.
@export var abort_type: BehaviorComposite.AbortType = BehaviorComposite.AbortType.SELF

## The value to compare with.
var value: Variant = 0.0

var _dirty: bool = true
var _passing: bool = false


func _get_property_list() -> Array[Dictionary]:
	var usage := PROPERTY_USAGE_DEFAULT
	if operator == Behaviors.Operator.IS_SET or operator == Behaviors.Operator.IS_NOT_SET:
		usage = PROPERTY_USAGE_STORAGE
	return [{"name": "value", "type": value_type, "usage": usage}]


func _validate_property(property: Dictionary) -> void:
	if property.name == "value_type" and (operator == Behaviors.Operator.IS_SET or operator == Behaviors.Operator.IS_NOT_SET):
		property.usage = PROPERTY_USAGE_STORAGE


func _on_awake() -> void:
	if blackboard == null:
		return
	var board := blackboard
	if String(variable).begins_with(BehaviorBlackboard.GLOBAL_PREFIX):
		board = Behaviors.get_globals()
	board.value_changed.connect(_on_value_changed)


## True when the variable passes the check now.
func check() -> bool:
	var name := StringName(variable)
	var current: Variant = get_var(name)
	return Behaviors.compare(current, operator, value)


func _execute(delta: float) -> Status:
	if _running_child < 0:
		_passing = check()
		_dirty = false
		if not _passing:
			return Status.FAILURE
	elif _self_abort() and _is_dirty():
		_dirty = false
		_passing = check()
		if not _passing:
			var interrupted := get_child()
			_abort_children()
			if agent:
				agent._task_aborted_by(self, interrupted)
			return Status.FAILURE
	return super(delta)


func _finish(result: Status) -> void:
	super(result)
	_observed = Status.SUCCESS if _passing else Status.FAILURE


func _reevaluate(_delta: float) -> bool:
	if _observed == Status.INACTIVE or not _is_dirty():
		return false
	_dirty = false
	var now := Status.SUCCESS if check() else Status.FAILURE
	if agent:
		agent._task_reevaluated(self, now)
	if now == _observed:
		return false
	_observed = now
	return true


func _observes_lower_priority() -> bool:
	return abort_type == BehaviorComposite.AbortType.LOWER_PRIORITY or abort_type == BehaviorComposite.AbortType.BOTH


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if variable.is_empty():
		warnings.append("Observe Variable has no variable.")
	return warnings


func _get_graph_text() -> String:
	var symbol: String = ["==", "!=", "<", "<=", ">", ">=", "is set", "is not set"][operator]
	if operator == Behaviors.Operator.IS_SET or operator == Behaviors.Operator.IS_NOT_SET:
		return "%s %s" % [variable, symbol]
	return "%s %s %s" % [variable, symbol, var_to_str(value)]


func _self_abort() -> bool:
	return abort_type == BehaviorComposite.AbortType.SELF or abort_type == BehaviorComposite.AbortType.BOTH


# Mapped variables change without a signal, so they are always checked.
func _is_dirty() -> bool:
	if _dirty:
		return true
	var declaration := blackboard.get_declaration(StringName(variable)) if blackboard else null
	return declaration != null and declaration.is_mapped()


func _on_value_changed(changed: StringName, _value: Variant) -> void:
	var name := String(variable)
	if name.begins_with(BehaviorBlackboard.GLOBAL_PREFIX):
		name = name.substr(BehaviorBlackboard.GLOBAL_PREFIX.length())
	if String(changed) == name:
		_dirty = true
