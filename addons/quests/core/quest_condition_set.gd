class_name QuestConditionSet
extends Resource
## A group of conditions and the rule for when the group counts as true.

enum Mode { ANY, ALL, MIN }

@export var condition_list: Array[QuestCondition]
@export var condition_count_mode := Mode.ALL
## For [constant Mode.MIN], how many conditions must be true.
@export var min_condition_count := 1

## How many conditions have become true. Runtime only; saved with the quest.
var num_true_conditions := 0

var _true_callback := Callable()
var _is_checking := false


## True if the set has no conditions, or its rule is satisfied.
var are_conditions_met: bool:
	get:
		if condition_list.is_empty():
			return true
		match condition_count_mode:
			Mode.ALL:
				return num_true_conditions >= condition_list.size()
			Mode.ANY:
				return num_true_conditions > 0
			Mode.MIN:
				return num_true_conditions >= min_condition_count
		return false

var is_empty: bool:
	get:
		return condition_list.is_empty()


func set_runtime_references(quest: Quest, node: QuestNode) -> void:
	for condition in condition_list:
		if condition != null:
			condition.set_runtime_references(quest, node)


## Starts every condition that isn't already true. [param true_callback] is
## called when the set's rule becomes satisfied.
func start_checking(true_callback: Callable) -> void:
	if _is_checking:
		return
	_is_checking = true
	_true_callback = true_callback
	for condition in condition_list.duplicate():
		if condition != null and not condition.already_true:
			condition.start_checking(_on_condition_true)


func stop_checking() -> void:
	if not _is_checking:
		return
	for condition in condition_list:
		if condition != null:
			condition.stop_checking()
	_is_checking = false


## Stops checking and sets every condition back to false.
func reset_conditions() -> void:
	stop_checking()
	for condition in condition_list:
		if condition != null:
			condition.reset_condition()
	_is_checking = false
	num_true_conditions = 0


func _on_condition_true() -> void:
	num_true_conditions += 1
	if are_conditions_met and _true_callback.is_valid():
		_true_callback.call()


## Number of conditions in [param condition_set], or 0 if it is null.
static func condition_count(condition_set: QuestConditionSet) -> int:
	return condition_set.condition_list.size() if condition_set != null else 0
