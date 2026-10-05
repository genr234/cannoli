extends QuestsTest

var _journal: QuestJournal


func before_each() -> void:
	make_manager()
	_journal = PartsTestUtil.make_journal(self)


func _expression(text: String, interval := 0.0, on_messages := true) -> QuestExpressionCondition:
	var condition := QuestExpressionCondition.new()
	condition.expression = text
	condition.check_interval = interval
	condition.check_on_messages = on_messages
	return condition


func test_true_expression_fires_immediately() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var condition := _expression("1 + 1 == 2")
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 1)
	assert_eq(condition.get_editor_name(), "Expression: 1 + 1 == 2")


func test_reacts_to_counter_through_messages() -> void:
	var quest := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("q", ["wolves"]))
	var condition := _expression("counter(\"\", \"wolves\") >= 2")
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 0)
	quest.get_counter("wolves").set_value(1)
	assert_eq(hits.count, 0)
	quest.get_counter("wolves").set_value(2)
	assert_eq(hits.count, 1)


func test_context_helpers() -> void:
	var other := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("other", ["n"]))
	var quest := PartsTestUtil.make_quest("q")
	var condition := _expression("is_state(\"other\", \"active\") and counter(\"other\", \"n\") == 0 and quest_id() == \"q\"")
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 0)
	other.set_state(Quest.State.ACTIVE)
	assert_eq(hits.count, 1)


func test_polling() -> void:
	var quest := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("q", ["a"]))
	var condition := _expression("counter(\"q\", \"a\") > 0", 0.05, false)
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	quest.get_counter("a").set_value(1)
	assert_eq(hits.count, 0, "not checked on messages")
	await root.get_tree().create_timer(0.3).timeout
	assert_eq(hits.count, 1)


func test_stop_checking_stops_polling() -> void:
	var quest := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("q", ["a"]))
	var condition := _expression("counter(\"q\", \"a\") > 0", 0.05)
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	condition.stop_checking()
	quest.get_counter("a").set_value(1)
	await root.get_tree().create_timer(0.2).timeout
	assert_eq(hits.count, 0)


func test_invalid_expression_never_fires() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var condition := _expression("1 +* )")
	condition.set_runtime_references(quest, null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 0)
	assert_false(condition.evaluate())
	assert_eq(_expression("").get_editor_name(), "Expression")


func test_failing_expression_is_false() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var condition := _expression("no_such_method()")
	condition.set_runtime_references(quest, null)
	assert_false(condition.evaluate())
