@tool
@icon("res://addons/behaviors/icons/variable.svg")
class_name BehaviorOperateVariable
extends BehaviorAction
## Does math on a variable: [code]variable = variable <operation> operand[/code].
##
## Works on ints, floats, vectors, colors, and strings (add joins text). The operand
## is a constant or another variable. Mixed int and float math gives a float. A
## combination that makes no sense, such as dividing by zero or subtracting from text,
## fails the task and leaves the variable unchanged.

## What to do with the two values.
enum Operation {
	## Add. Joins text.
	ADD,
	SUBTRACT,
	MULTIPLY,
	## Divide. Dividing two ints gives an int.
	DIVIDE,
	## The remainder. Numbers only.
	MODULO,
	## Raise to a power. Numbers only.
	POWER,
	## The smaller of both. Numbers and vectors.
	MIN,
	## The larger of both. Numbers and vectors.
	MAX,
	## Ignore the left value and use the operand.
	SET,
}

## The variable to change. It is the left value unless [member left_variable] is set.
@export var variable: String = ""
## What to do with the two values.
@export var operation: Operation = Operation.ADD
## Read the left value from this variable instead. Use it with [member store_in].
@export var left_variable: String = ""
## Write the result here instead of into [member variable].
@export var store_in: String = ""
## When set, the operand is read from this variable and [member value] is ignored.
@export var operand_variable: String = ""
## The type of [member value].
@export var value_type: Variant.Type = TYPE_FLOAT:
	set(new_type):
		value_type = new_type
		value = BehaviorVariable._convert(value, new_type)
		notify_property_list_changed()

## The constant operand.
var value: Variant = 0.0


func _get_property_list() -> Array[Dictionary]:
	return [{"name": "value", "type": value_type, "usage": PROPERTY_USAGE_DEFAULT}]


func _on_update(_delta: float) -> Status:
	var left_name := left_variable if not left_variable.is_empty() else variable
	var target := store_in if not store_in.is_empty() else variable
	if left_name.is_empty() or target.is_empty():
		return Status.FAILURE
	var operand: Variant = get_var(StringName(operand_variable)) if not operand_variable.is_empty() else value
	var result: Variant = calculate(get_var(StringName(left_name)), operation, operand)
	if typeof(result) == TYPE_NIL:
		return Status.FAILURE
	set_var(StringName(target), result)
	return Status.SUCCESS


## The result of [code]left <operation> right[/code], or null when the values cannot be
## combined.
static func calculate(left: Variant, operation: Operation, right: Variant) -> Variant:
	if operation == Operation.SET:
		return right
	var left_type := typeof(left)
	var right_type := typeof(right)
	if left_type == TYPE_STRING or left_type == TYPE_STRING_NAME:
		return str(left) + str(right) if operation == Operation.ADD else null
	var left_number := left_type == TYPE_INT or left_type == TYPE_FLOAT
	var right_number := right_type == TYPE_INT or right_type == TYPE_FLOAT
	if left_number and right_number:
		return _calculate_numbers(left, operation, right)
	if not _is_vector(left_type):
		return null
	var integer_vector := left_type in [TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I]
	if right_type == left_type:
		match operation:
			Operation.ADD: return left + right
			Operation.SUBTRACT: return left - right
			Operation.MULTIPLY: return left * right
			Operation.DIVIDE:
				return null if integer_vector and _has_zero(right) else left / right
			Operation.MIN: return left.min(right) if left_type != TYPE_COLOR else null
			Operation.MAX: return left.max(right) if left_type != TYPE_COLOR else null
		return null
	if not right_number:
		return null
	if integer_vector and right_type != TYPE_INT:
		return null
	match operation:
		Operation.MULTIPLY: return left * right
		Operation.DIVIDE:
			return null if integer_vector and right == 0 else left / right
	return null


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if variable.is_empty() and (left_variable.is_empty() or store_in.is_empty()):
		warnings.append("Operate Variable needs a variable, or a left variable and a store in.")
	return warnings


func _get_graph_text() -> String:
	var symbol: String = ["+", "-", "×", "÷", "%", "^", "min", "max", "="][operation]
	var operand := operand_variable if not operand_variable.is_empty() else var_to_str(value)
	var target := store_in if not store_in.is_empty() else variable
	return "%s %s %s" % [target, symbol, operand]


static func _calculate_numbers(left: Variant, operation: Operation, right: Variant) -> Variant:
	var integers := typeof(left) == TYPE_INT and typeof(right) == TYPE_INT
	match operation:
		Operation.ADD: return left + right
		Operation.SUBTRACT: return left - right
		Operation.MULTIPLY: return left * right
		Operation.DIVIDE:
			if right == 0:
				return null
			return left / right
		Operation.MODULO:
			if right == 0:
				return null
			return left % right if integers else fmod(left, right)
		Operation.POWER:
			var power := pow(left, right)
			if is_nan(power) or is_inf(power):
				return null
			return int(power) if integers and right >= 0 else power
		Operation.MIN: return min(left, right)
		Operation.MAX: return max(left, right)
	return null


static func _is_vector(type: Variant.Type) -> bool:
	return type in [TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_COLOR]


static func _has_zero(vector: Variant) -> bool:
	for index in _size_of(vector):
		if vector[index] == 0:
			return true
	return false


static func _size_of(vector: Variant) -> int:
	match typeof(vector):
		TYPE_VECTOR2, TYPE_VECTOR2I: return 2
		TYPE_VECTOR3, TYPE_VECTOR3I: return 3
	return 4
