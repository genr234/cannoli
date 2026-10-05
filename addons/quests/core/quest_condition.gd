class_name QuestCondition
extends QuestSubasset
## Base class for a condition that a [QuestConditionSet] checks.
##
## Subclasses start listening for their trigger in [method start_checking] and
## call [method set_true] when it happens.

## True once the condition has been met. Saved with the quest.
var already_true := false
var is_checking := false

var _true_callback := Callable()


func set_runtime_references(p_quest: Quest, p_node: QuestNode) -> void:
	super(p_quest, p_node)
	is_checking = false


## Virtual. Begins checking; [param true_callback] is called (with no
## arguments) when the condition becomes true. Call super.
func start_checking(true_callback: Callable) -> void:
	is_checking = true
	_true_callback = true_callback


## Virtual. Stops checking. Call super.
func stop_checking() -> void:
	is_checking = false


## Marks the condition true, stops checking and invokes the callback once.
func set_true() -> void:
	if already_true:
		return
	if Quests.debug:
		print("Quests: %s.set_true()" % get_type_name())
	already_true = true
	stop_checking()
	if _true_callback.is_valid():
		_true_callback.call()


## Stops checking and marks the condition false again. (Not named reset_state,
## which [Resource] already has.)
func reset_condition() -> void:
	stop_checking()
	already_true = false
