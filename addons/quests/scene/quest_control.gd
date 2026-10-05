class_name QuestControl
extends Node
## Methods that you can connect to signals, such as a button's pressed signal
## or an area's body_entered signal, to control quests without code.
##
## Some methods use the ids set in the exported fields; the others take their
## ids as arguments.

## Emitted by [method try_conditional_event] when the condition is met.
signal condition_met()

@export_group("Quest")
@export var quest_id := ""
@export var quest_node_id := ""
@export_group("Quest Counter")
@export var counter_name := ""
@export_group("Conditional Event")
## [method try_conditional_event] checks this quest and required state. If the
## node id isn't blank, it also checks the node and its state.
@export var conditional_quest_id := ""
@export var required_quest_state := Quest.State.ACTIVE
@export var conditional_node_id := ""
@export var required_node_state := QuestNode.State.TRUE


#region Messages

## Sends a message written as "Message", "Message:parameter" or "Message:parameter:value".
func send_to_message_system(message: String) -> void:
	QuestMessages.send_composite(self, message)


func send_message(message: String) -> void:
	QuestMessages.send(self, null, message)


func send_message_with_parameter(message: String, parameter: String) -> void:
	QuestMessages.send(self, null, message, parameter)


func send_message_with_value(message: String, parameter: String, value: Variant) -> void:
	QuestMessages.send(self, null, message, parameter, [value])

#endregion

#region Using the exported ids

## Sets the state of [member quest_id]. [param state_name] is a name such as "active".
func set_configured_quest_state(state_name: String) -> void:
	set_quest_state(quest_id, state_name)


## Sets the state of node [member quest_node_id] of [member quest_id].
func set_configured_quest_node_state(state_name: String) -> void:
	set_quest_node_state(quest_id, quest_node_id, state_name)


func set_configured_counter(value: int) -> void:
	set_counter(quest_id, counter_name, value)


func increment_configured_counter(amount: int) -> void:
	increment_counter(quest_id, counter_name, amount)

#endregion

#region Using ids as arguments

## Sets a quest's state. [param state_name] is a name such as "active",
## "successful" or "waiting to start".
func set_quest_state(p_quest_id: String, state_name: Variant) -> void:
	var quest := Quests.get_quest_instance(p_quest_id)
	if quest == null:
		if Quests.debug:
			push_warning("Quests: Can't find quest '%s' to set its state." % p_quest_id)
		return
	var state := Quests.state_from_name(state_name)
	if state == -1:
		push_warning("Quests: '%s' isn't a quest state." % str(state_name))
		return
	quest.set_state(state as Quest.State)


func set_quest_node_state(p_quest_id: String, node_id: String, state_name: Variant) -> void:
	var quest := Quests.get_quest_instance(p_quest_id)
	if quest == null:
		if Quests.debug:
			push_warning("Quests: Can't find quest '%s' to set the state of node '%s'." % [p_quest_id, node_id])
		return
	var node := quest.get_node(node_id)
	if node == null:
		if Quests.debug:
			push_warning("Quests: Can't find node '%s' in quest '%s'." % [node_id, p_quest_id])
		return
	var state := Quests.node_state_from_name(state_name)
	if state == -1:
		push_warning("Quests: '%s' isn't a quest node state." % str(state_name))
		return
	node.set_state(state as QuestNode.State)


func set_counter(p_quest_id: String, p_counter_name: String, value: int) -> void:
	var counter := _find_counter(p_quest_id, p_counter_name)
	if counter != null:
		counter.current_value = value


func increment_counter(p_quest_id: String, p_counter_name: String, amount: int) -> void:
	var counter := _find_counter(p_quest_id, p_counter_name)
	if counter != null:
		counter.current_value += amount


func _find_counter(p_quest_id: String, p_counter_name: String) -> QuestCounter:
	var quest := Quests.get_quest_instance(p_quest_id)
	if quest == null:
		if Quests.debug:
			push_warning("Quests: Can't find quest '%s' to adjust counter '%s'." % [p_quest_id, p_counter_name])
		return null
	var counter := quest.get_counter(p_counter_name)
	if counter == null and Quests.debug:
		push_warning("Quests: Can't find counter '%s' in quest '%s'." % [p_counter_name, p_quest_id])
	return counter

#endregion

#region Misc

## Gives a quest to the player's journal.
func give_quest(p_quest_id: String) -> void:
	Quests.give_quest(p_quest_id)


## Shows text using the alert UI.
func show_alert(text: String) -> void:
	var manager := Quests.get_manager()
	if manager == null or manager.alert_ui == null or text.is_empty():
		return
	manager.alert_ui.show_alert(text)


func show_journal_ui() -> void:
	Quests.show_journal_ui()


func hide_journal_ui() -> void:
	Quests.hide_journal_ui()


func toggle_journal_ui() -> void:
	Quests.toggle_journal_ui()


func start_spawner(spawner_name: String) -> void:
	QuestMessages.start_spawner(spawner_name)


func stop_spawner(spawner_name: String) -> void:
	QuestMessages.stop_spawner(spawner_name)


func despawn_spawner(spawner_name: String) -> void:
	QuestMessages.despawn_spawner(spawner_name)


## Emits [signal condition_met] if the configured condition is met.
func try_conditional_event() -> void:
	if is_condition_met():
		condition_met.emit()


func is_condition_met() -> bool:
	if conditional_quest_id.is_empty():
		return true
	if Quests.get_quest_state(conditional_quest_id) != required_quest_state:
		return false
	if conditional_node_id.is_empty():
		return true
	return Quests.get_quest_node_state(conditional_quest_id, conditional_node_id) == required_node_state

#endregion
