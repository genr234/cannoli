class_name QuestTimerCondition
extends QuestCondition
## Counts a counter down once per second (see [method Quests.tick_timers]); true when it reaches zero.

## Counter that tracks the time left, in seconds.
@export var counter_name := ""

var _counter: QuestCounter


func get_editor_name() -> String:
	return "Timer: " + counter_name if not counter_name.is_empty() else "Timer"


func start_checking(true_callback: Callable) -> void:
	super.start_checking(true_callback)
	_counter = quest.get_counter(counter_name) if quest != null else null
	Quests.register_timer(self)


func stop_checking() -> void:
	super.stop_checking()
	Quests.unregister_timer(self)


## Counts the counter down by one second.
func tick() -> void:
	if _counter == null:
		return
	_counter.set_value(_counter.current_value - 1)
	if _counter.current_value <= 0:
		if Quests.debug:
			print("Quests: QuestTimerCondition '%s' ran out. Setting condition true." % _counter.name)
		set_true()

