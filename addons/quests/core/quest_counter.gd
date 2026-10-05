@icon("../icons/quest_counter.svg")
class_name QuestCounter
extends Resource
## An integer value kept by a quest, such as how many wolves have been killed.
##
## A counter changes through messages. In [constant UpdateMode.MESSAGES] mode it
## listens for the "Set Quest Counter" and "Increment Quest Counter" messages
## (parameter = counter name) and for its [member message_event_list]. In
## [constant UpdateMode.DATA_SYNC] mode it mirrors an external value that is
## reported with the "Data Source Value Changed" message.

enum UpdateMode { DATA_SYNC, MESSAGES }
enum SetMode { INFORM_LISTENERS, DONT_INFORM_LISTENERS, DONT_INFORM_DATA_SYNC }

## Emitted when the value changes, unless set with [constant SetMode.DONT_INFORM_LISTENERS].
## ([Resource] already has a signal named changed, so this one has another name.)
signal value_changed(counter: QuestCounter)

@export var name := ""
@export var initial_value := 0
@export var randomize_initial_value := false
@export var min_value := 0
@export var max_value := 100
@export var update_mode := UpdateMode.MESSAGES
@export var message_event_list: Array[QuestCounterMessageEvent]
## Label for the quest's automatic objectives. Counters with no display name
## aren't shown as objectives.
@export var display_name := ""
## The number the objective counts up to. If null, [member max_value] is used.
@export var objective_goal: QuestNumber

## The current value. Setting it behaves like [method set_value].
var current_value: int:
	get:
		return _current_value
	set(value):
		set_value(value)

var _current_value := 0
var _is_listening := false
var _quest_ref: WeakRef


static func create(p_name: String, p_initial := 0, p_min := 0, p_max := 100,
		p_update_mode := UpdateMode.MESSAGES) -> QuestCounter:
	var result := QuestCounter.new()
	result.name = p_name
	result.initial_value = p_initial
	result.min_value = p_min
	result.max_value = p_max
	result.update_mode = p_update_mode
	result._current_value = p_initial
	return result


func get_quest() -> Quest:
	return _quest_ref.get_ref() as Quest if _quest_ref != null else null


func set_runtime_references(quest: Quest) -> void:
	_quest_ref = weakref(quest) if quest != null else null


## Sets the value back to [member initial_value] without telling anyone.
func reset() -> void:
	_current_value = clampi(initial_value, min_value, max_value)


func set_random_value() -> void:
	if randomize_initial_value:
		_current_value = randi_range(min_value, max_value)


## The goal for objectives: [member objective_goal] or [member max_value].
func get_goal(quest: Quest = null) -> int:
	if objective_goal != null:
		return objective_goal.get_value(quest if quest != null else get_quest())
	return max_value


func set_value(new_value: int, mode := SetMode.INFORM_LISTENERS) -> void:
	var clamped := clampi(new_value, min_value, max_value)
	if clamped == _current_value:
		return
	_current_value = clamped
	if mode == SetMode.DONT_INFORM_LISTENERS:
		return
	var quest := get_quest()
	var inform_data_sync := update_mode == UpdateMode.DATA_SYNC and mode != SetMode.DONT_INFORM_DATA_SYNC
	if inform_data_sync:
		QuestMessages.send(self, null, QuestMessages.REQUEST_DATA_SOURCE_CHANGE_VALUE, name, [_current_value])
	QuestMessages.quest_counter_changed(self, quest.id if quest != null else "", name, _current_value)
	value_changed.emit(self)
	if quest != null:
		quest.counter_changed.emit(quest, self)
		var manager := Quests.get_manager()
		if manager != null:
			manager.quest_counter_changed.emit(quest, self)


## Starts or stops listening for the messages that change this counter.
func set_listeners(enable: bool) -> void:
	if enable == _is_listening:
		return
	_is_listening = enable
	if not enable:
		QuestMessages.remove_listener(self)
		return
	var quest := get_quest()
	match update_mode:
		UpdateMode.DATA_SYNC:
			QuestMessages.add_listener(self, QuestMessages.DATA_SOURCE_VALUE_CHANGED, name, _on_message)
		UpdateMode.MESSAGES:
			# Accept every parameter; _on_message picks out the two documented forms.
			QuestMessages.add_listener(self, QuestMessages.SET_QUEST_COUNTER, "", _on_message)
			QuestMessages.add_listener(self, QuestMessages.INCREMENT_QUEST_COUNTER, "", _on_message)
	for event in message_event_list:
		if event != null:
			QuestMessages.add_listener(self, QuestTags.replace_tags(event.message, quest),
					QuestTags.replace_tags(event.parameter, quest), _on_message)


func _on_message(args: QuestMessageArgs) -> void:
	if Quests.debug:
		print("Quests: QuestCounter[%s]._on_message(%s, %s)" % [name, args.message, args.parameter])
	var quest := get_quest()
	var new_value := _current_value
	match args.message:
		QuestMessages.DATA_SOURCE_VALUE_CHANGED:
			new_value = args.int_value()
		QuestMessages.SET_QUEST_COUNTER:
			var amount: Variant = _get_message_amount(args)
			if amount == null:
				return
			new_value = amount
		QuestMessages.INCREMENT_QUEST_COUNTER:
			var amount: Variant = _get_message_amount(args)
			if amount == null:
				return
			new_value += amount
		_:
			for event in message_event_list:
				if event == null:
					continue
				if not (args.matches(QuestTags.replace_tags(event.message, quest), QuestTags.replace_tags(event.parameter, quest))
						and QuestMessages.is_required_id(args.sender, QuestTags.replace_tags(event.get_sender_id(), quest))
						and QuestMessages.is_required_id(args.target, QuestTags.replace_tags(event.get_target_id(), quest))):
					continue
				match event.operation:
					QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE:
						new_value += event.literal_value
					QuestCounterMessageEvent.Operation.MODIFY_BY_MESSAGE_VALUE:
						new_value += args.int_value()
					QuestCounterMessageEvent.Operation.SET_TO_LITERAL_VALUE:
						new_value = event.literal_value
					QuestCounterMessageEvent.Operation.SET_TO_MESSAGE_VALUE:
						new_value = args.int_value()
	set_value(new_value, SetMode.DONT_INFORM_DATA_SYNC)


## The number carried by a set/increment message addressed to this counter, or
## null if it is for another counter. Two forms are accepted: parameter =
## counter name with the number as first value, or parameter = quest id with
## the counter name and number as the first two values.
func _get_message_amount(args: QuestMessageArgs) -> Variant:
	if args.parameter == name and typeof(args.first_value()) == TYPE_INT:
		return args.first_value()
	var quest := get_quest()
	if quest != null and args.parameter == quest.id and args.values.size() >= 2 \
			and str(args.values[0]) == name and typeof(args.values[1]) == TYPE_INT:
		return args.values[1]
	return null
