extends QuestsTest
## Runs the README's code samples so they stay correct.


func test_builder_sample_and_messages() -> void:
	make_manager()
	var journal := QuestTestHelpers.make_journal(self)
	await frames(1)

	var builder := QuestBuilder.new("Wolves", "wolves", "Wolf Problem")
	builder.add_counter("wolves", 0, 0, 5, false, QuestCounter.UpdateMode.MESSAGES)
	builder.add_counter_message_event("wolves", "", "Killed", "Wolf",
			QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE, 1)
	var hunt := builder.add_condition_node(builder.get_start_node(), "hunt", "Hunt wolves", QuestConditionSet.Mode.ALL)
	builder.add_counter_condition(hunt, "wolves", QuestCounterCondition.CounterValueMode.AT_LEAST,
			QuestNumber.literal(5))
	builder.add_success_node(hunt)
	var asset := builder.to_quest()
	var quest := Quests.give_quest(asset)
	track_quest(asset)
	assert_not_null(quest, "give_quest returns the instance")
	assert_true(journal.contains_quest("wolves"), "quest is in the player journal")
	assert_eq(quest.get_state(), Quest.State.ACTIVE, "giving a quest activates it")
	await frames(2)

	var states: Array = []
	Quests.get_manager().quest_state_changed.connect(func(_q: Quest, _old, new_state) -> void:
		states.append(new_state))
	for i in 5:
		Quests.send_message("Killed", "Wolf")
	await frames(2)
	assert_eq(Quests.counter("wolves", "wolves"), 5, "counter follows messages")
	assert_eq(Quests.get_quest_state("wolves"), Quest.State.SUCCESSFUL, "quest succeeds")
	assert_true(states.has(Quest.State.SUCCESSFUL), "manager signal reports success")

	var data := Quests.get_manager().record_data()
	assert_true(data.has("lists"), "record_data returns lists")
	Quests.get_manager().apply_data(data)
