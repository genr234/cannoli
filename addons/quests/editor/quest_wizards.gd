class_name QuestWizards
extends RefCounted
## Wizards that add ready-made nodes to a quest, and whole-quest templates.
## Both are described by field lists so the editor can build a form for each:
## a field is {key, label, type ("string", "text", "int", "bool"), default, tooltip}.

const MESSAGE := "message"
const COUNTER := "counter"
const RETURN := "return"

const TEMPLATE_TALK := "talk_to_npc"
const TEMPLATE_COLLECT := "collect"
const TEMPLATE_KILL := "kill"
const TEMPLATE_TIMED_DELIVERY := "timed_delivery"
const TEMPLATE_CHAIN := "chain"


## Node wizards: id -> {title, help, fields}.
static func get_wizards() -> Dictionary:
	return {
		MESSAGE: {
			"title": "Message Requirement",
			"help": "Adds a condition node that listens for a message. The fields are set to example values. Change them and click Add.",
			"fields": [
				_field("message", "Message", "string", "Explored", "Message this node listens for. Send it with Quests.send_message()."),
				_field("parameter", "Parameter", "string", "Cave", "If set, require this parameter with the message. If blank, accept any parameter."),
				_field("hud_text", "HUD Text", "string", "Explore Cave", "Shown in the HUD while this node is active."),
				_field("journal_text", "Journal Text", "string", "{QUESTGIVER} has asked you to explore the Cave.", "Shown in the journal while this node is active."),
				_field("dialogue_text", "Dialogue Text", "string", "I want you to explore the Cave.", "Shown in dialogue while this node is active."),
				_field("leads_to_success", "Leads to Success", "bool", false, "Add a success node right after this node."),
			],
		},
		COUNTER: {
			"title": "Counter Requirement",
			"help": "Adds a counter and a condition node that requires the counter to reach a value. {0} is replaced by the current value and {1} by the goal.",
			"fields": [
				_field("counter_name", "Counter Name", "string", "orcsKilled", ""),
				_field("min", "Min", "int", 0, ""),
				_field("max", "Max (Goal)", "int", 99, ""),
				_field("increment_message", "Message", "string", "Killed:Orc", "Increment when this message arrives. The parameter follows a colon."),
				_field("hud_instructions", "HUD Text", "string", "Kill {1} Orcs", "Alert and HUD instructions. Leave blank to skip."),
				_field("hud_count", "HUD Count", "string", "{0}/{1} Killed", ""),
				_field("journal_text", "Journal Text", "string", "{QUESTGIVER} has asked you to kill {1} Orcs.", ""),
				_field("dialogue_text", "Dialogue Text", "string", "I want you to kill {1} Orcs.", ""),
				_field("leads_to_success", "Leads to Success", "bool", false, "Add a success node right after this node."),
			],
		},
		RETURN: {
			"title": "Return to Quest Giver",
			"help": "Adds a condition node that waits until the player returns to speak with the quest giver.",
			"fields": [
				_field("hud_text", "HUD Text", "string", "Return to {QUESTGIVER}", ""),
				_field("journal_text", "Journal Text", "string", "Return to {QUESTGIVER}.", ""),
				_field("dialogue_text", "Dialogue Text", "string", "Thanks for completing the quest.", "Shown when the player returns."),
				_field("leads_to_success", "Leads to Success", "bool", true, "Add a success node right after this node."),
			],
		},
	}


## Quest templates: id -> {title, help, fields}.
static func get_templates() -> Dictionary:
	var common := [
		_field("id", "Quest ID", "string", "", "Unique id. Leave blank to derive it from the title."),
		_field("title", "Title", "string", "", ""),
		_field("offer_text", "Offer Text", "string", "I have a task for you.", "What the giver says when offering the quest."),
	]
	return {
		TEMPLATE_TALK: {
			"title": "Talk to NPC",
			"help": "The player must greet a specific character.",
			"fields": common + [
				_field("npc_id", "NPC ID", "string", "Villager", "Quest identity id of the character."),
				_field("npc_name", "NPC Name", "string", "the villager", "Used in the objective text."),
			],
		},
		TEMPLATE_COLLECT: {
			"title": "Collect N",
			"help": "Collect a number of items, then return to the quest giver. Counts the message 'Collected' with the item as parameter.",
			"fields": common + [
				_field("item", "Item", "string", "Herb", "Parameter of the 'Collected' message."),
				_field("count", "Count", "int", 5, ""),
				_field("return_to_giver", "Return to Giver", "bool", true, ""),
			],
		},
		TEMPLATE_KILL: {
			"title": "Kill N",
			"help": "Defeat a number of enemies, then return to the quest giver. Counts the message 'Killed' with the enemy as parameter.",
			"fields": common + [
				_field("enemy", "Enemy", "string", "Orc", "Parameter of the 'Killed' message."),
				_field("count", "Count", "int", 5, ""),
				_field("return_to_giver", "Return to Giver", "bool", true, ""),
			],
		},
		TEMPLATE_TIMED_DELIVERY: {
			"title": "Timed delivery",
			"help": "Deliver an item before time runs out. The quest fails when its time limit expires.",
			"fields": common + [
				_field("item", "Item", "string", "Package", ""),
				_field("destination_id", "Destination ID", "string", "Harbor", "Parameter of the 'Delivered' message."),
				_field("seconds", "Time Limit (seconds)", "int", 120, ""),
			],
		},
		TEMPLATE_CHAIN: {
			"title": "Chain (requires previous quest)",
			"help": "A follow-up quest that is only offered after another quest is successful.",
			"fields": common + [
				_field("previous_id", "Previous Quest ID", "string", "", "Must be successful before this quest is offered."),
				_field("npc_id", "NPC ID", "string", "Villager", "The character the player must greet."),
				_field("npc_name", "NPC Name", "string", "the villager", ""),
			],
		},
	}


## Default values of a field list as a dictionary.
static func defaults(fields: Array) -> Dictionary:
	var values := {}
	for field: Dictionary in fields:
		values[field.key] = field.default
	return values


## Runs a node wizard. `clicked_id` is the node to link from; when empty, the
## node before the success node is used. Returns the new condition node.
static func apply_wizard(wizard_id: String, quest: Quest, clicked_id: String, params: Dictionary) -> QuestNode:
	match wizard_id:
		MESSAGE:
			return add_message_node(quest, clicked_id, params)
		COUNTER:
			return add_counter_node(quest, clicked_id, params)
		RETURN:
			return add_return_node(quest, clicked_id, params)
	push_warning("Quests: Unknown wizard '%s'." % wizard_id)
	return null


static func add_message_node(quest: Quest, clicked_id: String, params: Dictionary) -> QuestNode:
	var parent := _get_parent_node(quest, clicked_id)
	if parent == null:
		return null
	var hud_text: String = params.get("hud_text", "")
	var node := _insert_condition_node(quest, parent, hud_text)
	if params.get("leads_to_success", false):
		_add_success_node(quest, node)
	var condition := QuestMessageCondition.new()
	condition.message = params.get("message", "")
	condition.parameter = params.get("parameter", "")
	condition.value = QuestMessageValue.new()
	node.condition_set.condition_list.append(condition)
	var active := node.state_info_list[QuestNode.State.ACTIVE]
	active.hud_content.append(_body(hud_text))
	active.journal_content.append(_body(params.get("journal_text", "")))
	active.dialogue_content.append(_body(params.get("dialogue_text", "")))
	active.action_list.append(_alert(hud_text))
	return node


static func add_counter_node(quest: Quest, clicked_id: String, params: Dictionary) -> QuestNode:
	var counter_name: String = params.get("counter_name", "")
	var min_value: int = params.get("min", 0)
	var max_value: int = params.get("max", 1)
	if counter_name.is_empty() or max_value < min_value:
		return null
	var parent := _get_parent_node(quest, clicked_id)
	if parent == null:
		return null
	QuestGraphOps.remove_counter(quest, counter_name)
	var counter := QuestGraphOps.add_counter(quest, counter_name, min_value, max_value)
	counter.update_mode = QuestCounter.UpdateMode.MESSAGES
	var message_and_parameter := String(params.get("increment_message", "")).split(":")
	var event := QuestCounterMessageEvent.new()
	event.message = message_and_parameter[0]
	event.parameter = message_and_parameter[1] if message_and_parameter.size() > 1 else ""
	event.operation = QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE
	event.literal_value = 1
	counter.message_event_list.append(event)
	var hud_instructions: String = params.get("hud_instructions", "")
	var node := _insert_condition_node(quest, parent, hud_instructions.format([min_value, max_value]))
	if params.get("leads_to_success", false):
		_add_success_node(quest, node)
	var condition := QuestCounterCondition.new()
	condition.counter_name = counter_name
	condition.counter_value_mode = QuestCounterCondition.CounterValueMode.AT_LEAST
	condition.required_counter_value = QuestNumber.literal(max_value)
	node.condition_set.condition_list.append(condition)
	var active := node.state_info_list[QuestNode.State.ACTIVE]
	_append_body(active.hud_content, _counter_tags(hud_instructions, counter_name))
	_append_body(active.hud_content, _counter_tags(params.get("hud_count", ""), counter_name))
	_append_body(active.journal_content, _counter_tags(params.get("journal_text", ""), counter_name))
	_append_body(active.dialogue_content, _counter_tags(params.get("dialogue_text", ""), counter_name))
	if not hud_instructions.is_empty():
		active.action_list.append(_alert(_counter_tags(hud_instructions, counter_name)))
	return node


static func add_return_node(quest: Quest, clicked_id: String, params: Dictionary) -> QuestNode:
	var parent := _get_parent_node(quest, clicked_id)
	if parent == null:
		return null
	var journal_text: String = params.get("journal_text", "")
	var node := _insert_condition_node(quest, parent, journal_text)
	if params.get("leads_to_success", true):
		_add_success_node(quest, node)
	var condition := QuestMessageCondition.new()
	condition.message = QuestMessages.DISCUSS_QUEST
	condition.parameter = quest.id
	condition.value = QuestMessageValue.new()
	condition.target_specifier = QuestMessages.Participant.QUEST_GIVER
	node.condition_set.condition_list.append(condition)
	var active := node.state_info_list[QuestNode.State.ACTIVE]
	var hud_text: String = params.get("hud_text", "")
	active.hud_content.append(_body(hud_text))
	active.journal_content.append(_body(journal_text))
	active.action_list.append(_alert(hud_text))
	node.state_info_list[QuestNode.State.TRUE].dialogue_content.append(_body(params.get("dialogue_text", "")))
	return node


## Builds a complete quest from a template. Returns null for an unknown template.
static func create_from_template(template_id: String, params: Dictionary) -> Quest:
	var title: String = params.get("title", "")
	if title.is_empty():
		title = String(get_templates().get(template_id, {}).get("title", "New Quest"))
	var id: String = params.get("id", "")
	if id.is_empty():
		id = title.to_snake_case().replace(" ", "_")
	var quest := QuestGraphOps.new_quest(id, title)
	var offer_text: String = params.get("offer_text", "")
	if not offer_text.is_empty():
		quest.offer_content_list.append(_body(offer_text))
	match template_id:
		TEMPLATE_TALK:
			_talk(quest, params)
		TEMPLATE_COLLECT:
			_count(quest, params, String(params.get("item", "Item")), "Collected", "Collect {1} %s", "{0}/{1} collected")
		TEMPLATE_KILL:
			_count(quest, params, String(params.get("enemy", "Enemy")), "Killed", "Kill {1} %s", "{0}/{1} killed")
		TEMPLATE_TIMED_DELIVERY:
			_timed_delivery(quest, params)
		TEMPLATE_CHAIN:
			var previous: String = params.get("previous_id", "")
			if not previous.is_empty():
				quest.requires_quests = PackedStringArray([previous])
			_talk(quest, params)
		_:
			push_warning("Quests: Unknown quest template '%s'." % template_id)
			return null
	return quest


static func _talk(quest: Quest, params: Dictionary) -> void:
	var npc_name: String = params.get("npc_name", "")
	add_message_node(quest, "", {
		"message": QuestMessages.GREETED,
		"parameter": params.get("npc_id", ""),
		"hud_text": "Talk to %s" % npc_name,
		"journal_text": "{QUESTGIVER} has asked you to talk to %s." % npc_name,
		"dialogue_text": "Go and talk to %s." % npc_name,
		"leads_to_success": true,
	})


static func _count(quest: Quest, params: Dictionary, target: String, message: String, instructions: String, count_text: String) -> void:
	var count: int = params.get("count", 1)
	var counter_name := target.to_camel_case() + "Count"
	add_counter_node(quest, "", {
		"counter_name": counter_name,
		"min": 0,
		"max": count,
		"increment_message": "%s:%s" % [message, target],
		"hud_instructions": instructions % target,
		"hud_count": count_text,
		"journal_text": "{QUESTGIVER} needs you: " + (instructions % target) + ".",
		"dialogue_text": (instructions % target) + ", please.",
		"leads_to_success": not params.get("return_to_giver", true),
	})
	if params.get("return_to_giver", true):
		add_return_node(quest, "", {
			"hud_text": "Return to {QUESTGIVER}",
			"journal_text": "Return to {QUESTGIVER}.",
			"dialogue_text": "Thank you!",
			"leads_to_success": true,
		})
	var counter := quest.counter_list[0]
	counter.display_name = target


static func _timed_delivery(quest: Quest, params: Dictionary) -> void:
	var item: String = params.get("item", "")
	var destination: String = params.get("destination_id", "")
	quest.time_limit = float(params.get("seconds", 0))
	add_message_node(quest, "", {
		"message": "Delivered",
		"parameter": destination,
		"hud_text": "Deliver the %s to %s in time" % [item, destination],
		"journal_text": "{QUESTGIVER} needs the %s delivered to %s before time runs out." % [item, destination],
		"dialogue_text": "Hurry, there is not much time!",
		"leads_to_success": true,
	})
	var failed := quest.state_info_list[Quest.State.FAILED]
	failed.journal_content.append(_body("You ran out of time."))


static func _get_parent_node(quest: Quest, clicked_id: String) -> QuestNode:
	var clicked := QuestGraphOps.find_node(quest, clicked_id)
	if clicked != null:
		return clicked
	return _get_last_node_before_success(quest)


static func _get_last_node_before_success(quest: Quest) -> QuestNode:
	if quest.node_list.is_empty():
		push_error("Quests: Quest must have a Start node.")
		return null
	var node := quest.node_list[0]
	var visited := {}
	while true:
		visited[node] = true
		var next: QuestNode = null
		for child_id in node.children:
			var child := QuestGraphOps.find_node(quest, child_id)
			if child != null and child.node_type == QuestNode.Type.SUCCESS:
				return node
			if next == null and child != null and not visited.has(child):
				next = child
		if next == null:
			return node
		node = next
	return node


static func _insert_condition_node(quest: Quest, parent: QuestNode, title: String) -> QuestNode:
	var node := QuestGraphOps.create_node(quest, QuestNode.Type.CONDITION, parent.editor_position + Vector2(QuestGraphOps.NODE_SIZE.x + 20.0, 0.0))
	node.internal_name = title
	node.children = parent.children.duplicate()
	parent.children = PackedStringArray([node.id])
	return node


static func _add_success_node(quest: Quest, node: QuestNode) -> void:
	for child_id in node.children:
		var existing := QuestGraphOps.find_node(quest, child_id)
		if existing != null and existing.node_type == QuestNode.Type.SUCCESS:
			return
	for existing in quest.node_list:
		if existing != null and existing.node_type == QuestNode.Type.SUCCESS:
			node.children.append(existing.id)
			return
	var success := QuestGraphOps.create_node(quest, QuestNode.Type.SUCCESS, node.editor_position + Vector2(0.0, QuestGraphOps.NODE_SIZE.y + 10.0))
	success.internal_name = "Success"
	node.children.append(success.id)


static func _body(text: String) -> QuestBodyContent:
	var content := QuestBodyContent.new()
	content.text = text
	return content


static func _append_body(list: Array, text: String) -> void:
	if not text.is_empty():
		list.append(_body(text))


static func _alert(text: String) -> QuestAlertAction:
	var action := QuestAlertAction.new()
	action.content_list.append(_body(text))
	return action


static func _counter_tags(text: String, counter_name: String) -> String:
	return text.replace("{0}", "{#%s}" % counter_name).replace("{1}", "{>#%s}" % counter_name).replace("\\n", "\n")


static func _field(key: String, label: String, type: String, default: Variant, tooltip: String) -> Dictionary:
	return {"key": key, "label": label, "type": type, "default": default, "tooltip": tooltip}
