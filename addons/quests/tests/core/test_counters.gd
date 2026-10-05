extends QuestsTest

var journal: QuestJournal


func before_each() -> void:
	make_manager()
	journal = QuestTestHelpers.make_journal(self)


func _active_quest(counter: QuestCounter) -> Quest:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.counter_list.append(counter)
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	return quest


func test_value_is_clamped() -> void:
	var counter := QuestCounter.create("c", 0, 0, 5)
	counter.set_value(9)
	assert_eq(counter.current_value, 5)
	counter.set_value(-3)
	assert_eq(counter.current_value, 0)
	counter.current_value = 3
	assert_eq(counter.current_value, 3)


func test_initial_value_applies_to_instances() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.counter_list.append(QuestCounter.create("c", 4, 0, 10))
	var quest := journal.add_quest(asset)
	assert_eq(quest.get_counter("c").current_value, 4)
	assert_eq(asset.get_counter("c").current_value, 4, "asset keeps its own value")
	quest.get_counter("c").set_value(7)
	assert_eq(asset.get_counter("c").current_value, 4)
	assert_eq(journal.add_quest(asset).get_counter("c").current_value, 4, "a new instance starts fresh")


func test_changed_signals_and_messages() -> void:
	var counter := QuestCounter.create("c", 0, 0, 10)
	var quest := _active_quest(counter)
	counter = quest.get_counter("c")
	var events: Array[String] = []
	counter.value_changed.connect(func(c: QuestCounter) -> void: events.append("counter %d" % c.current_value))
	quest.counter_changed.connect(func(_q: Quest, c: QuestCounter) -> void: events.append("quest " + c.name))
	QuestManager.instance.quest_counter_changed.connect(func(q: Quest, c: QuestCounter) -> void: events.append("manager %s %s" % [q.id, c.name]))
	var heard: Array[QuestMessageArgs] = []
	QuestMessages.add_listener(self, QuestMessages.QUEST_COUNTER_CHANGED, "q", func(a: QuestMessageArgs) -> void: heard.append(a))
	counter.set_value(3)
	assert_eq(events, ["counter 3", "quest c", "manager q c"])
	assert_eq(heard.size(), 1)
	assert_eq(heard[0].values, ["c", 3])
	counter.set_value(3)
	assert_eq(events.size(), 3, "no change, no signal")
	counter.set_value(4, QuestCounter.SetMode.DONT_INFORM_LISTENERS)
	assert_eq(events.size(), 3)
	assert_eq(counter.current_value, 4)


func test_set_and_increment_messages_both_forms() -> void:
	var quest := _active_quest(QuestCounter.create("c", 0, 0, 100))
	var counter := quest.get_counter("c")
	Quests.send_message(QuestMessages.SET_QUEST_COUNTER, "c", 10)
	assert_eq(counter.current_value, 10, "parameter = counter name, first value = number")
	Quests.send_message(QuestMessages.INCREMENT_QUEST_COUNTER, "c", 5)
	assert_eq(counter.current_value, 15)
	QuestMessages.set_quest_counter(null, "q", "c", 40)
	assert_eq(counter.current_value, 40, "parameter = quest id, values = name and number")
	QuestMessages.increment_quest_counter(null, "q", "c", 2)
	assert_eq(counter.current_value, 42)
	QuestMessages.set_quest_counter(null, "other_quest", "c", 1)
	QuestMessages.set_quest_counter(null, "q", "other_counter", 1)
	Quests.send_message(QuestMessages.SET_QUEST_COUNTER, "other_counter", 1)
	assert_eq(counter.current_value, 42, "messages for other counters are ignored")


func test_counters_listen_only_while_quest_is_active() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.counter_list.append(QuestCounter.create("c", 0, 0, 100))
	var quest := journal.add_quest(asset)
	Quests.send_message(QuestMessages.INCREMENT_QUEST_COUNTER, "c", 1)
	assert_eq(quest.get_counter("c").current_value, 0, "waiting to start")
	quest.set_state(Quest.State.ACTIVE)
	Quests.send_message(QuestMessages.INCREMENT_QUEST_COUNTER, "c", 1)
	assert_eq(quest.get_counter("c").current_value, 1)
	quest.set_state(Quest.State.FAILED)
	Quests.send_message(QuestMessages.INCREMENT_QUEST_COUNTER, "c", 1)
	assert_eq(quest.get_counter("c").current_value, 1, "failed")


func _event_counter(event: QuestCounterMessageEvent) -> QuestCounter:
	var counter := QuestCounter.create("c", 0, 0, 100)
	counter.message_event_list.append(event)
	return counter


func test_event_modify_by_literal_value() -> void:
	var quest := _active_quest(_event_counter(QuestCounterMessageEvent.create("Wolf Killed", "", QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE, 2)))
	Quests.send_message("Wolf Killed", "any parameter")
	Quests.send_message("Wolf Killed")
	Quests.send_message("Bear Killed")
	assert_eq(quest.get_counter("c").current_value, 4)


func test_event_parameter_filter() -> void:
	var quest := _active_quest(_event_counter(QuestCounterMessageEvent.create("Killed", "Wolf")))
	Quests.send_message("Killed", "Bear")
	assert_eq(quest.get_counter("c").current_value, 0)
	Quests.send_message("Killed", "Wolf")
	assert_eq(quest.get_counter("c").current_value, 1)


func test_event_message_value_operations() -> void:
	var quest := _active_quest(_event_counter(QuestCounterMessageEvent.create("Loot", "", QuestCounterMessageEvent.Operation.MODIFY_BY_MESSAGE_VALUE)))
	Quests.send_message("Loot", "", 5)
	Quests.send_message("Loot", "", 3)
	assert_eq(quest.get_counter("c").current_value, 8)
	var set_quest := _active_quest(_event_counter(QuestCounterMessageEvent.create("Level", "", QuestCounterMessageEvent.Operation.SET_TO_MESSAGE_VALUE)))
	Quests.send_message("Level", "", 7)
	assert_eq(set_quest.get_counter("c").current_value, 7)


func test_event_set_to_literal_value() -> void:
	var quest := _active_quest(_event_counter(QuestCounterMessageEvent.create("Reset", "", QuestCounterMessageEvent.Operation.SET_TO_LITERAL_VALUE, 5)))
	quest.get_counter("c").set_value(50)
	Quests.send_message("Reset")
	assert_eq(quest.get_counter("c").current_value, 5)


func test_event_sender_and_target_filters() -> void:
	var event := QuestCounterMessageEvent.create("Delivered", "")
	event.sender_specifier = QuestMessages.Participant.OTHER
	event.sender_id = "courier"
	event.target_specifier = QuestMessages.Participant.OTHER
	event.target_id = "shopkeeper"
	var quest := _active_quest(_event_counter(event))
	Quests.send_message("Delivered", "", null, "someone", "shopkeeper")
	Quests.send_message("Delivered", "", null, "courier", "someone")
	Quests.send_message("Delivered", "", null, "courier")
	assert_eq(quest.get_counter("c").current_value, 0)
	Quests.send_message("Delivered", "", null, "courier", "shopkeeper")
	assert_eq(quest.get_counter("c").current_value, 1)


func test_event_quester_specifier_uses_quest_tags() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	var event := QuestCounterMessageEvent.create("Killed", "")
	event.sender_specifier = QuestMessages.Participant.QUESTER
	var counter := QuestCounter.create("c", 0, 0, 100)
	counter.message_event_list.append(event)
	asset.counter_list.append(counter)
	var quest := journal.add_quest(asset)
	quest.assign_quester(QuestParticipant.new("player", "Hero"))
	quest.set_state(Quest.State.ACTIVE)
	Quests.send_message("Killed", "", null, "npc")
	assert_eq(quest.get_counter("c").current_value, 0)
	Quests.send_message("Killed", "", null, "player")
	assert_eq(quest.get_counter("c").current_value, 1)


func test_event_message_text_uses_tags() -> void:
	var event := QuestCounterMessageEvent.create("Killed {QUESTID}", "")
	var quest := _active_quest(_event_counter(event))
	Quests.send_message("Killed q")
	assert_eq(quest.get_counter("c").current_value, 1)


func test_data_sync_mode() -> void:
	var counter := QuestCounter.create("gold", 0, 0, 1000, QuestCounter.UpdateMode.DATA_SYNC)
	var quest := _active_quest(counter)
	counter = quest.get_counter("gold")
	var requests: Array[QuestMessageArgs] = []
	QuestMessages.add_listener(self, QuestMessages.REQUEST_DATA_SOURCE_CHANGE_VALUE, "gold", func(a: QuestMessageArgs) -> void: requests.append(a))
	Quests.send_message(QuestMessages.DATA_SOURCE_VALUE_CHANGED, "gold", 250)
	assert_eq(counter.current_value, 250)
	assert_eq(requests.size(), 0, "a value that came from the data source isn't sent back")
	counter.set_value(100)
	assert_eq(requests.size(), 1)
	assert_eq(requests[0].values, [100])
	Quests.send_message(QuestMessages.SET_QUEST_COUNTER, "gold", 5)
	assert_eq(counter.current_value, 100, "data sync counters ignore the set message")


func test_random_initial_value() -> void:
	var counter := QuestCounter.create("c", 0, 3, 5)
	counter.randomize_initial_value = true
	var asset := QuestTestHelpers.simple_quest("q")
	asset.counter_list.append(counter)
	for i in 10:
		var quest := journal.add_quest(asset)
		var value := quest.get_counter("c").current_value
		assert_true(value >= 3 and value <= 5, "random value %d in range" % value)
		journal.delete_quest(quest)
		journal.deleted_static_quests.clear()


func test_objectives() -> void:
	var counter := QuestCounter.create("wolves", 0, 0, 10)
	counter.display_name = "Wolves slain"
	counter.objective_goal = QuestNumber.literal(5)
	var hidden := QuestCounter.create("internal", 2, 0, 10)
	var quest := _active_quest(counter)
	quest.counter_list.append(hidden)
	quest.get_counter("wolves").set_value(2)
	var objectives := quest.get_objectives()
	assert_eq(objectives.size(), 1)
	assert_eq(objectives[0].text, "Wolves slain 2/5")
	assert_eq(objectives[0].current, 2)
	assert_eq(objectives[0].goal, 5)
	assert_false(objectives[0].done)
	assert_eq(objectives[0].counter_name, "wolves")
	quest.get_counter("wolves").set_value(5)
	assert_true(quest.get_objectives()[0].done)
	quest.auto_objectives = false
	assert_eq(quest.get_objectives().size(), 0)


func test_objective_goal_defaults_to_max_and_can_use_counters() -> void:
	var counter := QuestCounter.create("a", 0, 0, 8)
	counter.display_name = "Apples"
	var quest := _active_quest(counter)
	assert_eq(quest.get_objectives()[0].goal, 8)
	var other := QuestCounter.create("target", 6, 0, 10)
	quest.counter_list.append(other)
	quest.get_counter("a").objective_goal = QuestNumber.from_counter("target")
	assert_eq(quest.get_objectives()[0].goal, 6)


func test_quest_number() -> void:
	var quest := _active_quest(QuestCounter.create("c", 3, 1, 9))
	assert_eq(QuestNumber.literal(4).get_value(quest), 4)
	assert_eq(QuestNumber.from_counter("c").get_value(quest), 3)
	assert_eq(QuestNumber.from_counter("c", QuestNumber.ValueType.COUNTER_MIN_VALUE).get_value(quest), 1)
	assert_eq(QuestNumber.from_counter("c", QuestNumber.ValueType.COUNTER_MAX_VALUE).get_value(quest), 9)
	assert_eq(QuestNumber.from_counter("c").get_editor_name(quest), "c")
	assert_eq(QuestNumber.from_counter("c", QuestNumber.ValueType.COUNTER_MAX_VALUE).get_editor_name(quest), "c Max Value")
	assert_eq(QuestNumber.literal(4).get_editor_name(quest), "4")


func test_message_value() -> void:
	assert_true(QuestMessageValue.new().matches(null))
	assert_true(QuestMessageValue.new().matches("anything"))
	var int_value := QuestMessageValue.from_int(3)
	assert_true(int_value.matches(3))
	assert_false(int_value.matches(4))
	assert_false(int_value.matches(null))
	assert_false(int_value.matches("3"))
	assert_eq(int_value.get_value(), 3)
	var string_value := QuestMessageValue.from_string("hi")
	assert_true(string_value.matches("hi"))
	assert_false(string_value.matches("no"))
	assert_eq(string_value.get_value(), "hi")
	assert_null(QuestMessageValue.new().get_value())
	assert_eq(int_value.get_editor_name(), "3")
