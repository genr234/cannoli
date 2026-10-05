extends QuestsTest

var journal: QuestJournal


func before_each() -> void:
	make_manager()
	journal = QuestTestHelpers.make_journal(self)


## start -> a, b (, c) -> join (condition node). Returns the instance, active.
func _join_quest(mode: QuestNode.JoinMode, min_count := 1, optional_ids: Array[String] = [], parents: Array[String] = ["a", "b"]) -> Quest:
	var asset := QuestTestHelpers.parallel_quest("q", parents)
	for parent_id in parents:
		asset.get_node(parent_id).children = PackedStringArray(["join"])
		asset.get_node(parent_id).is_optional = optional_ids.has(parent_id)
	var join := QuestTestHelpers.condition_node("join")
	join.join_mode = mode
	join.join_min_count = min_count
	asset.node_list.append(join)
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	return quest


func _fire(quest: Quest, node_id: String) -> void:
	QuestTestHelpers.test_condition(quest, node_id).fire()


func _join_state(quest: Quest) -> QuestNode.State:
	return quest.get_node("join").get_state()


func test_join_any_activates_on_first_parent() -> void:
	var quest := _join_quest(QuestNode.JoinMode.ANY)
	assert_eq(_join_state(quest), QuestNode.State.INACTIVE)
	_fire(quest, "a")
	assert_eq(_join_state(quest), QuestNode.State.ACTIVE)
	_fire(quest, "b")
	assert_eq(_join_state(quest), QuestNode.State.ACTIVE, "doesn't restart")


func test_join_all_waits_for_every_parent() -> void:
	var quest := _join_quest(QuestNode.JoinMode.ALL)
	_fire(quest, "a")
	assert_eq(_join_state(quest), QuestNode.State.INACTIVE)
	_fire(quest, "b")
	assert_eq(_join_state(quest), QuestNode.State.ACTIVE)


func test_join_all_ignores_optional_parents() -> void:
	var quest := _join_quest(QuestNode.JoinMode.ALL, 1, ["b"])
	_fire(quest, "a")
	assert_eq(_join_state(quest), QuestNode.State.ACTIVE, "b is optional")


func test_join_all_with_only_optional_unmet_parent_still_needs_none() -> void:
	var quest := _join_quest(QuestNode.JoinMode.ALL, 1, ["a", "b"])
	_fire(quest, "b")
	assert_eq(_join_state(quest), QuestNode.State.ACTIVE, "no non-optional parents, so any true parent opens it")


func test_join_min_counts_all_true_parents() -> void:
	var quest := _join_quest(QuestNode.JoinMode.MIN, 2, [], ["a", "b", "c"])
	_fire(quest, "a")
	assert_eq(_join_state(quest), QuestNode.State.INACTIVE)
	_fire(quest, "c")
	assert_eq(_join_state(quest), QuestNode.State.ACTIVE)


func test_join_min_counts_optional_parents() -> void:
	var quest := _join_quest(QuestNode.JoinMode.MIN, 2, ["b"], ["a", "b"])
	_fire(quest, "b")
	assert_eq(_join_state(quest), QuestNode.State.INACTIVE)
	_fire(quest, "a")
	assert_eq(_join_state(quest), QuestNode.State.ACTIVE)


func test_join_conditions_checked_when_restoring() -> void:
	var quest := _join_quest(QuestNode.JoinMode.ALL)
	assert_false(quest.get_node("join").are_join_conditions_met())
	quest.get_node("a").set_state_raw(QuestNode.State.TRUE)
	assert_false(quest.get_node("join").are_join_conditions_met())
	quest.get_node("b").set_state_raw(QuestNode.State.TRUE)
	assert_true(quest.get_node("join").are_join_conditions_met())


func test_journal_load_respects_join_mode() -> void:
	var quest := _join_quest(QuestNode.JoinMode.ALL)
	quest.get_node("a").set_state_raw(QuestNode.State.TRUE)
	journal._verify_true_node_children_are_active()
	assert_eq(_join_state(quest), QuestNode.State.INACTIVE)
	quest.get_node("b").set_state_raw(QuestNode.State.TRUE)
	journal._verify_true_node_children_are_active()
	assert_eq(_join_state(quest), QuestNode.State.ACTIVE)


# Condition sets

func _make_set(count: int, mode: QuestConditionSet.Mode, min_count := 1) -> QuestConditionSet:
	var condition_set := QuestConditionSet.new()
	condition_set.condition_count_mode = mode
	condition_set.min_condition_count = min_count
	for i in count:
		condition_set.condition_list.append(QuestTestCondition.new())
	return condition_set


func _fire_at(condition_set: QuestConditionSet, index: int) -> void:
	(condition_set.condition_list[index] as QuestTestCondition).fire()


func test_set_any() -> void:
	var condition_set := _make_set(3, QuestConditionSet.Mode.ANY)
	var hits := [0]
	condition_set.start_checking(func() -> void: hits[0] += 1)
	assert_false(condition_set.are_conditions_met)
	_fire_at(condition_set, 1)
	assert_eq(hits[0], 1)
	assert_true(condition_set.are_conditions_met)


func test_set_all() -> void:
	var condition_set := _make_set(3, QuestConditionSet.Mode.ALL)
	var hits := [0]
	condition_set.start_checking(func() -> void: hits[0] += 1)
	_fire_at(condition_set, 0)
	_fire_at(condition_set, 2)
	assert_eq(hits[0], 0)
	_fire_at(condition_set, 1)
	assert_eq(hits[0], 1)
	assert_eq(condition_set.num_true_conditions, 3)


func test_set_min() -> void:
	var condition_set := _make_set(4, QuestConditionSet.Mode.MIN, 2)
	var hits := [0]
	condition_set.start_checking(func() -> void: hits[0] += 1)
	_fire_at(condition_set, 3)
	assert_eq(hits[0], 0)
	_fire_at(condition_set, 0)
	assert_eq(hits[0], 1)


func test_empty_set_is_met_and_never_fires() -> void:
	var condition_set := QuestConditionSet.new()
	var hits := [0]
	condition_set.start_checking(func() -> void: hits[0] += 1)
	assert_true(condition_set.are_conditions_met)
	assert_true(condition_set.is_empty)
	assert_eq(QuestConditionSet.condition_count(condition_set), 0)
	assert_eq(QuestConditionSet.condition_count(null), 0)
	assert_eq(hits[0], 0)


func test_set_skips_conditions_that_are_already_true() -> void:
	var condition_set := _make_set(2, QuestConditionSet.Mode.ALL)
	var first := condition_set.condition_list[0] as QuestTestCondition
	first.already_true = true
	condition_set.num_true_conditions = 1
	var hits := [0]
	condition_set.start_checking(func() -> void: hits[0] += 1)
	assert_eq(first.start_count, 0)
	_fire_at(condition_set, 1)
	assert_eq(hits[0], 1)


func test_set_stop_and_reset() -> void:
	var condition_set := _make_set(2, QuestConditionSet.Mode.ALL)
	var hits := [0]
	condition_set.start_checking(func() -> void: hits[0] += 1)
	_fire_at(condition_set, 0)
	condition_set.stop_checking()
	for condition in condition_set.condition_list:
		assert_false(condition.is_checking)
	condition_set.reset_conditions()
	assert_eq(condition_set.num_true_conditions, 0)
	assert_false(condition_set.condition_list[0].already_true)
	condition_set.start_checking(func() -> void: hits[0] += 1)
	_fire_at(condition_set, 0)
	_fire_at(condition_set, 1)
	assert_eq(hits[0], 1)


func test_set_ignores_second_start() -> void:
	var condition_set := _make_set(1, QuestConditionSet.Mode.ALL)
	condition_set.start_checking(func() -> void: pass)
	condition_set.start_checking(func() -> void: pass)
	assert_eq((condition_set.condition_list[0] as QuestTestCondition).start_count, 1)


func test_condition_node_all_mode_in_quest() -> void:
	var asset := QuestTestHelpers.chain("q", [QuestTestHelpers.condition_node("task", 2, QuestConditionSet.Mode.ALL),
			QuestTestHelpers.node("done", QuestNode.Type.SUCCESS)])
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task", 0).fire()
	assert_eq(quest.get_state(), Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task", 1).fire()
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)


func test_condition_node_any_mode_in_quest() -> void:
	var asset := QuestTestHelpers.chain("q", [QuestTestHelpers.condition_node("task", 2, QuestConditionSet.Mode.ANY),
			QuestTestHelpers.node("done", QuestNode.Type.SUCCESS)])
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task", 1).fire()
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)
