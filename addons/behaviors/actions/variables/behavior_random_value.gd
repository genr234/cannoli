@tool
@icon("res://addons/behaviors/icons/random.svg")
class_name BehaviorRandomValue
extends BehaviorAction
## Stores a random value in a variable.

## What kind of value to make.
enum Mode {
	## A float between [member min_value] and [member max_value].
	FLOAT,
	## A whole number between [member min_value] and [member max_value], both included.
	INT,
	## True with the odds of [member chance].
	BOOL,
	## One element of the array in [member array_variable].
	ARRAY_ELEMENT,
}

## What kind of value to make.
@export var mode: Mode = Mode.FLOAT:
	set(new_mode):
		mode = new_mode
		notify_property_list_changed()
## The variable that receives the value.
@export var store_in: String = ""
## The lowest value.
@export var min_value: float = 0.0
## The highest value.
@export var max_value: float = 1.0
## The chance of true, from 0 to 1.
@export_range(0.0, 1.0, 0.01) var chance: float = 0.5
## The variable holding the array to pick from.
@export var array_variable: String = ""
## Uses [member seed_value], so every run gives the same numbers.
@export var use_seed: bool = false
## The seed, used when [member use_seed] is true.
@export var seed_value: int = 0

var _random := RandomNumberGenerator.new()


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"min_value", "max_value":
			if mode != Mode.FLOAT and mode != Mode.INT:
				property.usage = PROPERTY_USAGE_STORAGE
		"chance":
			if mode != Mode.BOOL:
				property.usage = PROPERTY_USAGE_STORAGE
		"array_variable":
			if mode != Mode.ARRAY_ELEMENT:
				property.usage = PROPERTY_USAGE_STORAGE
		"seed_value":
			if not use_seed:
				property.usage = PROPERTY_USAGE_STORAGE


func _on_awake() -> void:
	if use_seed:
		_random.seed = seed_value
	else:
		_random.randomize()


func _on_update(_delta: float) -> Status:
	if store_in.is_empty():
		return Status.FAILURE
	var result: Variant
	match mode:
		Mode.FLOAT:
			result = _random.randf_range(minf(min_value, max_value), maxf(min_value, max_value))
		Mode.INT:
			result = _random.randi_range(int(minf(min_value, max_value)), int(maxf(min_value, max_value)))
		Mode.BOOL:
			result = _random.randf() < chance
		Mode.ARRAY_ELEMENT:
			var items: Variant = get_var(StringName(array_variable))
			if not items is Array or (items as Array).is_empty():
				return Status.FAILURE
			result = items[_random.randi_range(0, items.size() - 1)]
	set_var(StringName(store_in), result)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if store_in.is_empty():
		warnings.append("Random Value has no variable to store in.")
	if mode == Mode.ARRAY_ELEMENT and array_variable.is_empty():
		warnings.append("Random Value has no array variable.")
	return warnings


func _get_graph_text() -> String:
	match mode:
		Mode.FLOAT, Mode.INT:
			return "%s: %s–%s" % [store_in, min_value, max_value]
		Mode.BOOL:
			return "%s: %d%%" % [store_in, roundi(chance * 100.0)]
	return "%s ← %s" % [store_in, array_variable]
