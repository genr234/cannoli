class_name QuestMessages
extends RefCounted
## The message bus the quest system uses to talk to itself and to your game.
##
## Listeners register for a message name and an optional parameter. A listener
## with an empty parameter receives every parameter. Messages that quests send
## use the quest id as the parameter.
## [codeblock]
## QuestMessages.add_listener(self, QuestMessages.QUEST_STATE_CHANGED, "", _on_quest_state)
## QuestMessages.send(self, null, "Wolf Killed", "", [1])
## [/codeblock]

enum Participant { ANY, QUESTER, QUEST_GIVER, OTHER }

const QUEST_STATE_CHANGED := "Quest State Changed"
const QUEST_TRACK_TOGGLE_CHANGED := "Quest Track Toggle Changed"
const QUEST_ABANDONED := "Quest Abandoned"
const CHECK_OFFER_CONDITIONS := "Check Offer Conditions"
const QUEST_COUNTER_CHANGED := "Quest Counter Changed"
const SET_QUEST_COUNTER := "Set Quest Counter"
const INCREMENT_QUEST_COUNTER := "Increment Quest Counter"
const TIMER_TICK := "Timer Tick"
const SET_INDICATOR_STATE := "Set Indicator State"
const REFRESH_INDICATOR := "Refresh Indicator"
const REFRESH_UIS := "Refresh UIs"
const QUEST_ALERT := "Quest Alert"
const GREET := "Greet"
const GREETED := "Greeted"
const DISCUSS_QUEST := "Discuss Quest"
const DISCUSSED_QUEST := "Discussed Quest"
const START_SPAWNER := "Start Spawner"
const STOP_SPAWNER := "Stop Spawner"
const DESPAWN_SPAWNER := "Despawn Spawner"
const GROUP_BUTTON_CLICKED := "Group Button Clicked"
## A counter in DATA_SYNC mode listens for this message (parameter = counter name).
const DATA_SOURCE_VALUE_CHANGED := "Data Source Value Changed"
## Sent when a DATA_SYNC counter changes, so the data source can follow.
const REQUEST_DATA_SOURCE_CHANGE_VALUE := "Request Data Source Change Value"

## If false, listeners added during the current frame don't receive messages
## until the next frame. Used while loading a game.
static var allow_receive_same_frame_added := true


class _Listener:
	var id := 0
	var message := ""
	var parameter := ""
	var callback := Callable()
	var frame_added := 0
	var removed := false


static var _listeners: Array[_Listener] = []
static var _send_depth := 0


#region Listeners

## Registers [param callback] to be called with a [QuestMessageArgs] when
## [param message] is sent with [param parameter]. An empty parameter accepts any.
## [param listener] identifies the registration for [method remove_listener].
static func add_listener(listener: Object, message: String, parameter: String, callback: Callable) -> void:
	if listener == null:
		return
	var listener_id := listener.get_instance_id()
	for x in _listeners:
		if x.id == listener_id and x.message == message and (x.parameter == parameter or x.parameter.is_empty()) \
				and x.callback == callback:
			x.removed = false
			return
	var info := _Listener.new()
	info.id = listener_id
	info.message = message
	info.parameter = parameter
	info.callback = callback
	info.frame_added = Engine.get_process_frames()
	_listeners.append(info)


## Removes [param listener]'s registrations. An empty [param message] or
## [param parameter] matches any.
static func remove_listener(listener: Object, message := "", parameter := "") -> void:
	if listener == null or _listeners.is_empty():
		return
	var listener_id := listener.get_instance_id()
	for i in range(_listeners.size() - 1, -1, -1):
		var x := _listeners[i]
		if x.id == listener_id and (message.is_empty() or x.message == message) \
				and (parameter.is_empty() or x.parameter == parameter):
			x.removed = true
			if _send_depth == 0:
				_listeners.remove_at(i)


static func is_listener_registered(listener: Object, message: String, parameter := "") -> bool:
	if listener == null:
		return false
	var listener_id := listener.get_instance_id()
	for x in _listeners:
		if not x.removed and x.id == listener_id and x.message == message \
				and (x.parameter == parameter or x.parameter.is_empty()):
			return true
	return false


## Removes every listener, such as when changing scenes.
static func clear_listeners() -> void:
	_listeners.clear()
	_send_depth = 0
	allow_receive_same_frame_added = true


static func get_listener_count() -> int:
	var count := 0
	for x in _listeners:
		if not x.removed:
			count += 1
	return count

#endregion

#region Sending

## Sends [param message] to every matching listener. [param sender] and
## [param target] may be ids (Strings), nodes, quests or null.
static func send(sender: Variant, target: Variant, message: String, parameter := "", values: Array = []) -> void:
	var args := QuestMessageArgs.new(sender, target, message, parameter, values)
	if Quests.debug:
		print("Quests: send(sender=%s target=%s: %s, %s)" % [sender, target, message, parameter])
	_send_depth += 1
	var i := 0
	while i < _listeners.size():
		var x := _listeners[i]
		i += 1
		if x.removed:
			continue
		if not is_instance_valid(instance_from_id(x.id)):
			x.removed = true
			continue
		if not allow_receive_same_frame_added and x.frame_added == Engine.get_process_frames():
			continue
		if x.message == message and (x.parameter == parameter or x.parameter.is_empty()):
			if x.callback.is_valid():
				x.callback.call(args)
	_send_depth -= 1
	if _send_depth == 0:
		_remove_marked_listeners()
	var manager := Quests.get_manager()
	if manager != null:
		manager.message_sent.emit(args)
		if message == QUEST_ALERT:
			var contents: Array[QuestContent] = []
			if not values.is_empty() and values[0] is Array:
				contents.assign(values[0])
			manager.quest_alert.emit(parameter, contents)


static func _remove_marked_listeners() -> void:
	for i in range(_listeners.size() - 1, -1, -1):
		if _listeners[i].removed:
			_listeners.remove_at(i)


## Sends a message written as "Message", "Message:parameter" or
## "Message:parameter:value". A numeric value is sent as an int.
static func send_composite(sender: Variant, message: String) -> void:
	if message.is_empty():
		return
	if Quests.debug:
		print("Quests: Sending composite message '%s'" % message)
	var parameter := ""
	var value: Variant = null
	if message.contains(":"):
		var colon := message.find(":")
		parameter = message.substr(colon + 1)
		message = message.substr(0, colon)
		if parameter.contains(":"):
			colon = parameter.find(":")
			var value_string := parameter.substr(colon + 1)
			parameter = parameter.substr(0, colon)
			value = value_string.to_int() if value_string.is_valid_int() else value_string
	if value == null:
		send(sender, null, message, parameter)
	else:
		send(sender, null, message, parameter, [value])

#endregion

#region Participants

## The id of a message participant: a String is its own id; a [QuestList],
## [QuestIdentity] or [Quest] has an id; for any other node, the id of the
## [QuestList] or [QuestIdentity] found on the node, its children, its
## ancestors or their children, else the node's name. Null has no id.
static func get_id(participant: Variant) -> String:
	if participant == null:
		return ""
	if typeof(participant) == TYPE_STRING or typeof(participant) == TYPE_STRING_NAME:
		return String(participant)
	if participant is Quest:
		return participant.id
	if participant is QuestList or participant is QuestIdentity:
		return participant.id
	if participant is Node:
		var found := find_identifiable(participant)
		if found != null:
			return _identifiable_id(found)
		return String(participant.name)
	return ""


static func get_display_name(participant: Variant, default := "") -> String:
	if participant == null:
		return default
	if typeof(participant) == TYPE_STRING or typeof(participant) == TYPE_STRING_NAME:
		return String(participant)
	if participant is QuestList or participant is QuestIdentity:
		return participant.get_display_name()
	if participant is Node:
		var found := find_identifiable(participant)
		if found != null:
			return found.get_display_name() if found.has_method("get_display_name") else _identifiable_id(found)
		return String(participant.name)
	return default


## Finds the node that identifies [param node]: the node itself, then its
## descendants, then its ancestors and their children, looking for a [QuestList], a
## [QuestIdentity], or a node with a get_quest_id() method. The ancestor search
## stops at [member Node.owner], the root of the scene [param node] was instanced
## in, so it can't pick up another character's identity. Without an owner it
## climbs to the root.
static func find_identifiable(node: Node) -> Node:
	if node == null:
		return null
	if _is_identifiable(node):
		return node
	var found := _find_identifiable_in_children(node)
	if found != null:
		return found
	var ancestor := node.get_parent()
	while ancestor != null:
		if _is_identifiable(ancestor):
			return ancestor
		# The identity of a character is usually a child of the character.
		for sibling in ancestor.get_children():
			if sibling is QuestList:
				return sibling
		for sibling in ancestor.get_children():
			if _is_identifiable(sibling):
				return sibling
		if ancestor == node.owner:
			break
		ancestor = ancestor.get_parent()
	return null


static func _is_identifiable(node: Node) -> bool:
	return node is QuestList or node is QuestIdentity or node.has_method(&"get_quest_id")


static func _find_identifiable_in_children(node: Node) -> Node:
	# Quest lists first, then identities, like the order of precedence in a character.
	for child in node.get_children():
		if child is QuestList:
			return child
	for child in node.get_children():
		if _is_identifiable(child):
			return child
	for child in node.get_children():
		var found := _find_identifiable_in_children(child)
		if found != null:
			return found
	return null


static func _identifiable_id(node: Node) -> String:
	if node is QuestList or node is QuestIdentity:
		return (node as Variant).id
	return str(node.call(&"get_quest_id"))


## True if [param id] is empty or is the id of [param participant].
static func is_required_id(participant: Variant, id: String) -> bool:
	return id.is_empty() or get_id(participant) == id


## Converts a message value to a String.
static func arg_to_string(arg: Variant) -> String:
	return "" if arg == null else str(arg)


## Converts a message value to an int, or -1 if it isn't an int.
static func arg_to_int(arg: Variant) -> int:
	return arg if typeof(arg) == TYPE_INT else -1


## Finds the node with the given id: a registered quest list, an identity,
## or a node with that name.
static func find_node_with_id(id: String, from: Node = null) -> Node:
	if id.is_empty():
		return null
	var list := Quests.get_quest_list(id)
	if list != null:
		return list
	var identity := QuestIdentity.find_by_id(id)
	if identity != null:
		return identity.get_parent() if identity.get_parent() != null else identity
	var tree := from.get_tree() if from != null and from.is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree == null or tree.root == null:
		return null
	return tree.root.find_child(id, true, false)

#endregion

#region Senders for the messages the quest system uses

## Parameter is the quest id; values are ["", state].
static func quest_state_changed(sender: Variant, quest_id: String, state: Quest.State) -> void:
	send(sender, null, QUEST_STATE_CHANGED, quest_id, ["", state])


## Parameter is the quest id; values are [node_id, state].
static func quest_node_state_changed(sender: Variant, quest_id: String, node_id: String, state: QuestNode.State) -> void:
	send(sender, null, QUEST_STATE_CHANGED, quest_id, [node_id, state])


static func quest_track_toggle_changed(sender: Variant, quest_id: String, tracked: bool) -> void:
	send(sender, null, QUEST_TRACK_TOGGLE_CHANGED, quest_id, [tracked])


static func quest_abandoned(sender: Variant, quest_id: String) -> void:
	send(sender, null, QUEST_ABANDONED, quest_id)


static func quest_counter_changed(sender: Variant, quest_id: String, counter_name: String, value: int) -> void:
	send(sender, null, QUEST_COUNTER_CHANGED, quest_id, [counter_name, value])


## Sets a counter. Parameter is the quest id; values are [counter_name, value].
static func set_quest_counter(sender: Variant, quest_id: String, counter_name: String, value: int) -> void:
	send(sender, null, SET_QUEST_COUNTER, quest_id, [counter_name, value])


## Increments a counter. Parameter is the quest id; values are [counter_name, amount].
static func increment_quest_counter(sender: Variant, quest_id: String, counter_name: String, amount: int) -> void:
	send(sender, null, INCREMENT_QUEST_COUNTER, quest_id, [counter_name, amount])


## Tells the entity with [param entity_id] to show an indicator for a quest.
static func set_indicator_state(sender: Variant, entity_id: String, quest_id: String, state: Quest.IndicatorState) -> void:
	send(sender, entity_id, SET_INDICATOR_STATE, quest_id, [state])


static func refresh_indicator(sender: Variant, entity_id: String) -> void:
	send(sender, entity_id, REFRESH_INDICATOR, entity_id)


## Asks every indicator to refresh.
static func refresh_indicators(sender: Variant) -> void:
	refresh_indicator(sender, "")


static func refresh_uis(sender: Variant) -> void:
	send(sender, null, REFRESH_UIS, "")


static func quest_alert(sender: Variant, quest_id: String, contents: Array[QuestContent]) -> void:
	send(sender, null, QUEST_ALERT, quest_id, [contents])


static func greet(sender: Variant, target: Variant, target_id: String) -> void:
	send(sender, target, GREET, target_id)


static func greeted(sender: Variant, target: Variant, target_id: String) -> void:
	send(sender, target, GREETED, target_id)


static func discuss_quest(sender: Variant, target: Variant, target_id: String, quest_id: String) -> void:
	send(sender, target, DISCUSS_QUEST, quest_id, [target_id])


static func discussed_quest(sender: Variant, target: Variant, target_id: String, quest_id: String) -> void:
	send(sender, target, DISCUSSED_QUEST, quest_id, [target_id])


static func start_spawner(spawner_name: String) -> void:
	send(Quests.get_manager(), null, START_SPAWNER, spawner_name)


static func stop_spawner(spawner_name: String) -> void:
	send(Quests.get_manager(), null, STOP_SPAWNER, spawner_name)


static func despawn_spawner(spawner_name: String) -> void:
	send(Quests.get_manager(), null, DESPAWN_SPAWNER, spawner_name)

#endregion
