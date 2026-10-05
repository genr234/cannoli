extends QuestsTest

var fx: QuestsGeneratorFixture
var _heard: Array[QuestMessageArgs] = []


func before_each() -> void:
	QuestGeneratorData.reset_runtime_data()
	fx = QuestsGeneratorFixture.new()
	_heard.clear()
	make_manager()


func after_each() -> void:
	fx = null
	QuestGeneratorData.reset_static_state()


func _make_npc() -> QuestGeneratorEntity:
	var npc := Node.new()
	var giver := QuestGiver.new()
	giver.id = "captain"
	giver.display_name = "Captain Molly"
	npc.add_child(giver)
	var generator := QuestGeneratorEntity.new()
	generator.entity_type = fx.villager_type
	generator.domain_type = fx.village
	npc.add_child(generator)
	add_node(npc)
	return generator


func _make_quest(world: QuestWorldModel, return_to_complete: bool, reward_systems: Array[QuestRewardSystem] = []) -> Quest:
	var generator := _make_npc()
	var planner := QuestPlanner.new()
	planner.frame_slicing = false
	planner.rng.seed = 42
	var plan := await planner.make_plan(fx.villager_type, fx.village, world)
	assert_true(plan != null, "plan found")
	var builder := QuestPlanToQuestBuilder.new()
	builder.rng.seed = 42
	var no_contents: Array[QuestContent] = []
	var quest := builder.convert_plan_to_quest(generator, "Village", plan.goal, plan.motive, plan, return_to_complete, no_contents, reward_systems)
	return track_quest(quest)


func _on_heard(args: QuestMessageArgs) -> void:
	_heard.append(args)


func test_kill_quest_structure() -> void:
	var quest := await _make_quest(fx.new_world_model(3), false)
	assert_true(quest.title.begins_with("Kill "), "title is verb plus descriptor: " + quest.title)
	assert_eq(quest.group, "Village", "group")
	assert_eq(quest.goal_entity_type_name, "Orc", "goal entity type recorded")
	assert_true(quest.is_procedurally_generated, "marked as generated")
	assert_true(quest.is_trackable and quest.show_in_track_hud, "trackable")
	assert_eq(quest.tag_dictionary[QuestTags.TARGET], "Orc", "target tag")
	assert_eq(quest.tag_dictionary[QuestTags.TARGETS], "Orcs", "targets tag")
	assert_eq(quest.tag_dictionary[QuestTags.ACTION], "Kill", "action tag")
	assert_eq(quest.tag_dictionary[QuestTags.DOMAIN], "Forest", "domain tag")
	var counter := quest.get_counter("OrcsKilled")
	assert_true(counter != null, "counter named after plural target and counter base name")
	assert_eq(counter.max_value, 50, "counter max from the verb")
	assert_eq(counter.message_event_list[0].parameter, "Orc", "{TARGETENTITY} replaced in the counter event parameter")
	var step := quest.get_node("1")
	assert_true(step != null and step.node_type == QuestNode.Type.CONDITION, "step node")
	var condition := step.condition_set.condition_list[0] as QuestCounterCondition
	assert_true(condition != null, "counter condition")
	assert_eq(condition.counter_name, "OrcsKilled", "condition counter")
	assert_true(condition.required_counter_value.literal_value >= 2, "required count")
	assert_true(quest.get_node("success") != null, "success node")
	assert_true(quest.get_node("Rewards") != null, "rewards node")
	assert_true(quest.get_node("Return") == null, "no return node when not required")
	assert_true(quest.get_start_node().children.has("1") and quest.get_start_node().children.has("Rewards"), "start links to the first step and rewards")
	assert_true(quest.offer_content_list.size() >= 2, "offer shows title and motive text")
	var offer_body := quest.offer_content_list[1] as QuestBodyContent
	assert_true(offer_body != null and offer_body.text.contains("Forest"), "motive text had {DOMAIN} replaced: " + str(offer_body.text if offer_body else ""))


func test_kill_quest_completes_from_messages() -> void:
	var quest := await _make_quest(fx.new_world_model(3), false)
	var needed := (quest.get_node("1").condition_set.condition_list[0] as QuestCounterCondition).required_counter_value.literal_value
	var instance := quest.clone() if not quest.is_instance else quest
	instance.set_state(Quest.State.ACTIVE)
	assert_eq(instance.get_node("1").get_state(), QuestNode.State.ACTIVE, "step active")
	for i in needed - 1:
		QuestMessages.send(null, null, "Killed", "Orc")
	assert_eq(instance.get_state(), Quest.State.ACTIVE, "not done yet")
	QuestMessages.send(null, null, "Killed", "Wolf")
	assert_eq(instance.get_counter("OrcsKilled").current_value, needed - 1, "other parameters don't count")
	QuestMessages.send(null, null, "Killed", "Orc")
	assert_eq(instance.get_counter("OrcsKilled").current_value, needed, "counter reached the goal")
	assert_eq(instance.get_state(), Quest.State.SUCCESSFUL, "quest succeeds")
	instance.dispose()


func test_return_node_requires_talking_to_the_giver() -> void:
	var quest := await _make_quest(fx.new_world_model(2), true)
	var return_node := quest.get_node("Return")
	assert_true(return_node != null, "return node exists")
	assert_true(quest.get_node("1").children.has("Return"), "step leads to the return node")
	assert_true(return_node.children.has("success"), "return leads to success")
	assert_eq(return_node.state_info_list[QuestNode.State.ACTIVE].action_list.size(), 2, "alert and indicator actions")
	assert_true(return_node.state_info_list[QuestNode.State.ACTIVE].action_list[0] is QuestAlertAction, "alert action")
	var indicator := return_node.state_info_list[QuestNode.State.ACTIVE].action_list[1] as QuestSetIndicatorAction
	assert_true(indicator != null and indicator.indicator_state == Quest.IndicatorState.TALK, "talk indicator")
	var message_condition := return_node.condition_set.condition_list[0] as QuestMessageCondition
	assert_eq(message_condition.message, QuestMessages.DISCUSSED_QUEST, "waits for the discussed-quest message")
	assert_eq(message_condition.target_id, "captain", "target is the giver")
	assert_eq(return_node.state_info_list[QuestNode.State.ACTIVE].hud_content.size(), 1, "hud text")
	var hud := return_node.state_info_list[QuestNode.State.ACTIVE].hud_content[0] as QuestBodyContent
	assert_eq(hud.text, "{Return to} Captain Molly", "hud text uses the {Return to} tag and the giver's name")


func test_multi_step_quest_uses_counter_and_message_conditions() -> void:
	var quest := await _make_quest(fx.new_world_model(0, 2, 1), false)
	assert_true(quest.get_node("1") != null and quest.get_node("2") != null, "two step nodes")
	assert_true(quest.get_node("1").children.has("2"), "step 1 leads to step 2")
	assert_true(quest.get_node("2").children.has("success"), "step 2 leads to success")
	assert_true(quest.get_node("2").condition_set.condition_list[0] is QuestMessageCondition, "craft is completed by a message")
	var instance := quest
	instance.set_state(Quest.State.ACTIVE)
	assert_eq(instance.get_node("2").get_state(), QuestNode.State.INACTIVE, "step 2 waits for step 1")
	var counter_name := ""
	for c in instance.counter_list:
		counter_name = c.name
	assert_true(not counter_name.is_empty(), "the collect step has a counter")
	var needed := (instance.get_node("1").condition_set.condition_list[0] as QuestCounterCondition).required_counter_value.literal_value
	for i in needed:
		QuestMessages.send(null, null, "Got", "Iron")
	assert_eq(instance.get_node("1").get_state(), QuestNode.State.TRUE, "collecting done")
	assert_eq(instance.get_node("2").get_state(), QuestNode.State.ACTIVE, "crafting is active")
	await frames(2) # Message conditions start listening a frame after their node becomes active.
	QuestMessages.send(null, null, "Crafted", "Sword")
	assert_eq(instance.get_state(), Quest.State.SUCCESSFUL, "quest succeeds after crafting")
	instance.dispose()


func test_step_text_goes_to_the_right_categories() -> void:
	var quest := await _make_quest(fx.new_world_model(3), false)
	var active := quest.get_node("1").state_info_list[QuestNode.State.ACTIVE]
	assert_eq(active.dialogue_content.size(), 1, "dialogue text")
	assert_true((active.dialogue_content[0] as QuestBodyContent).text.begins_with("Kill "), "task text")
	assert_true((active.dialogue_content[0] as QuestBodyContent).text.contains("Orcs"), "{TARGETDESCRIPTOR} replaced")
	assert_eq((active.hud_content[0] as QuestBodyContent).text, "Kill {#OrcsKilled}/%d" % (quest.get_node("1").condition_set.condition_list[0] as QuestCounterCondition).required_counter_value.literal_value, "hud text uses counter tags")
	assert_eq(active.action_list.size(), 1, "alert action from alert text")
	var active_info := quest.get_state_info(Quest.State.ACTIVE)
	assert_eq(active_info.dialogue_content.size(), 1, "quest title in active dialogue")
	assert_eq(active_info.hud_content.size(), 1, "quest title in active hud")
	var successful := quest.get_state_info(Quest.State.SUCCESSFUL)
	assert_eq(successful.dialogue_content.size(), 2, "title and completion text in successful dialogue")


func test_rewards_are_added_by_reward_systems() -> void:
	var xp := QuestXPRewardSystem.new()
	var coins := QuestMessageRewardSystem.new()
	var systems: Array[QuestRewardSystem] = [xp, coins]
	var quest := await _make_quest(fx.new_world_model(3), false, systems)
	var texts := PackedStringArray()
	for content in quest.offer_content_list:
		if content is QuestBodyContent:
			texts.append(content.text)
	var found_xp := false
	var found_coins := false
	for t in texts:
		found_xp = found_xp or t.ends_with(" XP")
		found_coins = found_coins or t.ends_with(" Coins")
	assert_true(found_xp and found_coins, "offer text lists both rewards: " + str(texts))
	assert_eq(quest.get_state_info(Quest.State.SUCCESSFUL).action_list.size(), 2, "success sends two reward messages")
	var rewards_node := quest.get_node("Rewards")
	assert_true(rewards_node.state_info_list[QuestNode.State.TRUE].journal_content.size() >= 2, "rewards shown in the journal when done")
	xp.free()
	coins.free()


func test_reward_systems_directly() -> void:
	var quest := Quest.create("q")
	var xp := QuestXPRewardSystem.new()
	assert_eq(xp.determine_reward(10, quest, fx.orc_type), 10, "xp doesn't consume points")
	fx.orc_type.reward_multipliers[QuestRewardMultiplier.Category.XP] = 2.0
	xp.determine_reward(10, quest, fx.orc_type)
	assert_eq((quest.offer_content_list[0] as QuestBodyContent).text, "10 XP", "first xp text")
	assert_eq((quest.offer_content_list[1] as QuestBodyContent).text, "20 XP", "multiplier applied")
	var coins := QuestMessageRewardSystem.new()
	assert_eq(coins.determine_reward(10, quest), 0, "coins consume points")
	coins.consume_points = false
	assert_eq(coins.determine_reward(10, quest), 10, "unless told not to")
	var message := quest.get_state_info(Quest.State.SUCCESSFUL).action_list[-1] as QuestMessageAction
	assert_eq(message.message, "Get", "message")
	assert_eq(message.value.int_value, 10, "value")
	xp.free()
	coins.free()


func test_generated_quest_serializes() -> void:
	var quest := await _make_quest(fx.new_world_model(3), true)
	var data := QuestSerializer.quest_to_dict(quest)
	var json := JSON.stringify(data)
	var restored := track_quest(QuestSerializer.dict_to_quest(JSON.parse_string(json)))
	assert_eq(restored.id, quest.id, "id survives")
	assert_eq(restored.node_list.size(), quest.node_list.size(), "nodes survive")
	assert_eq(restored.counter_list.size(), quest.counter_list.size(), "counters survive")
	assert_eq(restored.goal_entity_type_name, "Orc", "goal entity survives")


func test_quest_with_return_node_completes_after_discussing() -> void:
	var quest := await _make_quest(fx.new_world_model(2), true)
	quest.assign_quester(QuestParticipant.new("player", "Player"))
	quest.assign_quest_giver(QuestParticipant.new("captain", "Captain Molly"))
	quest.set_state(Quest.State.ACTIVE)
	var needed := (quest.get_node("1").condition_set.condition_list[0] as QuestCounterCondition).required_counter_value.literal_value
	for i in needed:
		QuestMessages.send(null, null, "Killed", "Orc")
	assert_eq(quest.get_node("Return").get_state(), QuestNode.State.ACTIVE, "return node is active")
	assert_eq(quest.get_state(), Quest.State.ACTIVE, "quest is not done until the giver is visited")
	await frames(2)
	QuestMessages.send("player", "captain", QuestMessages.DISCUSSED_QUEST, quest.id)
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL, "quest succeeds after returning to the giver")
	quest.dispose()


class RecordingBuilder extends QuestPlanToQuestBuilder:
	var built: Quest

	func convert_plan_to_quest(entity: QuestEntity, group: String, goal: QuestPlanStep, motive: QuestMotive, plan: QuestPlan,
			require_return_to_complete: bool, rewards_ui_contents: Array[QuestContent], reward_systems: Array[QuestRewardSystem]) -> Quest:
		built = super.convert_plan_to_quest(entity, group, goal, motive, plan, require_return_to_complete, rewards_ui_contents, reward_systems)
		return built


func _generate_with(recorder: RecordingBuilder, callback: Callable) -> void:
	var generator := _make_npc()
	var planner := QuestPlanner.new()
	planner.frame_slicing = false
	planner.rng.seed = 42
	planner.plan_to_quest_builder = recorder
	var no_contents: Array[QuestContent] = []
	var no_systems: Array[QuestRewardSystem] = []
	var no_quests: Array[Quest] = []
	planner.generate_quest(generator, "Village", fx.village, fx.new_world_model(3), false, no_contents, no_systems, no_quests,
			callback, null, false)
	await frames(2)


func test_quest_is_disposed_when_nobody_takes_it() -> void:
	var recorder := RecordingBuilder.new()
	await _generate_with(recorder, Callable())
	assert_not_null(recorder.built, "a quest was built")
	assert_eq(recorder.built.get_state(), Quest.State.DISABLED, "but it was disposed of because there is no callback")


func test_quest_is_handed_to_the_callback() -> void:
	var recorder := RecordingBuilder.new()
	var received: Array[Quest] = []
	await _generate_with(recorder, func(q: Quest) -> void: received.append(q))
	assert_eq(received.size(), 1, "the callback was called once")
	track_quest(received[0])
	assert_eq(received[0], recorder.built, "with the quest that was built")
	assert_ne(received[0].get_state(), Quest.State.DISABLED, "which is left for the receiver to dispose of")


func test_message_reward_can_use_the_reward_action_format() -> void:
	var coins := QuestMessageRewardSystem.new()
	assert_eq(coins.message, "Get", "the original defaults are kept")
	assert_eq(coins.parameter, "Coin", "parameter")
	coins.use_reward_message_format("gold")
	var quest := Quest.create("q")
	coins.determine_reward(10, quest)
	var action := quest.get_state_info(Quest.State.SUCCESSFUL).action_list[-1] as QuestMessageAction
	assert_eq(action.message, QuestRewardAction.REWARD_MESSAGE, "same message as the reward action")
	assert_eq(action.parameter, "gold", "reward id as parameter")
	assert_eq(action.value.int_value, 10, "amount as value")
	assert_eq(action.sender_id, QuestTags.QUESTGIVERID, "sent by the giver")
	assert_eq(action.target_id, QuestTags.QUESTERID, "to the quester")
	coins.free()
