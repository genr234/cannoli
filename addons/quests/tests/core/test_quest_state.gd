extends QuestsTest

var journal: QuestJournal


func before_each() -> void:
	make_manager()
	journal = QuestTestHelpers.make_journal(self)


func _instance(asset: Quest) -> Quest:
	return journal.add_quest(asset)


func test_create_has_start_node_and_state_infos() -> void:
	var quest := Quest.create("q")
	assert_eq(quest.node_list.size(), 1)
	assert_eq(quest.get_start_node().id, "q.start")
	assert_eq(quest.get_start_node().node_type, QuestNode.Type.START)
	assert_eq(quest.state_info_list.size(), 6)
	assert_eq(quest.get_start_node().state_info_list.size(), 3)
	assert_eq(quest.get_state_info(Quest.State.DISABLED).action_list.size(), 0)


func test_state_info_list_autosizes() -> void:
	var quest := Quest.new()
	assert_eq(quest.state_info_list.size(), 6)
	var node := QuestNode.new()
	assert_eq(node.state_info_list.size(), 3)
	assert_eq(node.get_state_info(QuestNode.State.TRUE).get_content_list(QuestContent.Category.ALERT).size(), 0)


func test_clone_is_independent() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	var copy := make_quest_instance(asset)
	assert_true(copy.is_instance)
	assert_false(asset.is_instance)
	assert_eq(copy.original_asset, asset)
	assert_ne(copy.get_node("task"), asset.get_node("task"))
	assert_ne(copy.get_node("task").condition_set.condition_list[0], asset.get_node("task").condition_set.condition_list[0])
	assert_eq(copy.get_node("task").quest, copy)
	assert_eq(copy.get_node("task").parent_list.size(), 1)
	assert_eq(copy.get_node("task").child_list[0].id, "done")
	assert_eq(copy.get_node("task").condition_set.condition_list[0].quest, copy)


func test_new_instance_waits_and_is_offerable() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	assert_eq(quest.get_state(), Quest.State.WAITING_TO_START)
	assert_true(quest.is_offerable)
	assert_eq(quest.get_start_node().get_state(), QuestNode.State.INACTIVE)


func test_activate_walks_the_graph() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(quest.get_start_node().get_state(), QuestNode.State.TRUE)
	assert_eq(quest.get_node("task").get_state(), QuestNode.State.ACTIVE)
	assert_eq(quest.get_node("done").get_state(), QuestNode.State.INACTIVE)
	assert_eq(quest.get_state(), Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task").fire()
	assert_eq(quest.get_node("task").get_state(), QuestNode.State.TRUE)
	assert_eq(quest.get_node("done").get_state(), QuestNode.State.TRUE)
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)


func test_failure_node_fails_quest() -> void:
	var quest := _instance(QuestTestHelpers.chain("q", [QuestTestHelpers.condition_node("task"), QuestTestHelpers.node("bad", QuestNode.Type.FAILURE)]))
	quest.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task").fire()
	assert_eq(quest.get_state(), Quest.State.FAILED)


func test_passthrough_nodes_turn_true_automatically() -> void:
	var quest := _instance(QuestTestHelpers.chain("q", [
		QuestTestHelpers.node("p1"), QuestTestHelpers.node("p2"), QuestTestHelpers.node("end", QuestNode.Type.SUCCESS)]))
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(quest.get_node("p1").get_state(), QuestNode.State.TRUE)
	assert_eq(quest.get_node("p2").get_state(), QuestNode.State.TRUE)
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)


func test_condition_node_without_conditions_waits_forever() -> void:
	var node := QuestTestHelpers.condition_node("task", 0)
	var quest := _instance(QuestTestHelpers.chain("q", [node]))
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(quest.get_node("task").get_state(), QuestNode.State.ACTIVE)


func test_finishing_deactivates_active_nodes() -> void:
	var asset := QuestTestHelpers.parallel_quest("q", ["a", "b"])
	asset.get_node("a").children = PackedStringArray(["win"])
	asset.node_list.append(QuestTestHelpers.node("win", QuestNode.Type.SUCCESS))
	var quest := _instance(asset)
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(quest.get_node("b").get_state(), QuestNode.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "a").fire()
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)
	assert_eq(quest.get_node("b").get_state(), QuestNode.State.INACTIVE)
	assert_eq(QuestTestHelpers.test_condition(quest, "b").is_checking, false)


func test_leaving_active_stops_condition_checking() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	var condition := QuestTestHelpers.test_condition(quest, "task")
	assert_true(condition.is_checking)
	quest.set_state(Quest.State.FAILED)
	assert_false(condition.is_checking)
	condition.fire()
	assert_eq(quest.get_node("task").get_state(), QuestNode.State.INACTIVE)


func test_state_actions_run_in_order_and_only_when_informing() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	var quest_action := QuestTestAction.new()
	asset.get_state_info(Quest.State.ACTIVE).action_list.append(quest_action)
	var node_action := QuestTestAction.new()
	asset.get_node("task").get_state_info(QuestNode.State.ACTIVE).action_list.append(node_action)
	var quest := _instance(asset)
	var quest_instance_action: QuestTestAction = quest.get_state_info(Quest.State.ACTIVE).action_list[0]
	var node_instance_action: QuestTestAction = quest.get_node("task").get_state_info(QuestNode.State.ACTIVE).action_list[0]
	assert_ne(quest_instance_action, quest_action, "actions are cloned")
	quest.set_state(Quest.State.ACTIVE, false)
	assert_eq(quest_instance_action.executed, 0)
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(quest_instance_action.executed, 1)
	assert_eq(node_instance_action.executed, 1)
	assert_eq(quest_action.executed, 0)
	assert_eq(quest_instance_action.quest, quest)


func test_state_changed_signals_and_messages() -> void:
	var manager := QuestManager.instance
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	var events: Array[String] = []
	quest.state_changed.connect(func(_q: Quest) -> void: events.append("quest"))
	manager.quest_state_changed.connect(func(q: Quest, old: Quest.State, new: Quest.State) -> void:
		events.append("manager %s %s->%s" % [q.id, Quest.State.find_key(old), Quest.State.find_key(new)]))
	var nodes: Array[String] = []
	manager.quest_node_state_changed.connect(func(_q: Quest, n: QuestNode, s: QuestNode.State) -> void:
		nodes.append("%s=%s" % [n.id, QuestNode.State.find_key(s)]))
	var messages: Array[QuestMessageArgs] = []
	QuestMessages.add_listener(self, QuestMessages.QUEST_STATE_CHANGED, "q", func(args: QuestMessageArgs) -> void: messages.append(args))
	quest.set_state(Quest.State.ACTIVE)
	assert_true(events.has("quest"))
	assert_true(events.has("manager q WAITING_TO_START->ACTIVE"))
	assert_eq(nodes, ["q.start=ACTIVE", "q.start=TRUE", "task=ACTIVE"])
	assert_eq(messages.size(), 4, "one quest message and three node messages")
	assert_eq(messages[0].values, ["", Quest.State.ACTIVE])
	assert_eq(messages[1].values, ["q.start", QuestNode.State.ACTIVE])
	assert_eq(messages[0].sender, quest)


func test_set_state_without_informing_sends_nothing() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	var count := [0]
	quest.state_changed.connect(func(_q: Quest) -> void: count[0] += 1)
	quest.set_state(Quest.State.ACTIVE, false)
	assert_eq(count[0], 0)
	assert_eq(quest.get_state(), Quest.State.ACTIVE)
	assert_eq(quest.get_start_node().get_state(), QuestNode.State.INACTIVE, "nodes untouched")
	quest.set_state_raw(Quest.State.FAILED)
	assert_eq(quest.get_state(), Quest.State.FAILED)


func test_node_set_state_without_informing_still_checks_conditions() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE, false)
	quest.get_node("task").set_state(QuestNode.State.ACTIVE, false)
	assert_true(QuestTestHelpers.test_condition(quest, "task").is_checking)
	QuestTestHelpers.test_condition(quest, "task").fire()
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)


func test_reverting_true_to_active_resets_conditions() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	var condition := QuestTestHelpers.test_condition(quest, "task")
	condition.fire()
	assert_true(condition.already_true)
	quest.set_state(Quest.State.ACTIVE, false)
	quest.get_node("task").set_state(QuestNode.State.ACTIVE)
	assert_false(condition.already_true)
	assert_true(condition.is_checking)


func test_node_set_inactive_resets_conditions() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	var condition := QuestTestHelpers.test_condition(quest, "task")
	quest.get_node("task").set_state(QuestNode.State.INACTIVE)
	assert_false(condition.is_checking)
	assert_eq(quest.get_node("task").condition_set.num_true_conditions, 0)


func test_children_only_activate_while_quest_is_active() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	quest.get_start_node().set_state(QuestNode.State.TRUE)
	assert_eq(quest.get_node("task").get_state(), QuestNode.State.INACTIVE, "quest isn't active")


func test_node_lookup_and_missing_nodes() -> void:
	var quest := QuestTestHelpers.simple_quest("q")
	assert_not_null(quest.get_node("task"))
	assert_null(quest.get_node("nope"))
	assert_null(quest.get_node(""))


func test_speakers_recorded() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.quest_giver_id = "giver"
	asset.get_node("task").speaker = "guard"
	var quest := _instance(asset)
	assert_true(quest.speakers.has("giver"))
	assert_true(quest.speakers.has("guard"))
	assert_eq(quest.speakers.size(), 2)


func test_content_lists_follow_state_and_speaker() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.quest_giver_id = "giver"
	asset.get_state_info(Quest.State.ACTIVE).journal_content.append(QuestTestContent.make("quest journal"))
	asset.get_state_info(Quest.State.ACTIVE).dialogue_content.append(QuestTestContent.make("giver says"))
	var task := asset.get_node("task")
	task.speaker = "guard"
	task.get_state_info(QuestNode.State.ACTIVE).dialogue_content.append(QuestTestContent.make("guard says"))
	task.get_state_info(QuestNode.State.ACTIVE).hud_content.append(QuestTestContent.make("hud"))
	var quest := _instance(asset)
	assert_eq(quest.get_content_list(QuestContent.Category.JOURNAL).size(), 0, "not active yet")
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(quest.get_content_list(QuestContent.Category.JOURNAL).size(), 1)
	assert_eq(quest.get_content_list(QuestContent.Category.HUD).size(), 1)
	var giver_content := quest.get_content_list(QuestContent.Category.DIALOGUE)
	assert_eq(giver_content.size(), 1)
	assert_eq((giver_content[0] as QuestTestContent).text, "giver says")
	var guard_content := quest.get_content_list(QuestContent.Category.DIALOGUE, QuestParticipant.new("guard", "Guard"))
	assert_eq(guard_content.size(), 2, "the quest's own content plus the guard node's")
	assert_eq((guard_content[1] as QuestTestContent).text, "guard says")
	assert_true(quest.has_content(QuestContent.Category.DIALOGUE, QuestParticipant.new("guard")))
	assert_false(quest.has_content(QuestContent.Category.DIALOGUE, QuestParticipant.new("stranger")))
	assert_eq(quest.get_content_list(QuestContent.Category.OFFER).size(), 0)


func test_content_ids_and_lookup() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	var content := QuestTestContent.make("x")
	asset.assign_content_id(content)
	asset.assign_content_id(QuestTestContent.new())
	assert_eq(content.content_id, 0)
	assert_eq(asset.next_content_id, 2)
	asset.get_node("task").get_state_info(QuestNode.State.TRUE).journal_content.append(content)
	var quest := make_quest_instance(asset)
	assert_eq((quest.get_content_by_id(0) as QuestTestContent).text, "x")
	assert_null(quest.get_content_by_id(77))


func test_indicator_states_and_messages() -> void:
	var quest := _instance(QuestTestHelpers.simple_quest("q"))
	var heard: Array[QuestMessageArgs] = []
	QuestMessages.add_listener(self, QuestMessages.SET_INDICATOR_STATE, "q", func(a: QuestMessageArgs) -> void: heard.append(a))
	quest.set_indicator_state("npc", Quest.IndicatorState.TALK)
	assert_eq(quest.get_indicator_state("npc"), Quest.IndicatorState.TALK)
	assert_eq(quest.get_indicator_state("other"), Quest.IndicatorState.NONE)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0].get_target_id(), "npc")
	assert_eq(heard[0].values, [Quest.IndicatorState.TALK])
	quest.set_indicator_state("", Quest.IndicatorState.TALK)
	assert_eq(heard.size(), 1, "blank entity ignored")
	quest.clear_indicator_states()
	assert_eq(quest.get_indicator_state("npc"), Quest.IndicatorState.NONE)
	assert_eq(heard.size(), 2)
	assert_eq(heard[1].values, [Quest.IndicatorState.NONE])


func test_become_offerable_sets_giver_indicator() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.quest_giver_id = "npc"
	var heard: Array[QuestMessageArgs] = []
	QuestMessages.add_listener(self, QuestMessages.SET_INDICATOR_STATE, "q", func(a: QuestMessageArgs) -> void: heard.append(a))
	var quest := _instance(asset)
	assert_eq(heard[0].get_target_id(), "npc")
	assert_eq(heard[0].values, [Quest.IndicatorState.OFFER])
	assert_eq(quest.get_indicator_state("npc"), Quest.IndicatorState.NONE, "cleared again when the state is set")
	quest.become_offerable()
	assert_eq(quest.get_indicator_state("npc"), Quest.IndicatorState.OFFER)
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(quest.get_indicator_state("npc"), Quest.IndicatorState.OFFER, "kept while active")
	quest.set_state(Quest.State.FAILED)
	assert_eq(quest.get_indicator_state("npc"), Quest.IndicatorState.NONE, "cleared when the quest isn't active")


func test_compress_generated_content() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.is_procedurally_generated = true
	asset.get_state_info(Quest.State.ACTIVE).journal_content.append(QuestTestContent.make("old"))
	asset.get_state_info(Quest.State.SUCCESSFUL).journal_content.append(QuestTestContent.make("keep"))
	asset.offer_content_list.append(QuestTestContent.make("offer"))
	journal.only_remember_handwritten_quests = false
	var quest := _instance(asset)
	quest.set_state(Quest.State.ACTIVE)
	quest.compress_generated_content()
	assert_eq(quest.get_state_info(Quest.State.ACTIVE).journal_content.size(), 1, "only completed quests compress")
	QuestTestHelpers.test_condition(quest, "task").fire()
	quest.compress_generated_content()
	assert_eq(quest.get_state_info(Quest.State.ACTIVE).journal_content.size(), 0)
	assert_eq(quest.get_state_info(Quest.State.SUCCESSFUL).journal_content.size(), 1)
	assert_eq(quest.offer_content_list.size(), 0)
	assert_eq(quest.get_node("task").condition_set.condition_list.size(), 0)


func test_dispose_stops_everything() -> void:
	var quest := _instance(QuestTestHelpers.counter_quest("q", "n"))
	quest.set_state(Quest.State.ACTIVE)
	var condition := QuestTestHelpers.test_condition(quest, "task")
	assert_true(condition.is_checking)
	assert_eq(Quests.get_all_quest_instances().has("q"), true)
	journal.delete_quest("q")
	assert_false(condition.is_checking)
	assert_eq(quest.get_state(), Quest.State.DISABLED)
	assert_false(Quests.get_all_quest_instances().has("q"))
	assert_eq(quest.get_node("task").child_list.size(), 0)
	Quests.send_message("Set Quest Counter", "n", 5)
	assert_eq(quest.get_counter("n").current_value, 0)


func test_clone_copies_subassets_that_live_in_their_own_files() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	var shared := QuestTestAction.new()
	shared.take_over_path("res://addons/quests/tests/core/virtual_shared_action.tres")
	asset.get_state_info(Quest.State.ACTIVE).action_list.append(shared)
	asset.icon = load("res://addons/quests/icon.svg") as Texture2D
	var first := make_quest_instance(asset)
	var second := make_quest_instance(asset)
	var first_action: QuestTestAction = first.get_state_info(Quest.State.ACTIVE).action_list[0]
	var second_action: QuestTestAction = second.get_state_info(Quest.State.ACTIVE).action_list[0]
	assert_ne(first_action, shared)
	assert_ne(first_action, second_action)
	assert_eq(first.icon, asset.icon, "textures stay shared and keep their path")
	assert_eq(first.icon.resource_path, "res://addons/quests/icon.svg")
	shared.take_over_path("")
