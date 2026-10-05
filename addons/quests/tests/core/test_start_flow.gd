extends QuestsTest

var journal: QuestJournal


func before_each() -> void:
	QuestsTime.mode = QuestsTime.Mode.MANUAL
	QuestsTime.manual_time = 100.0
	make_manager()
	journal = QuestTestHelpers.make_journal(self)


func test_no_offer_conditions_means_offerable_at_once() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	var offered: Array[Quest] = []
	QuestManager.instance.quest_offerable.connect(func(q: Quest) -> void: offered.append(q))
	var quest := journal.add_quest(asset)
	assert_eq(offered.size(), 1)
	assert_eq(offered[0], quest)
	assert_true(quest.is_offerable)
	assert_true(quest.can_be_offered())


func test_offer_conditions_gate_offerable() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.offer_condition_set.condition_list.append(QuestTestCondition.new())
	var quest := journal.add_quest(asset)
	var offered := [0]
	quest.offerable.connect(func(_q: Quest) -> void: offered[0] += 1)
	assert_eq(quest.get_state(), Quest.State.WAITING_TO_START)
	assert_false(quest.is_offerable)
	assert_false(quest.can_be_offered())
	(quest.offer_condition_set.condition_list[0] as QuestTestCondition).fire()
	assert_eq(offered[0], 1)
	assert_true(quest.is_offerable)


func test_autostart_conditions_start_the_quest() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.autostart_condition_set.condition_list.append(QuestTestCondition.new())
	var quest := journal.add_quest(asset)
	assert_eq(quest.get_state(), Quest.State.WAITING_TO_START)
	(quest.autostart_condition_set.condition_list[0] as QuestTestCondition).fire()
	assert_eq(quest.get_state(), Quest.State.ACTIVE)
	assert_eq(quest.get_node("task").get_state(), QuestNode.State.ACTIVE)


func test_check_offer_conditions_message_recheck() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.offer_condition_set.condition_list.append(QuestTestCondition.new())
	var quest := journal.add_quest(asset)
	var condition := quest.offer_condition_set.condition_list[0] as QuestTestCondition
	var start_count := condition.start_count
	QuestMessages.send(self, null, QuestMessages.CHECK_OFFER_CONDITIONS, "q")
	assert_eq(quest.get_state(), Quest.State.DISABLED, "conditions not met, so the quest becomes unofferable")
	assert_gt(condition.start_count, start_count)


func assert_gt(a: int, b: int) -> void:
	assert_true(a > b, "%d > %d" % [a, b])


func test_cooldown() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.cooldown_seconds = 10.0
	asset.max_times = 3
	var quest := journal.add_quest(asset)
	var offered := [0]
	quest.offerable.connect(func(_q: Quest) -> void: offered[0] += 1)
	quest.start_cooldown()
	assert_almost_eq(quest.cooldown_seconds_remaining, 10.0)
	assert_false(quest.can_be_offered())
	QuestsTime.manual_time += 4.0
	quest.update_cooldown()
	assert_almost_eq(quest.cooldown_seconds_remaining, 6.0)
	assert_eq(offered[0], 0)
	QuestsTime.manual_time += 7.0
	quest.update_cooldown()
	assert_almost_eq(quest.cooldown_seconds_remaining, 0.0)
	assert_eq(offered[0], 1)
	assert_true(quest.can_be_offered())


func test_cooldown_without_duration_does_nothing() -> void:
	var quest := journal.add_quest(QuestTestHelpers.simple_quest("q"))
	quest.start_cooldown()
	assert_almost_eq(quest.cooldown_seconds_remaining, 0.0)


func test_manager_tick_updates_cooldowns() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.cooldown_seconds = 5.0
	asset.max_times = 2
	var quest := journal.add_quest(asset)
	quest.start_cooldown()
	QuestsTime.manual_time += 6.0
	QuestManager.instance.tick()
	assert_almost_eq(quest.cooldown_seconds_remaining, 0.0)


func test_max_times_and_repeats() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.max_times = 2
	var quest := journal.add_quest(asset)
	assert_true(quest.can_be_offered())
	quest.times_accepted = 1
	assert_true(quest.can_be_offered())
	quest.times_accepted = 2
	assert_false(quest.can_be_offered())
	assert_eq(quest.get_max_times(), 2)
	quest.infinitely_repeatable = true
	assert_true(quest.can_be_offered())
	quest.times_accepted = 5000
	assert_true(quest.can_be_offered())


func test_requires_quests() -> void:
	var prerequisite := journal.add_quest(QuestTestHelpers.simple_quest("first"))
	var second_asset := QuestTestHelpers.simple_quest("second")
	second_asset.requires_quests = PackedStringArray(["first"])
	var offered: Array[Quest] = []
	QuestManager.instance.quest_offerable.connect(func(q: Quest) -> void: offered.append(q))
	var second := journal.add_quest(second_asset)
	assert_false(second.are_requirements_met())
	assert_false(second.can_be_offered())
	assert_false(second.is_offerable)
	var offered_second := offered.filter(func(q: Quest) -> bool: return q.id == "second")
	assert_eq(offered_second.size(), 0, "not offerable while the prerequisite isn't done")
	prerequisite.set_state(Quest.State.ACTIVE)
	assert_false(second.can_be_offered(), "active isn't enough")
	QuestTestHelpers.test_condition(prerequisite, "task").fire()
	assert_eq(prerequisite.get_state(), Quest.State.SUCCESSFUL)
	assert_true(second.are_requirements_met())
	assert_true(second.can_be_offered())
	offered_second = offered.filter(func(q: Quest) -> bool: return q.id == "second")
	assert_eq(offered_second.size(), 1, "becomes offerable when the prerequisite succeeds")


func test_requires_quests_survives_deleting_completed_quest() -> void:
	journal.remember_completed_quests = false
	var prerequisite := journal.add_quest(QuestTestHelpers.simple_quest("first"))
	var second_asset := QuestTestHelpers.simple_quest("second")
	second_asset.requires_quests = PackedStringArray(["first"])
	var second := journal.add_quest(second_asset)
	prerequisite.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(prerequisite, "task").fire()
	assert_false(journal.contains_quest("first"), "deleted when complete")
	assert_true(Quests.was_completed("first"))
	assert_true(second.can_be_offered())


func test_time_limit_fails_the_quest() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.time_limit = 10.0
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	assert_almost_eq(quest.time_remaining, 10.0)
	QuestsTime.manual_time += 4.0
	QuestManager.instance.tick()
	assert_almost_eq(quest.time_remaining, 6.0)
	assert_eq(quest.get_state(), Quest.State.ACTIVE)
	QuestsTime.manual_time += 5.0
	QuestManager.instance.tick()
	assert_almost_eq(quest.time_remaining, 1.0)
	QuestsTime.manual_time += 2.0
	QuestManager.instance.tick()
	assert_eq(quest.get_state(), Quest.State.FAILED)
	assert_almost_eq(quest.time_remaining, 0.0)


func test_time_limit_stops_when_quest_completes() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.time_limit = 5.0
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task").fire()
	QuestsTime.manual_time += 60.0
	QuestManager.instance.tick()
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)


func test_no_time_limit_never_fails() -> void:
	var quest := journal.add_quest(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	QuestsTime.manual_time += 100000.0
	QuestManager.instance.tick()
	assert_eq(quest.get_state(), Quest.State.ACTIVE)


func test_time_limit_tag() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.time_limit = 125.0
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(QuestTags.replace_tags("Time left: {TIMELIMIT}", quest), "Time left: 02:05")


func test_infinite_and_zero_max() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.max_times = 0
	var quest := journal.add_quest(asset)
	assert_false(quest.can_be_offered())
