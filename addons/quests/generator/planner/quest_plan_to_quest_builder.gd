class_name QuestPlanToQuestBuilder
extends RefCounted
## Converts a [QuestPlan] into a [Quest]. Each step becomes a condition node
## completed by a counter or a message. Extend this class and assign an
## instance to [member QuestPlanner.plan_to_quest_builder] to customize
## generated quests.

## Random numbers used when rolling reward system probabilities. The planner sets this.
var rng := RandomNumberGenerator.new()


func convert_plan_to_quest(entity: QuestEntity, group: String, goal: QuestPlanStep, motive: QuestMotive, plan: QuestPlan,
		require_return_to_complete: bool, rewards_ui_contents: Array[QuestContent], reward_systems: Array[QuestRewardSystem]) -> Quest:
	var main_target_entity := goal.fact.entity_type.get_asset_name()
	var main_target_descriptor := goal.fact.entity_type.get_descriptor(goal.required_counter_value)
	var domain_name := goal.fact.domain_type.get_display_name()
	var ids := _build_title(goal, main_target_descriptor)
	var title: String = ids[0]
	var quest_id: String = ids[1]
	var quest_builder := QuestBuilder.new(title, quest_id, title)
	_set_main_info(quest_builder, quest_id, title, group, goal)
	_add_tags_to_dictionary(quest_builder.quest.tag_dictionary, goal)
	quest_builder.get_start_node().editor_position = Vector2(120, 48)
	_add_offer_text(quest_builder, main_target_entity, main_target_descriptor, domain_name, goal, motive)
	var rewards_content_index := quest_builder.quest.offer_content_list.size()
	_add_rewards(quest_builder, entity, goal, rewards_ui_contents, reward_systems)
	_add_quest_headings(quest_builder, goal)
	_add_successful_text(quest_builder, main_target_entity, main_target_descriptor, domain_name, goal)
	var previous_node := _add_steps(quest_builder, domain_name, goal, plan)
	if require_return_to_complete:
		previous_node = _add_return_node(quest_builder, previous_node, entity, main_target_entity, main_target_descriptor,
				domain_name, goal, rewards_content_index)
	quest_builder.add_success_node(previous_node)
	_add_rewards_node(quest_builder, rewards_content_index)
	return quest_builder.to_quest()


## Returns [title, quest id].
func _build_title(goal: QuestPlanStep, main_target_descriptor: String) -> PackedStringArray:
	var title := goal.action.get_display_name() + " " + main_target_descriptor
	return PackedStringArray([title, title + " " + QuestBuilder.generate_guid()])


func _set_main_info(quest_builder: QuestBuilder, _quest_id: String, _title: String, group: String, goal: QuestPlanStep) -> void:
	quest_builder.quest.is_trackable = true
	quest_builder.quest.show_in_track_hud = true
	quest_builder.quest.icon = goal.fact.entity_type.image
	quest_builder.quest.group = group
	quest_builder.quest.goal_entity_type_name = goal.fact.entity_type.get_asset_name()


func _add_offer_text(quest_builder: QuestBuilder, main_target_entity: String, main_target_descriptor: String,
		domain_name: String, goal: QuestPlanStep, motive: QuestMotive) -> void:
	var motive_text: String
	if motive != null:
		motive_text = motive.text
	elif not goal.action.motives.is_empty() and goal.action.motives[0] != null:
		motive_text = goal.action.motives[0].text
	else:
		motive_text = goal.action.text.active_text.dialogue_text
	motive_text = _replace_step_tags(motive_text, main_target_entity, main_target_descriptor, domain_name, "", 0)
	quest_builder.add_offer_contents([quest_builder.create_title_content(), quest_builder.create_body_content(motive_text)])


func _add_rewards(quest_builder: QuestBuilder, entity: QuestEntity, goal: QuestPlanStep, rewards_ui_contents: Array[QuestContent],
		reward_systems: Array[QuestRewardSystem]) -> void:
	if QuestPlanner.detailed_debug:
		print("Quests: [Generator] Checking %d reward systems for %d %s (level %d) on %s" % [reward_systems.size(), goal.fact.count,
				goal.fact.entity_type.get_asset_name(), goal.fact.entity_type.level, entity.name])
	for content in rewards_ui_contents:
		if content != null:
			quest_builder.quest.offer_content_list.append(content.duplicate())
	var points_remaining := goal.fact.entity_type.level * goal.fact.count
	for reward_system in reward_systems:
		if reward_system == null:
			continue
		if rng.randf() > reward_system.probability:
			continue
		points_remaining = reward_system.determine_reward(points_remaining, quest_builder.quest, goal.fact.entity_type)
		if points_remaining <= 0:
			break


func _add_quest_headings(quest_builder: QuestBuilder, goal: QuestPlanStep) -> void:
	var has_successful_dialogue_text := not goal.action.text.completed_text.dialogue_text.is_empty()
	var has_successful_journal_text := not goal.action.text.completed_text.journal_text.is_empty()
	_add_quest_heading(quest_builder, QuestContent.Category.DIALOGUE, has_successful_dialogue_text)
	_add_quest_heading(quest_builder, QuestContent.Category.JOURNAL, has_successful_journal_text)
	_add_quest_heading(quest_builder, QuestContent.Category.HUD, false)


func _add_quest_heading(quest_builder: QuestBuilder, category: QuestContent.Category, add_to_successful_list: bool) -> void:
	quest_builder.add_state_contents(Quest.State.ACTIVE, category, [quest_builder.create_title_content()])
	if add_to_successful_list and category != QuestContent.Category.HUD:
		quest_builder.add_state_contents(Quest.State.SUCCESSFUL, category, [quest_builder.create_title_content()])


func _add_successful_text(quest_builder: QuestBuilder, main_target_entity: String, main_target_descriptor: String,
		domain_name: String, goal: QuestPlanStep) -> void:
	var completed := goal.action.text.completed_text
	if not completed.dialogue_text.is_empty():
		var text := _replace_step_tags(completed.dialogue_text, main_target_entity, main_target_descriptor, domain_name, "", 0)
		quest_builder.add_state_contents(Quest.State.SUCCESSFUL, QuestContent.Category.DIALOGUE, [quest_builder.create_body_content(text)])
	if not completed.journal_text.is_empty():
		var text := _replace_step_tags(completed.journal_text, main_target_entity, main_target_descriptor, domain_name, "", 0)
		quest_builder.add_state_contents(Quest.State.SUCCESSFUL, QuestContent.Category.JOURNAL, [quest_builder.create_body_content(text)])


func _add_steps(quest_builder: QuestBuilder, domain_name: String, goal: QuestPlanStep, plan: QuestPlan) -> QuestNode:
	var previous_node := quest_builder.get_start_node()
	var counter_names: Dictionary = {}
	for i in plan.steps.size():
		var step := plan.steps[i]
		var is_last_step := i == plan.steps.size() - 1
		var target_entity := step.fact.entity_type.get_asset_name()
		var target_descriptor := step.fact.entity_type.get_descriptor(step.required_counter_value)
		var id := str(i + 1)
		var internal_name := step.action.get_display_name() + " " + target_descriptor
		var condition_node := quest_builder.add_condition_node(previous_node, id, internal_name, QuestConditionSet.Mode.ALL)
		previous_node = condition_node
		var info := _add_step_condition(quest_builder, condition_node, target_entity, target_descriptor, domain_name, counter_names, goal, step)
		var counter_name: String = info[0]
		var required_counter_value: int = info[1]
		var active_state := condition_node.state_info_list[QuestNode.State.ACTIVE]
		_add_step_node_text(quest_builder, condition_node, active_state, target_entity, target_descriptor, domain_name,
				counter_name, required_counter_value, step, step.action.text.active_text, false)
		if not step.action.text.active_text.alert_text.is_empty():
			active_state.action_list.append(quest_builder.create_alert_action(_replace_step_tags(
					step.action.text.active_text.alert_text, target_entity, target_descriptor, domain_name, counter_name, required_counter_value)))
		if not step.action.send_message_on_active.is_empty():
			active_state.action_list.append(quest_builder.create_message_action(_replace_step_tags(
					step.action.send_message_on_active, target_entity, target_descriptor, domain_name, counter_name, required_counter_value)))
		var true_state := condition_node.state_info_list[QuestNode.State.TRUE]
		_add_step_node_text(quest_builder, condition_node, true_state, target_entity, target_descriptor, domain_name,
				counter_name, required_counter_value, step, step.action.text.completed_text, is_last_step)
		if not step.action.send_message_on_completion.is_empty():
			true_state.action_list.append(quest_builder.create_message_action(_replace_step_tags(
					step.action.send_message_on_completion, target_entity, target_descriptor, domain_name, counter_name, required_counter_value)))
	return previous_node


## Adds the step's completion condition. Returns [counter name, required counter value].
func _add_step_condition(quest_builder: QuestBuilder, condition_node: QuestNode, target_entity: String, target_descriptor: String,
		domain_name: String, counter_names: Dictionary, goal: QuestPlanStep, step: QuestPlanStep) -> Array:
	var counter_name := ""
	var required_counter_value := 0
	var completion := step.action.completion
	if completion.mode == QuestVerbCompletion.Mode.COUNTER:
		counter_name = goal.fact.entity_type.get_plural_display_name() + completion.base_counter_name
		if not counter_names.has(counter_name):
			counter_names[counter_name] = true
			var counter := quest_builder.add_counter(counter_name, completion.initial_value, completion.min_value,
					completion.max_value, false, completion.update_mode)
			if counter != null:
				for message_event in completion.message_event_list:
					var parameter := message_event.parameter.replace("{TARGETENTITY}", target_entity).replace("{DOMAIN}", domain_name)
					var counter_message_event := QuestCounterMessageEvent.create(message_event.message, parameter,
							message_event.operation, message_event.literal_value)
					counter_message_event.sender_specifier = _get_specifier(completion.sender_specifier, completion.sender_id)
					counter_message_event.target_specifier = _get_specifier(completion.target_specifier, completion.target_id)
					counter_message_event.sender_id = completion.sender_id
					counter_message_event.target_id = completion.target_id
					counter.message_event_list.append(counter_message_event)
		var counter_value_mode := completion.counter_value_mode
		if counter_value_mode == QuestCounterCondition.CounterValueMode.AT_LEAST:
			required_counter_value = mini(step.required_counter_value, step.fact.count)
		else:
			required_counter_value = maxi(step.required_counter_value, step.fact.count)
		quest_builder.add_counter_condition(condition_node, counter_name, counter_value_mode, required_counter_value)
	else:
		var parameter := completion.parameter.replace("{TARGETENTITY}", target_entity).replace("{DOMAIN}", domain_name)
		var sender_specifier := completion.sender_specifier
		var sender_id := completion.sender_id if sender_specifier == QuestMessages.Participant.ANY else _replace_step_tags(
				completion.sender_id, target_entity, target_descriptor, domain_name, counter_name, 0)
		var target_specifier := completion.target_specifier
		var target_id := completion.target_id if target_specifier == QuestMessages.Participant.ANY else _replace_step_tags(
				completion.target_id, target_entity, target_descriptor, domain_name, counter_name, 0)
		quest_builder.add_message_condition(condition_node, sender_specifier, sender_id, target_specifier, target_id,
				completion.message, parameter)
		if completion.message == QuestMessages.DISCUSS_QUEST or completion.message == QuestMessages.DISCUSSED_QUEST:
			if not target_id.is_empty():
				condition_node.speaker = target_id
			elif not sender_id.is_empty():
				condition_node.speaker = sender_id
	return [counter_name, required_counter_value]


func _get_specifier(specifier: QuestMessages.Participant, specifier_id: String) -> QuestMessages.Participant:
	if specifier != QuestMessages.Participant.OTHER:
		return specifier
	if specifier_id.is_empty():
		return QuestMessages.Participant.ANY
	if specifier_id == QuestTags.QUESTER or specifier_id == QuestTags.QUESTERID:
		return QuestMessages.Participant.QUESTER
	if specifier_id == QuestTags.QUESTGIVERID:
		return QuestMessages.Participant.QUEST_GIVER
	return QuestMessages.Participant.OTHER


func _add_step_node_text(quest_builder: QuestBuilder, _condition_node: QuestNode, state: QuestStateInfo, target_entity: String,
		target_descriptor: String, domain_name: String, counter_name: String, required_counter_value: int, _step: QuestPlanStep,
		action_state_text: QuestVerbStateText, is_last_step_completion: bool) -> void:
	var task_text := _replace_step_tags(action_state_text.dialogue_text, target_entity, target_descriptor, domain_name, counter_name, required_counter_value)
	if not task_text.is_empty():
		state.dialogue_content.append(quest_builder.create_body_content(task_text))
	var journal_text := _replace_step_tags(action_state_text.journal_text, target_entity, target_descriptor, domain_name, counter_name, required_counter_value)
	# The last step's completion text goes to the main quest success text, not the step node.
	if not (journal_text.is_empty() or is_last_step_completion):
		state.journal_content.append(quest_builder.create_body_content(journal_text))
	var hud_text := _replace_step_tags(action_state_text.hud_text, target_entity, target_descriptor, domain_name, counter_name, required_counter_value)
	if not hud_text.is_empty():
		state.hud_content.append(quest_builder.create_body_content(hud_text))


func _add_return_node(quest_builder: QuestBuilder, previous_node: QuestNode, entity: QuestEntity, main_target_entity: String,
		main_target_descriptor: String, domain_name: String, goal: QuestPlanStep, rewards_content_index := 9999) -> QuestNode:
	var quest_giver := entity.find_quest_list()
	var giver_id := quest_giver.id if quest_giver != null and not quest_giver.id.is_empty() else entity.get_display_name()
	var giver_name := quest_giver.display_name if quest_giver != null and not quest_giver.display_name.is_empty() else entity.get_display_name()
	var return_node := quest_builder.add_discuss_quest_node(previous_node, QuestMessages.Participant.QUEST_GIVER, giver_id, false, "Return")
	var hud_text := "{Return to} " + giver_name
	_add_return_node_text(quest_builder, return_node, giver_name, main_target_entity, main_target_descriptor, domain_name, goal, hud_text)
	var dialogue_list := return_node.state_info_list[QuestNode.State.ACTIVE].dialogue_content
	var offer_content_list := quest_builder.quest.offer_content_list
	for i in range(rewards_content_index, offer_content_list.size()):
		dialogue_list.append(offer_content_list[i].duplicate())
	var action_list := return_node.state_info_list[QuestNode.State.ACTIVE].action_list
	_add_return_node_alert(quest_builder, return_node, action_list, hud_text)
	_add_return_node_indicators(quest_builder, return_node, action_list, entity)
	return return_node


func _add_return_node_text(quest_builder: QuestBuilder, return_node: QuestNode, giver_name: String, main_target_entity: String,
		main_target_descriptor: String, domain_name: String, goal: QuestPlanStep, hud_text: String) -> void:
	var state_info := return_node.state_info_list[QuestNode.State.ACTIVE]
	var success_text := _replace_step_tags(goal.action.text.success_text, main_target_entity, main_target_descriptor, domain_name, "", 0)
	state_info.dialogue_content.append(quest_builder.create_body_content(success_text))
	state_info.journal_content.append(quest_builder.create_body_content("{Return to} " + giver_name + "."))
	state_info.hud_content.append(quest_builder.create_body_content(hud_text))


func _add_return_node_alert(quest_builder: QuestBuilder, _return_node: QuestNode, action_list: Array[QuestAction], hud_text: String) -> void:
	action_list.append(quest_builder.create_alert_action(hud_text))


func _add_return_node_indicators(quest_builder: QuestBuilder, return_node: QuestNode, action_list: Array[QuestAction], entity: QuestEntity) -> void:
	action_list.append(quest_builder.create_set_indicator_action(quest_builder.quest.id, entity.get_id(), Quest.IndicatorState.TALK))
	return_node.state_info_list[QuestNode.State.TRUE].action_list.append(
			quest_builder.create_set_indicator_action(quest_builder.quest.id, entity.get_id(), Quest.IndicatorState.NONE))


## Adds a passthrough node whose journal text shows the rewards once the quest is done.
func _add_rewards_node(quest_builder: QuestBuilder, rewards_content_index := 9999) -> void:
	var node := quest_builder.add_passthrough_node(quest_builder.get_start_node(), "Rewards", "Rewards")
	var journal_list := node.state_info_list[QuestNode.State.TRUE].journal_content
	var offer_content_list := quest_builder.quest.offer_content_list
	for i in range(rewards_content_index, offer_content_list.size()):
		journal_list.append(offer_content_list[i].duplicate())


func _replace_step_tags(s: String, target_entity: String, target_descriptor: String, domain_name: String, counter_name: String, counter_value: int) -> String:
	return s.replace("{#COUNTERNAME}", "{#" + counter_name + "}") \
			.replace("{#COUNTERGOAL}", str(counter_value)) \
			.replace("{TARGETENTITY}", target_entity) \
			.replace("{TARGETDESCRIPTOR}", target_descriptor) \
			.replace("{DOMAIN}", domain_name)


func _add_tags_to_dictionary(tag_dictionary: Dictionary, goal: QuestPlanStep) -> void:
	if goal == null:
		return
	tag_dictionary[QuestTags.DOMAIN] = goal.fact.domain_type.get_display_name()
	tag_dictionary[QuestTags.ACTION] = goal.action.get_display_name()
	tag_dictionary[QuestTags.TARGET] = goal.fact.entity_type.get_display_name()
	tag_dictionary[QuestTags.TARGETS] = goal.fact.entity_type.get_plural_display_name()
	tag_dictionary[QuestTags.TARGETDESCRIPTOR] = goal.fact.entity_type.get_descriptor(goal.required_counter_value)
	if goal.action.completion.mode == QuestVerbCompletion.Mode.COUNTER:
		tag_dictionary[QuestTags.COUNTERGOAL] = str(goal.required_counter_value)
