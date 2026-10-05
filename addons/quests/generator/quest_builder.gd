class_name QuestBuilder
extends RefCounted
## Builds [Quest]s in code. Used by the quest generator, and available for
## creating your own quests at runtime.
##
## [codeblock]
## var builder := QuestBuilder.new("Wolves", "wolves_quest", "Wolf Hunt")
## builder.add_counter("wolves", 0, 0, 5, false, QuestCounter.UpdateMode.MESSAGES)
## builder.add_counter_message_event("wolves", "", "Killed", "Wolf", QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE, 1)
## var node := builder.add_condition_node(builder.get_start_node(), "kill", "Kill wolves")
## builder.add_counter_condition(node, "wolves", QuestCounterCondition.CounterValueMode.AT_LEAST, 5)
## builder.add_success_node(node)
## var quest := builder.to_quest()
## [/codeblock]
##
## Most methods return the thing they created, as the original does. The ones
## that only configure the quest return the builder so calls can be chained.

## The quest being built.
var quest: Quest


## Creates a builder with a new quest. [param id] and [param title] default to [param name].
func _init(name_or_quest: Variant = "", id := "", title := "") -> void:
	if name_or_quest is Quest:
		quest = name_or_quest
		return
	var quest_name := str(name_or_quest)
	_create_quest(quest_name, quest_name if id.is_empty() else id, quest_name if title.is_empty() else title)


func _create_quest(quest_name: String, id: String, title: String) -> void:
	quest = Quest.create(id, title)
	quest.resource_name = quest_name
	quest.is_instance = true
	quest.is_procedurally_generated = true
	_validate_node(quest.node_list[0])


## Finishes the quest: makes sure the lists have the right sizes, wires runtime
## references, and returns it.
func to_quest() -> Quest:
	if quest == null:
		return null
	_validate_list_sizes()
	quest.initialize()
	return quest


func _validate_list_sizes() -> void:
	QuestStateInfo.validate_list(quest.state_info_list, Quest.State.size())
	for node in quest.node_list:
		_validate_node(node)


func _validate_node(node: QuestNode) -> void:
	QuestStateInfo.validate_list(node.state_info_list, QuestNode.State.size())
	if node.condition_set == null:
		node.condition_set = QuestConditionSet.new()


## Disposes of the quest being built and forgets it. Call this on a builder
## whose quest is discarded; a built quest is a runtime instance whose nodes and
## subassets refer to each other and would otherwise never be freed.
func dispose() -> void:
	if quest != null:
		quest.dispose(true)
		quest = null


## A random identifier suitable for a quest id.
static func generate_guid() -> String:
	var parts := PackedStringArray()
	for i in 4:
		parts.append("%08x" % randi())
	return "-".join(parts)


#region Quest info

func with_group(group: String) -> QuestBuilder:
	quest.group = group
	return self


func with_icon(icon: Texture2D) -> QuestBuilder:
	quest.icon = icon
	return self


func with_abandonable(abandonable := true) -> QuestBuilder:
	quest.is_abandonable = abandonable
	return self


func with_tag(tag: String, text: String) -> QuestBuilder:
	quest.tag_dictionary[tag] = text
	return self

#endregion
#region Counters

## Adds a counter. Returns it, or null if one with the same name exists.
func add_counter(counter_name: String, initial_value: int, min_value: int, max_value: int, randomize_initial_value: bool,
		update_mode: QuestCounter.UpdateMode) -> QuestCounter:
	if get_counter(counter_name) != null:
		push_warning("Quests: Counter '%s' already exists in QuestBuilder." % counter_name)
		return null
	var counter := QuestCounter.create(counter_name, initial_value, min_value, max_value, update_mode)
	counter.randomize_initial_value = randomize_initial_value
	quest.counter_list.append(counter)
	return counter


func get_counter(counter_name: String) -> QuestCounter:
	for counter in quest.counter_list:
		if counter != null and counter.name == counter_name:
			return counter
	return null


## Adds a message that changes a counter, and sets the counter to update by messages.
func add_counter_message_event(counter_name: String, target_id: String, message: String, parameter: String,
		operation: QuestCounterMessageEvent.Operation, literal_value := 0) -> QuestBuilder:
	var counter := get_counter(counter_name)
	if counter == null:
		push_warning("Quests: Counter '%s' isn't present in QuestBuilder." % counter_name)
		return self
	counter.update_mode = QuestCounter.UpdateMode.MESSAGES
	counter.message_event_list.append(QuestCounterMessageEvent.create(message, parameter, operation, literal_value, target_id))
	return self

#endregion
#region Rewards

## Asks each reward system, in order, to use up [param points] until none are left.
func assign_rewards(reward_systems: Array, points: int) -> QuestBuilder:
	var points_remaining := points
	for reward_system in reward_systems:
		if reward_system == null:
			continue
		points_remaining = (reward_system as QuestRewardSystem).determine_reward(points_remaining, quest)
		if points_remaining <= 0:
			break
	return self

#endregion
#region Offer content

func add_offer_contents(contents: Array) -> QuestBuilder:
	add_contents(quest.offer_content_list, contents)
	return self


func add_offer_unmet_contents(contents: Array) -> QuestBuilder:
	add_contents(quest.offer_conditions_unmet_content_list, contents)
	return self

#endregion
#region Create content

## Appends [param contents] to [param content_list].
func add_contents(content_list: Array[QuestContent], contents: Array) -> void:
	if content_list == null:
		return
	for content in contents:
		content_list.append(content)


## Adds content to a state of the quest in a UI category (dialogue, journal or HUD).
func add_state_contents(state: Quest.State, category: QuestContent.Category, contents: Array) -> void:
	QuestStateInfo.validate_list(quest.state_info_list, Quest.State.size())
	add_contents(quest.state_info_list[state].get_content_list(category), contents)


func create_title_content() -> QuestContent:
	var content := QuestHeadingContent.new()
	content.resource_name = "title"
	content.use_quest_title = true
	content.heading_level = 1
	return content


func create_heading_content(text: String, level: int) -> QuestContent:
	var content := QuestHeadingContent.new()
	content.resource_name = "heading"
	content.use_quest_title = false
	content.text = text
	content.heading_level = level
	return content


func create_body_content(text: String) -> QuestContent:
	var content := QuestBodyContent.new()
	content.resource_name = "text"
	content.text = text
	return content

#endregion
#region Nodes

func get_start_node() -> QuestNode:
	return quest.node_list[0]


func get_node(node_id: String) -> QuestNode:
	for node in quest.node_list:
		if node.id == node_id:
			return node
	return null


## Adds a node as a child of [param parent]. Returns null if there is no valid parent.
func add_node(parent: QuestNode, id: String, internal_name: String, node_type: QuestNode.Type, is_optional := false) -> QuestNode:
	if parent == null:
		push_warning("Quests: QuestBuilder.add_node must be provided a valid parent node.")
		return null
	if get_node(id) != null:
		push_warning("Quests: QuestBuilder already has a node with id '%s'." % id)
	var node := QuestNode.new()
	node.id = id
	node.internal_name = internal_name
	node.node_type = node_type
	node.is_optional = is_optional
	node.editor_position = Vector2(parent.editor_position.x, parent.editor_position.y + 20.0 + 48.0)
	parent.children.append(id)
	quest.node_list.append(node)
	_validate_node(node)
	return node


func add_success_node(parent: QuestNode) -> QuestNode:
	return add_node(parent, "success", "Success", QuestNode.Type.SUCCESS)


func add_failure_node(parent: QuestNode) -> QuestNode:
	return add_node(parent, "failure", "Failure", QuestNode.Type.FAILURE)


func add_passthrough_node(parent: QuestNode, id: String, internal_name: String) -> QuestNode:
	return add_node(parent, id, internal_name, QuestNode.Type.PASSTHROUGH)


func add_condition_node(parent: QuestNode, id: String, internal_name: String,
		condition_count_mode := QuestConditionSet.Mode.ALL, is_optional := false) -> QuestNode:
	var node := add_node(parent, id, internal_name, QuestNode.Type.CONDITION, is_optional)
	if node == null:
		return null
	node.condition_set.condition_count_mode = condition_count_mode
	return node


## Adds a condition node that is true when the quester discusses this quest with
## the target. [param node_id] defaults to "talkTo" plus the target id.
func add_discuss_quest_node(parent: QuestNode, target_specifier: QuestMessages.Participant, target_id: String,
		is_optional := false, node_id := "") -> QuestNode:
	var node := add_condition_node(parent, "talkTo" + target_id if node_id.is_empty() else node_id,
			"Talk to " + target_id, QuestConditionSet.Mode.ALL, is_optional)
	if node == null:
		return null
	add_message_condition(node, QuestMessages.Participant.QUESTER, "", target_specifier, target_id,
			QuestMessages.DISCUSSED_QUEST, quest.id)
	return node

#endregion
#region Conditions

func add_counter_condition(node: QuestNode, counter_name: String, condition_mode: QuestCounterCondition.CounterValueMode,
		required_value: Variant) -> QuestCounterCondition:
	var condition := QuestCounterCondition.new()
	condition.resource_name = "counterCondition"
	condition.counter_name = counter_name
	condition.counter_value_mode = condition_mode
	condition.required_counter_value = required_value if required_value is QuestNumber else QuestNumber.literal(int(required_value))
	node.condition_set.condition_list.append(condition)
	return condition


func add_message_condition(node: QuestNode, sender_specifier: QuestMessages.Participant, sender_id: String,
		target_specifier: QuestMessages.Participant, target_id: String, message: String, parameter: String,
		value: QuestMessageValue = null) -> QuestMessageCondition:
	var condition := QuestMessageCondition.new()
	condition.resource_name = "messageCondition"
	condition.sender_specifier = sender_specifier
	condition.sender_id = sender_id
	condition.target_specifier = target_specifier
	condition.target_id = target_id
	condition.message = message
	condition.parameter = parameter
	condition.value = value if value != null else QuestMessageValue.new()
	node.condition_set.condition_list.append(condition)
	return condition


func add_parent_condition(node: QuestNode, parent_count_mode: QuestConditionSet.Mode, min_parent_count := 1) -> QuestParentCondition:
	var condition := QuestParentCondition.new()
	condition.resource_name = "parentCondition"
	condition.parent_count_mode = parent_count_mode
	condition.min_parent_count = min_parent_count
	node.condition_set.condition_list.append(condition)
	return condition

#endregion
#region Actions

func create_alert_action(text: String) -> QuestAction:
	var alert_action := QuestAlertAction.new()
	add_contents(alert_action.content_list, [create_body_content(text)])
	return alert_action


func create_message_action(message_or_text: String, parameter: Variant = null) -> QuestAction:
	var action := QuestMessageAction.new()
	if parameter == null:
		# "parameter:message" form.
		var colon := message_or_text.find(":")
		if colon >= 0:
			action.message = message_or_text.substr(colon + 1)
			action.parameter = message_or_text.substr(0, colon)
		else:
			action.message = message_or_text
			action.parameter = ""
	else:
		action.message = message_or_text
		action.parameter = str(parameter)
	action.value = QuestMessageValue.new()
	return action


func create_set_indicator_action(quest_id: String, entity_id: String, indicator_state: Quest.IndicatorState) -> QuestAction:
	var action := QuestSetIndicatorAction.new()
	action.quest_id = quest_id
	action.entity_id = entity_id
	action.indicator_state = indicator_state
	return action

#endregion
