class_name QuestIndicatorManager
extends Node
## Tracks the indicator state of every quest for a character and shows the
## highest-priority one on a [QuestIndicator].
##
## Put it on a character that has a [QuestIdentity] (as a child or sibling of it).
## It listens for [constant QuestMessages.SET_INDICATOR_STATE] messages and
## refreshes from all quests when told to.

## The indicator to drive. If empty, the first [QuestIndicator] child.
@export var indicator: QuestIndicator
## Show this state when the quest giver has a quest to offer.
@export var has_quest_to_offer_state := Quest.IndicatorState.OFFER
## Show this state when the quest giver only has quests whose offer conditions aren't met yet.
@export var has_quest_but_cannot_offer_state := Quest.IndicatorState.NONE
## Single player game. Check the player's journal for active/completed quests.
@export var check_single_player_journal := true

## For each [enum Quest.IndicatorState], the IDs of the quests that want it.
var states: Array[PackedStringArray] = []

var _my_id := ""
var _refresh_pending := false
var _connected_manager: QuestManager


## The ID of the entity this manager belongs to.
func get_entity_id() -> String:
	return _my_id


func _ready() -> void:
	_my_id = QuestMessages.get_id(get_parent() if get_parent() != null else self)
	if _my_id.is_empty():
		_my_id = QuestMessages.get_id(self)
	if indicator == null:
		for child in get_children():
			if child is QuestIndicator:
				indicator = child
				break
	_initialize_states()
	QuestMessages.add_listener(self, QuestMessages.SET_INDICATOR_STATE, "", _on_message)
	QuestMessages.add_listener(self, QuestMessages.REFRESH_INDICATOR, "", _on_message)
	QuestMessages.add_listener(self, QuestMessages.REFRESH_UIS, "", _on_message)
	_connected_manager = Quests.get_manager()
	if _connected_manager != null:
		_connected_manager.quest_state_changed.connect(_on_quest_changed)
		_connected_manager.quest_offerable.connect(_on_quest_changed)
	repaint()


func _exit_tree() -> void:
	QuestMessages.remove_listener(self)
	if _connected_manager != null and is_instance_valid(_connected_manager):
		_connected_manager.quest_state_changed.disconnect(_on_quest_changed)
		_connected_manager.quest_offerable.disconnect(_on_quest_changed)
	_connected_manager = null


func _on_quest_changed(_quest: Quest, _a: Variant = null, _b: Variant = null) -> void:
	repaint()


func _on_message(args: QuestMessageArgs) -> void:
	var target := args.get_target_id()
	if not (target.is_empty() or target == _my_id):
		return
	match args.message:
		QuestMessages.SET_INDICATOR_STATE:
			var first: Variant = args.first_value()
			if typeof(first) == TYPE_INT:
				set_indicator_state(args.parameter, first)
		QuestMessages.REFRESH_INDICATOR, QuestMessages.REFRESH_UIS:
			repaint()


func _initialize_states() -> void:
	states.clear()
	for i in Quest.IndicatorState.size():
		states.append(PackedStringArray())


## Sets the indicator state that a quest wants on this entity.
func set_indicator_state(quest_id: String, state: Quest.IndicatorState) -> void:
	if states.is_empty():
		_initialize_states()
	for i in states.size():
		var index := states[i].find(quest_id)
		if index >= 0:
			states[i].remove_at(index)
	states[state].append(quest_id)
	show_highest_priority_indicator()


## Refreshes from all quests at the end of the frame, once however many times it's called.
func repaint() -> void:
	if not is_inside_tree() or _refresh_pending:
		return
	_refresh_pending = true
	_refresh_next_frame()


func _refresh_next_frame() -> void:
	await get_tree().process_frame
	_refresh_pending = false
	if is_inside_tree():
		refresh_from_all_quests()


## Rebuilds the states from every quest instance and updates the indicator.
func refresh_from_all_quests() -> void:
	var player_journal: QuestJournal = Quests.get_journal() if check_single_player_journal else null
	_initialize_states()
	var all_quests := Quests.get_all_quest_instances()
	for quest_id: String in all_quests:
		for quest: Quest in all_quests[quest_id]:
			if quest == null:
				continue
			var quest_state := quest.get_state()
			if quest_state == Quest.State.ACTIVE and quest.indicator_states.has(_my_id):
				# The quest specifies an indicator for this entity.
				states[quest.indicator_states[_my_id]].append(quest.id)
			elif quest_state == Quest.State.WAITING_TO_START and quest.quest_giver_id == _my_id and quest.quester_id.is_empty():
				# Offerable by this entity, unless the single player already has it.
				if not (check_single_player_journal and _does_journal_have_quest(player_journal, quest)):
					var state := has_quest_to_offer_state if quest.is_offerable else has_quest_but_cannot_offer_state
					states[state].append(quest.id)
	show_highest_priority_indicator()


func _does_journal_have_quest(journal: QuestJournal, quest: Quest) -> bool:
	if quest == null or journal == null:
		return false
	var in_journal := journal.find_quest(quest.id)
	if in_journal == null:
		return false
	var state := in_journal.get_state()
	return state == Quest.State.ACTIVE or (state == Quest.State.SUCCESSFUL and quest.times_accepted < quest.max_times)


## The indicator state that is currently showing.
func get_highest_priority_state() -> Quest.IndicatorState:
	for i in range(states.size() - 1, 0, -1):
		if not states[i].is_empty():
			return i as Quest.IndicatorState
	return Quest.IndicatorState.NONE


## Hides all indicators and shows the one with the highest priority.
func show_highest_priority_indicator() -> void:
	if indicator == null:
		return
	indicator.hide_all_indicators()
	var state := get_highest_priority_state()
	if state != Quest.IndicatorState.NONE:
		indicator.set_indicator(state, true)


## Returns the data to save: the quest IDs for each state.
func record_data() -> Dictionary:
	var data: Array = []
	for list in states:
		data.append(Array(list))
	return {"states": data}


## Restores saved data and updates the indicator.
func apply_data(data: Dictionary) -> void:
	var saved: Array = data.get("states", [])
	if saved.is_empty():
		return
	_initialize_states()
	for i in mini(saved.size(), states.size()):
		states[i] = PackedStringArray(saved[i])
	show_highest_priority_indicator()
