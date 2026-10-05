extends QuestsTest


func test_builder_creates_start_node_and_lists() -> void:
	var builder := QuestBuilder.new("Wolves", "wolves_quest", "Wolf Hunt")
	var quest := track_quest(builder.to_quest())
	assert_eq(quest.id, "wolves_quest", "id")
	assert_eq(quest.title, "Wolf Hunt", "title")
	assert_eq(quest.node_list.size(), 1, "start node only")
	assert_eq(quest.get_start_node().node_type, QuestNode.Type.START, "start node type")
	assert_eq(quest.state_info_list.size(), Quest.State.size(), "state infos")
	assert_true(quest.is_procedurally_generated, "built quests are marked generated")


func test_counters_and_events() -> void:
	var builder := QuestBuilder.new("q")
	track_quest(builder.quest)
	var counter := builder.add_counter("wolves", 0, 0, 5, false, QuestCounter.UpdateMode.MESSAGES)
	assert_true(counter != null, "counter added")
	assert_true(builder.add_counter("wolves", 0, 0, 5, false, QuestCounter.UpdateMode.MESSAGES) == null, "duplicate refused")
	builder.add_counter_message_event("wolves", "", "Killed", "Wolf", QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE, 1)
	assert_eq(counter.message_event_list.size(), 1, "event added")
	assert_eq(counter.message_event_list[0].parameter, "Wolf", "event parameter")


func test_nodes_link_by_id() -> void:
	var builder := QuestBuilder.new("q")
	track_quest(builder.quest)
	var a := builder.add_condition_node(builder.get_start_node(), "a", "A")
	var b := builder.add_passthrough_node(a, "b", "B")
	var failure := builder.add_failure_node(b)
	var quest := builder.to_quest()
	assert_eq(quest.node_list.size(), 4, "four nodes")
	assert_true(builder.get_start_node().children.has("a"), "start -> a")
	assert_true(a.children.has("b"), "a -> b")
	assert_eq(failure.node_type, QuestNode.Type.FAILURE, "failure node")
	assert_eq(quest.get_node("b").node_type, QuestNode.Type.PASSTHROUGH, "lookup by id")
	assert_true(builder.add_node(null, "x", "X", QuestNode.Type.SUCCESS) == null, "null parent refused")


func test_content_and_actions() -> void:
	var builder := QuestBuilder.new("q", "q", "Quest")
	track_quest(builder.quest)
	builder.add_offer_contents([builder.create_title_content(), builder.create_body_content("Hello")])
	builder.add_offer_unmet_contents([builder.create_heading_content("Not yet", 2)])
	var quest := builder.quest
	assert_eq(quest.offer_content_list.size(), 2, "offer content")
	assert_eq(quest.offer_conditions_unmet_content_list.size(), 1, "unmet content")
	var message := builder.create_message_action("Coin:Get") as QuestMessageAction
	assert_eq(message.message, "Get", "text after the colon is the message")
	assert_eq(message.parameter, "Coin", "text before the colon is the parameter")
	var plain := builder.create_message_action("Hello") as QuestMessageAction
	assert_eq(plain.message, "Hello", "no colon")
	assert_eq(plain.parameter, "", "no parameter")
	var explicit := builder.create_message_action("Get", "Gold") as QuestMessageAction
	assert_eq(explicit.parameter, "Gold", "explicit parameter")
	var alert := builder.create_alert_action("Careful") as QuestAlertAction
	assert_eq(alert.content_list.size(), 1, "alert content")
	var indicator := builder.create_set_indicator_action("q", "npc", Quest.IndicatorState.TALK) as QuestSetIndicatorAction
	assert_eq(indicator.indicator_state, Quest.IndicatorState.TALK, "indicator state")


func test_built_quest_runs_with_counter_and_message_conditions() -> void:
	var builder := QuestBuilder.new("hunt", "hunt", "Hunt")
	builder.add_counter("wolves", 0, 0, 3, false, QuestCounter.UpdateMode.MESSAGES)
	builder.add_counter_message_event("wolves", "", "Killed", "Wolf", QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE, 1)
	var kill := builder.add_condition_node(builder.get_start_node(), "kill", "Kill wolves")
	builder.add_counter_condition(kill, "wolves", QuestCounterCondition.CounterValueMode.AT_LEAST, 2)
	var report := builder.add_condition_node(kill, "report", "Report")
	builder.add_message_condition(report, QuestMessages.Participant.ANY, "", QuestMessages.Participant.ANY, "", "Reported", "hunt")
	builder.add_success_node(report)
	var asset := track_quest(builder.to_quest())
	var quest := make_quest_instance(asset)
	quest.set_state(Quest.State.ACTIVE)
	QuestMessages.send(null, null, "Killed", "Wolf")
	assert_eq(quest.get_counter("wolves").current_value, 1, "one wolf")
	assert_eq(quest.get_node("kill").get_state(), QuestNode.State.ACTIVE, "needs two wolves")
	QuestMessages.send(null, null, "Killed", "Wolf")
	assert_eq(quest.get_node("kill").get_state(), QuestNode.State.TRUE, "two wolves done")
	assert_eq(quest.get_node("report").get_state(), QuestNode.State.ACTIVE, "report is active")
	await frames(2) # Message conditions start listening a frame after their node becomes active.
	QuestMessages.send(null, null, "Reported", "hunt")
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL, "quest succeeds")


func test_dispose_releases_a_discarded_quest() -> void:
	var builder := QuestBuilder.new("discard", "discard_quest", "Discard")
	var quest := builder.to_quest()
	Quests.register_quest_instance(quest)
	builder.dispose()
	assert_null(builder.quest, "the builder lets go of the quest")
	assert_eq(quest.get_state(), Quest.State.DISABLED, "the quest was disposed of")
	assert_null(Quests.get_quest_instance("discard_quest"), "and unregistered")
	builder.dispose()
