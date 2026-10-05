extends QuestsTest

var _journal: QuestJournal


func before_each() -> void:
	make_manager()
	_journal = PartsTestUtil.make_journal(self)


func _counter_condition(counter_name: String, mode: QuestCounterCondition.CounterValueMode, value: int) -> QuestCounterCondition:
	var condition := QuestCounterCondition.new()
	condition.counter_name = counter_name
	condition.counter_value_mode = mode
	condition.required_counter_value = QuestNumber.literal(value)
	return condition


func test_counter_condition_at_least() -> void:
	var quest := PartsTestUtil.make_quest("q", ["wolves"])
	quest.initialize()
	var condition := _counter_condition("wolves", QuestCounterCondition.CounterValueMode.AT_LEAST, 3)
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_true(condition.is_checking)
	var counter := quest.get_counter("wolves")
	counter.set_value(2)
	assert_eq(hits.count, 0)
	counter.set_value(3)
	assert_eq(hits.count, 1)
	assert_true(condition.already_true)
	assert_false(condition.is_checking, "stops checking when true")
	counter.set_value(5)
	assert_eq(hits.count, 1, "true only once")
	assert_eq(condition.get_editor_name(), "Counter: wolves >= 3")


func test_counter_condition_at_most_and_already_met() -> void:
	var quest := PartsTestUtil.make_quest("q", ["fuel"])
	quest.initialize()
	var condition := _counter_condition("fuel", QuestCounterCondition.CounterValueMode.AT_MOST, 0)
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 1, "0 <= 0 is true immediately")
	assert_eq(condition.get_editor_name(), "Counter: fuel <= 0")


func test_counter_condition_stop_checking() -> void:
	var quest := PartsTestUtil.make_quest("q", ["a"])
	quest.initialize()
	var condition := _counter_condition("a", QuestCounterCondition.CounterValueMode.AT_LEAST, 1)
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	condition.stop_checking()
	quest.get_counter("a").set_value(4)
	assert_eq(hits.count, 0)


func test_message_condition() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var condition := QuestMessageCondition.new()
	condition.message = "Door Opened"
	condition.parameter = "cellar"
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	QuestMessages.send(null, null, "Door Opened", "cellar")
	assert_eq(hits.count, 0, "doesn't hear messages sent in the frame it started")
	await frames(2)
	QuestMessages.send(null, null, "Door Opened", "attic")
	assert_eq(hits.count, 0, "wrong parameter")
	QuestMessages.send(null, null, "Other", "cellar")
	assert_eq(hits.count, 0, "wrong message")
	QuestMessages.send(null, null, "Door Opened", "cellar")
	assert_eq(hits.count, 1)
	QuestMessages.send(null, null, "Door Opened", "cellar")
	assert_eq(hits.count, 1, "true once")
	assert_eq(condition.get_editor_name(), "Message: Door Opened cellar")


func test_message_condition_value_and_ids() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var condition := QuestMessageCondition.new()
	condition.message = "Talked"
	condition.sender_specifier = QuestMessages.Participant.OTHER
	condition.sender_id = "npc_a"
	condition.value = QuestMessageValue.from_int(7)
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	await frames(2)
	QuestMessages.send("npc_b", null, "Talked", "", [7])
	assert_eq(hits.count, 0, "wrong sender")
	QuestMessages.send("npc_a", null, "Talked", "", [6])
	assert_eq(hits.count, 0, "wrong value")
	QuestMessages.send("npc_a", null, "Talked", "")
	assert_eq(hits.count, 0, "no value")
	QuestMessages.send("npc_a", null, "Talked", "", [7])
	assert_eq(hits.count, 1)


func test_message_condition_stop_before_listening() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var condition := QuestMessageCondition.new()
	condition.message = "Ping"
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	condition.stop_checking()
	await frames(2)
	QuestMessages.send(null, null, "Ping")
	assert_eq(hits.count, 0)


func test_timer_condition() -> void:
	var quest := PartsTestUtil.make_quest("q", ["time"])
	quest.initialize()
	quest.get_counter("time").set_value(3)
	var condition := QuestTimerCondition.new()
	condition.counter_name = "time"
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	Quests.tick_timers()
	Quests.tick_timers()
	assert_eq(hits.count, 0)
	assert_eq(quest.get_counter("time").current_value, 1)
	Quests.tick_timers()
	assert_eq(hits.count, 1)
	Quests.tick_timers()
	assert_eq(hits.count, 1, "unregistered after true")
	assert_eq(condition.get_editor_name(), "Timer: time")


func test_quest_state_condition() -> void:
	var other := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("other"))
	var quest := PartsTestUtil.make_quest("q")
	var condition := QuestStateCondition.new()
	condition.required_quest_id = "other"
	condition.required_state = Quest.State.ACTIVE
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 0)
	other.set_state(Quest.State.ACTIVE)
	assert_eq(hits.count, 1)
	assert_eq(condition.get_editor_name(), "Quest State: other == Active")


func test_quest_state_condition_is_not_and_immediate() -> void:
	PartsTestUtil.give(_journal, PartsTestUtil.make_quest("other"))
	var quest := PartsTestUtil.make_quest("q")
	var condition := QuestStateCondition.new()
	condition.required_quest_id = "other"
	condition.is_not = true
	condition.required_state = Quest.State.ACTIVE
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 1, "waiting_to_start != active")
	assert_eq(condition.get_editor_name(), "Quest State: other != Active")


func test_quest_node_state_condition() -> void:
	var asset := PartsTestUtil.make_quest("other")
	var step := QuestNode.create("step", "Step", QuestNode.Type.PASSTHROUGH)
	asset.node_list.append(step)
	var other := PartsTestUtil.give(_journal, asset)
	var quest := PartsTestUtil.make_quest("q")
	var condition := QuestNodeStateCondition.new()
	condition.required_quest_id = "other"
	condition.required_node_id = "step"
	condition.required_state = QuestNode.State.ACTIVE
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 0)
	other.get_node("step").set_state(QuestNode.State.ACTIVE)
	assert_eq(hits.count, 1)
	assert_eq(condition.get_editor_name(), "Quest Node State: Quest 'other' Node 'step' == Active")


func test_parent_condition() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var a := QuestNode.create("a", "A", QuestNode.Type.PASSTHROUGH)
	var b := QuestNode.create("b", "B", QuestNode.Type.PASSTHROUGH, true)
	var child := QuestNode.create("c", "C", QuestNode.Type.PASSTHROUGH)
	child.parent_list = [a, b]
	child.nonoptional_parent_list = [a]
	child.optional_parent_list = [b]
	var all := QuestParentCondition.new()
	all.parent_count_mode = QuestConditionSet.Mode.ALL
	all.set_runtime_references(quest, child)
	var any := QuestParentCondition.new()
	any.parent_count_mode = QuestConditionSet.Mode.ANY
	any.set_runtime_references(quest, child)
	var minimum := QuestParentCondition.new()
	minimum.parent_count_mode = QuestConditionSet.Mode.MIN
	minimum.min_parent_count = 2
	minimum.set_runtime_references(quest, child)
	var all_hits := PartsTestUtil.Counter.new()
	var any_hits := PartsTestUtil.Counter.new()
	var min_hits := PartsTestUtil.Counter.new()
	all.start_checking(all_hits.hit)
	any.start_checking(any_hits.hit)
	minimum.start_checking(min_hits.hit)
	b.set_state_raw(QuestNode.State.TRUE)
	b.state_changed.emit(b)
	assert_eq(any_hits.count, 1, "any: optional parent counts")
	assert_eq(all_hits.count, 0, "all: only non-optional parents count")
	assert_eq(min_hits.count, 0)
	a.set_state_raw(QuestNode.State.TRUE)
	a.state_changed.emit(a)
	assert_eq(all_hits.count, 1)
	assert_eq(min_hits.count, 1)
	assert_eq(all.get_editor_name(), "Parents: All True")
	assert_eq(any.get_editor_name(), "Parents: Any True")
	assert_eq(minimum.get_editor_name(), "Parents: At Least 2 True")


func test_condition_reset_state() -> void:
	var quest := PartsTestUtil.make_quest("q", ["a"])
	quest.initialize()
	var condition := _counter_condition("a", QuestCounterCondition.CounterValueMode.AT_LEAST, 1)
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	quest.get_counter("a").set_value(1)
	assert_eq(hits.count, 1)
	condition.reset_condition()
	assert_false(condition.already_true)
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 2, "can fire again after reset")
