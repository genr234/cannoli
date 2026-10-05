extends QuestsTest


func _database() -> QuestDatabase:
	var database := QuestDatabase.new()
	var asset := QuestTestHelpers.chain("q1", [QuestTestHelpers.condition_node("task"), QuestTestHelpers.node("done", QuestNode.Type.SUCCESS)])
	asset.counter_list.append(QuestCounter.create("c", 0, 0, 50))
	database.add_quest(asset)
	database.add_quest(QuestTestHelpers.simple_quest("q2"))
	return database


func _manager_with_database() -> QuestManager:
	var manager := QuestManager.new()
	manager.use_save_addon = false
	manager.quest_databases = [_database()] as Array[QuestDatabase]
	return add_node(manager) as QuestManager


func _journal() -> QuestJournal:
	var journal := QuestJournal.new()
	journal.id = "player"
	journal.save_key = "journal"
	return add_node(journal) as QuestJournal


func test_manager_registers_database_quests() -> void:
	_manager_with_database()
	assert_not_null(Quests.get_quest_asset("q1"))
	assert_not_null(Quests.get_quest_asset("q2"))
	assert_null(Quests.get_quest_asset("q3"))
	assert_eq(QuestManager.instance.get_class(), "Node")
	assert_eq(Quests.get_manager(), QuestManager.instance)


func test_database_api() -> void:
	var database := _database()
	assert_eq(database.get_quest_asset("q1").id, "q1")
	assert_null(database.get_quest_asset("zzz"))
	var replacement := Quest.create("q1", "New")
	database.add_quest(replacement)
	assert_eq(database.quest_assets.size(), 2)
	assert_eq(database.get_quest_asset("q1").title, "New")
	database.remove_quest("q2")
	assert_eq(database.quest_assets.size(), 1)


func test_only_one_manager() -> void:
	var first := make_manager()
	var second := QuestManager.new()
	second.use_save_addon = false
	add_node(second)
	await frames(2)
	assert_eq(QuestManager.instance, first)
	assert_false(is_instance_valid(second), "the second manager frees itself")


func test_give_quest_by_id_and_asset() -> void:
	_manager_with_database()
	var journal := _journal()
	var quest := Quests.give_quest("q1")
	assert_not_null(quest)
	assert_true(quest.is_instance)
	assert_eq(quest.get_state(), Quest.State.ACTIVE)
	assert_eq(quest.quester_id, "player")
	assert_eq(quest.times_accepted, 1)
	assert_eq(journal.find_quest("q1"), quest)
	assert_eq(Quests.get_quest_instance("q1"), quest)
	assert_eq(Quests.get_quest_instance("q1", "player"), quest)
	var other := Quests.give_quest(Quests.get_quest_asset("q2"))
	assert_eq(other.id, "q2")
	assert_null(Quests.give_quest("missing"))
	assert_eq(Quests.give_quest_to_quester("missing", journal), null)


func test_give_quest_to_named_quester() -> void:
	_manager_with_database()
	_journal()
	var second := QuestJournal.new()
	second.id = "ally"
	add_node(second)
	var quest := Quests.give_quest_to_quester("q1", "ally")
	assert_eq(second.find_quest("q1"), quest)
	assert_eq(quest.quester_id, "ally")
	assert_eq(Quests.get_quest_instance("q1", "ally"), quest)


func test_state_helpers() -> void:
	_manager_with_database()
	_journal()
	assert_eq(Quests.get_quest_state("q1"), Quest.State.WAITING_TO_START, "no instance counts as waiting to start")
	Quests.give_quest("q1")
	assert_eq(Quests.get_quest_state("q1"), Quest.State.ACTIVE)
	assert_eq(Quests.get_quest_node_state("q1", "task"), QuestNode.State.ACTIVE)
	assert_eq(Quests.get_quest_node_state("q1", "nope"), QuestNode.State.INACTIVE)
	assert_eq(Quests.get_quest_node_state("nothing", "task"), QuestNode.State.INACTIVE)
	Quests.set_quest_node_state("q1", "task", QuestNode.State.TRUE)
	assert_eq(Quests.get_quest_state("q1"), Quest.State.SUCCESSFUL)
	Quests.set_quest_state("q1", Quest.State.FAILED)
	assert_eq(Quests.get_quest_state("q1"), Quest.State.FAILED)
	Quests.set_quest_state("nothing", Quest.State.FAILED)


func test_expression_helpers() -> void:
	_manager_with_database()
	_journal()
	assert_false(Quests.is_state("q1", "active"))
	assert_true(Quests.is_state("q1", "waiting to start"), "not given yet")
	Quests.give_quest("q1")
	assert_true(Quests.is_state("q1", "active"))
	assert_true(Quests.is_state("q1", "Active"))
	assert_false(Quests.is_state("q1", "successful"))
	assert_false(Quests.is_state("q1", "not a state"))
	assert_eq(Quests.counter("q1", "c"), 0)
	Quests.send_message(QuestMessages.INCREMENT_QUEST_COUNTER, "c", 6)
	assert_eq(Quests.counter("q1", "c"), 6)
	assert_eq(Quests.counter("q1", "missing"), 0)
	assert_eq(Quests.counter("missing", "c"), 0)
	assert_eq(Quests.get_quest_counter("q1", "c").current_value, 6)
	assert_eq(Quests.state_from_name("waiting_to_start"), Quest.State.WAITING_TO_START)
	assert_eq(Quests.state_from_name("SUCCESS"), Quest.State.SUCCESSFUL)
	assert_eq(Quests.state_from_name(3), Quest.State.FAILED)
	assert_eq(Quests.state_from_name(99), -1)
	assert_eq(Quests.node_state_from_name("true"), QuestNode.State.TRUE)
	assert_eq(Quests.node_state_from_name("bogus"), -1)


func test_record_and_apply_data_round_trip() -> void:
	_manager_with_database()
	_journal()
	await frames(2)
	var quest := Quests.give_quest("q1")
	quest.get_counter("c").set_value(12)
	Quests.give_quest("q2")
	Quests.set_quest_state("q2", Quest.State.FAILED)
	var data := QuestManager.instance.record_data()
	_assert_json_safe(data)
	data = JSON.parse_string(JSON.stringify(data))
	assert_eq(data.version, 1)
	assert_true(data.lists.has("journal"))
	assert_eq(data.lists.journal.id, "player")
	assert_eq(data.lists.journal.quests.size(), 2)
	assert_true(data.has("generator"))
	# A new session: fresh nodes, same quests.
	free_tracked_nodes()
	Quests.reset_static_state()
	_manager_with_database()
	var journal_2 := _journal()
	await frames(2)
	assert_eq(journal_2.quest_list.size(), 0)
	QuestManager.instance.apply_data(data)
	await frames(3)
	var restored := journal_2.find_quest("q1")
	assert_not_null(restored)
	assert_eq(restored.get_state(), Quest.State.ACTIVE)
	assert_eq(restored.get_counter("c").current_value, 12)
	assert_eq(restored.get_node("task").get_state(), QuestNode.State.ACTIVE)
	assert_eq(journal_2.find_quest("q2").get_state(), Quest.State.FAILED)
	assert_false(Quests.is_loading_game)
	# And it still plays.
	QuestTestHelpers.test_condition(restored, "task")
	restored.get_node("task").set_state(QuestNode.State.TRUE)
	assert_eq(restored.get_state(), Quest.State.SUCCESSFUL)


func _assert_json_safe(value: Variant) -> void:
	match typeof(value):
		TYPE_ARRAY:
			for item in value:
				_assert_json_safe(item)
		TYPE_DICTIONARY:
			for key in value:
				_assert_json_safe(value[key])
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			assert_true(false, "data holds an object")


func test_apply_data_restores_deleted_quests_and_generated_quests() -> void:
	_manager_with_database()
	var journal := _journal()
	var generated := QuestTestHelpers.simple_quest("generated")
	generated.is_procedurally_generated = true
	generated.title = "Made Up"
	journal.add_quest(generated)
	Quests.give_quest("q1")
	journal.delete_quest("q1")
	assert_true(journal.deleted_static_quests.has("q1"))
	var data := JSON.parse_string(JSON.stringify(QuestManager.instance.record_data()))
	free_tracked_nodes()
	Quests.reset_static_state()
	_manager_with_database()
	var journal_2 := _journal()
	await frames(2)
	QuestManager.instance.apply_data(data)
	await frames(3)
	assert_null(journal_2.find_quest("q1"))
	assert_true(journal_2.deleted_static_quests.has("q1"))
	var restored := journal_2.find_quest("generated")
	assert_not_null(restored)
	assert_eq(restored.title, "Made Up")
	assert_true(restored.is_procedurally_generated)
	assert_false(journal_2.deleted_static_quests.has("generated"))


func test_pending_data_applies_when_the_list_registers_later() -> void:
	_manager_with_database()
	_journal()
	Quests.give_quest("q1")
	var data := JSON.parse_string(JSON.stringify(QuestManager.instance.record_data()))
	free_tracked_nodes()
	Quests.reset_static_state()
	var manager := _manager_with_database()
	manager.apply_data(data)
	var late := _journal()
	await frames(3)
	assert_eq(late.find_quest("q1").get_state(), Quest.State.ACTIVE)


func test_lists_with_saving_off_are_skipped() -> void:
	var manager := _manager_with_database()
	var journal := _journal()
	journal.include_in_saved_game_data = false
	assert_false(manager.record_data().lists.has("journal"))
	assert_eq(journal.record_data(), {})


func test_giver_data_round_trip_keeps_cooldown_and_acceptance() -> void:
	QuestsTime.mode = QuestsTime.Mode.MANUAL
	_manager_with_database()
	_journal()
	var asset := QuestTestHelpers.simple_quest("repeat")
	asset.max_times = 3
	asset.cooldown_seconds = 60.0
	var giver := QuestGiver.new()
	giver.id = "npc"
	giver.save_key = "giver"
	giver.quests = [asset] as Array[Quest]
	add_node(giver)
	await frames(2)
	var quest := giver.find_quest("repeat")
	quest.times_accepted = 1
	quest.start_cooldown()
	QuestsTime.manual_time += 20.0
	var data := JSON.parse_string(JSON.stringify(QuestManager.instance.record_data()))
	assert_almost_eq(data.lists.giver.quests[0].state.cooldown, 40.0)
	free_tracked_nodes()
	Quests.reset_static_state()
	QuestsTime.mode = QuestsTime.Mode.MANUAL
	_manager_with_database()
	_journal()
	var giver_2 := QuestGiver.new()
	giver_2.id = "npc"
	giver_2.save_key = "giver"
	giver_2.quests = [asset] as Array[Quest]
	add_node(giver_2)
	await frames(2)
	QuestManager.instance.apply_data(data)
	await frames(3)
	var restored := giver_2.find_quest("repeat")
	assert_eq(restored.times_accepted, 1)
	assert_almost_eq(restored.cooldown_seconds_remaining, 40.0)


func test_add_new_quests_since_saved_game() -> void:
	_manager_with_database()
	var list := QuestList.new()
	list.id = "shelf"
	list.save_key = "shelf"
	list.quests = [QuestTestHelpers.simple_quest("old")] as Array[Quest]
	add_node(list)
	await frames(2)
	var data := JSON.parse_string(JSON.stringify(QuestManager.instance.record_data()))
	free_tracked_nodes()
	Quests.reset_static_state()
	_manager_with_database()
	var list_2 := QuestList.new()
	list_2.id = "shelf"
	list_2.save_key = "shelf"
	list_2.add_new_quests_since_saved_game = true
	list_2.quests = [QuestTestHelpers.simple_quest("old"), QuestTestHelpers.simple_quest("new")] as Array[Quest]
	add_node(list_2)
	await frames(2)
	QuestManager.instance.apply_data(data)
	await frames(3)
	assert_not_null(list_2.find_quest("old"))
	assert_not_null(list_2.find_quest("new"))


func test_reset_all() -> void:
	var manager := _manager_with_database()
	var list := QuestList.new()
	list.id = "shelf"
	list.quests = [QuestTestHelpers.simple_quest("a")] as Array[Quest]
	add_node(list)
	await frames(2)
	list.quest_list[0].set_state(Quest.State.ACTIVE)
	manager.reset_all()
	await frames(2)
	assert_eq(list.quest_list[0].get_state(), Quest.State.WAITING_TO_START)


func test_generator_callbacks_in_saved_data() -> void:
	var manager := _manager_with_database()
	var applied := []
	Quests.generator_record_callback = func() -> Dictionary: return {"seed": 42}
	Quests.generator_apply_callback = func(d: Dictionary) -> void: applied.append(d)
	var data := manager.record_data()
	assert_eq(data.generator, {"seed": 42})
	manager.apply_data(data)
	assert_eq(applied, [{"seed": 42}])


func test_completed_ids_are_saved() -> void:
	var manager := _manager_with_database()
	_journal()
	var quest := Quests.give_quest("q2")
	QuestTestHelpers.test_condition(quest, "task").fire()
	var data := manager.record_data()
	assert_eq(data.completed, ["q2"])
	Quests.reset_static_state()
	assert_false(Quests.was_completed("q2"))
	manager.apply_data(data)
	assert_true(Quests.was_completed("q2"))


func test_tick_sends_message_and_runs_timers() -> void:
	var manager := make_manager()
	var ticks := [0]
	QuestMessages.add_listener(self, QuestMessages.TIMER_TICK, "", func(_a: QuestMessageArgs) -> void: ticks[0] += 1)
	var timer := QuestTestTimer.new()
	Quests.register_timer(timer)
	manager.tick()
	manager.tick()
	assert_eq(ticks[0], 2)
	assert_eq(timer.ticks, 2)
	Quests.unregister_timer(timer)
	manager.tick()
	assert_eq(timer.ticks, 2)


func test_manager_ticks_once_per_second_of_quest_time() -> void:
	QuestsTime.mode = QuestsTime.Mode.MANUAL
	QuestsTime.manual_delta = 0.4
	var ticks := [0]
	var manager := make_manager()
	QuestMessages.add_listener(self, QuestMessages.TIMER_TICK, "", func(_a: QuestMessageArgs) -> void: ticks[0] += 1)
	for i in 6:
		manager._process(0.4)
	assert_eq(ticks[0], 2, "2.4 seconds")


class QuestTestTimer:
	extends RefCounted
	var ticks := 0

	func tick() -> void:
		ticks += 1


func test_debugger_commands() -> void:
	_manager_with_database()
	var journal := _journal()
	var quest := Quests.give_quest("q1")
	assert_true(QuestManager._on_debugger_message("watch", [true]))
	assert_true(QuestManager._debugger_watching)
	assert_true(QuestManager._on_debugger_message("watch", [false]))
	assert_false(QuestManager._debugger_watching)
	assert_true(QuestManager._on_debugger_message("set_counter", ["player", "q1", "c", 9]))
	assert_eq(quest.get_counter("c").current_value, 9)
	assert_true(QuestManager._on_debugger_message("set_node_state", ["player", "q1", "task", QuestNode.State.TRUE]))
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)
	assert_true(QuestManager._on_debugger_message("set_state", ["journal", "q1", Quest.State.FAILED]), "found by save key too")
	assert_eq(quest.get_state(), Quest.State.FAILED)
	assert_true(QuestManager._on_debugger_message("set_state", ["nobody", "q1", 1]))
	assert_false(QuestManager._on_debugger_message("unknown", []))
	QuestManager.instance._send_debugger_state()
	assert_eq(journal.quest_list.size(), 1)


func test_register_with_save() -> void:
	assert_false(Quests.register_with_save(), "no Save autoload")
	var manager := _manager_with_database()
	var journal := _journal()
	var save := FakeSave.new()
	save.name = "Save"
	add_node(save)
	assert_true(Quests.register_with_save("quest_data"))
	assert_true(save.providers.has("quest_data"))
	Quests.give_quest("q1")
	save.collect()
	assert_true(save.sections["quest_data"].lists.has("journal"))
	assert_eq(save.sections["quest_data"].lists.journal.quests.size(), 1)
	# Loading a slot applies the stored data.
	journal.delete_quest("q1")
	journal.deleted_static_quests.clear()
	assert_null(journal.find_quest("q1"))
	save.loaded.emit(0)
	await frames(3)
	assert_not_null(journal.find_quest("q1"))
	assert_eq(journal.find_quest("q1").get_state(), Quest.State.ACTIVE)
	assert_true(Quests.register_with_save("quest_data"), "registering twice is harmless")
	assert_eq(Quests.get_manager(), manager)


func test_manager_registers_with_save_automatically() -> void:
	var save := FakeSave.new()
	save.name = "Save"
	add_node(save)
	var manager := QuestManager.new()
	add_node(manager)
	assert_true(save.providers.has("quests"))
	assert_eq(Quests.get_manager(), manager)


func test_quest_control_methods() -> void:
	_manager_with_database()
	_journal()
	Quests.give_quest("q1")
	var control := add_node(QuestControl.new()) as QuestControl
	control.quest_id = "q1"
	control.quest_node_id = "task"
	control.counter_name = "c"
	control.set_configured_counter(5)
	assert_eq(Quests.counter("q1", "c"), 5)
	control.increment_configured_counter(3)
	assert_eq(Quests.counter("q1", "c"), 8)
	control.increment_counter("q1", "c", -2)
	assert_eq(Quests.counter("q1", "c"), 6)
	control.set_counter("q1", "c", 1)
	assert_eq(Quests.counter("q1", "c"), 1)
	var heard: Array[QuestMessageArgs] = []
	QuestMessages.add_listener(self, "Ping", "", func(a: QuestMessageArgs) -> void: heard.append(a))
	control.send_to_message_system("Ping:Pong:7")
	control.send_message("Ping")
	control.send_message_with_parameter("Ping", "x")
	control.send_message_with_value("Ping", "y", 3)
	assert_eq(heard.size(), 4)
	assert_eq(heard[0].parameter, "Pong")
	assert_eq(heard[0].values, [7])
	assert_eq(heard[0].sender, control)
	assert_eq(heard[3].values, [3])
	control.set_configured_quest_node_state("true")
	assert_eq(Quests.get_quest_state("q1"), Quest.State.SUCCESSFUL)
	control.set_quest_state("q1", "failed")
	assert_eq(Quests.get_quest_state("q1"), Quest.State.FAILED)
	control.set_configured_quest_state("active")
	assert_eq(Quests.get_quest_state("q1"), Quest.State.ACTIVE)
	control.set_quest_node_state("q1", "task", "inactive")
	assert_eq(Quests.get_quest_node_state("q1", "task"), QuestNode.State.INACTIVE)
	control.give_quest("q2")
	assert_not_null(Quests.get_quest_instance("q2"))


func test_quest_control_conditional_event() -> void:
	_manager_with_database()
	_journal()
	var control := add_node(QuestControl.new()) as QuestControl
	var fired := [0]
	control.condition_met.connect(func() -> void: fired[0] += 1)
	control.try_conditional_event()
	assert_eq(fired[0], 1, "no quest set means always met")
	control.conditional_quest_id = "q1"
	control.required_quest_state = Quest.State.ACTIVE
	control.try_conditional_event()
	assert_eq(fired[0], 1)
	Quests.give_quest("q1")
	control.try_conditional_event()
	assert_eq(fired[0], 2)
	control.conditional_node_id = "task"
	control.required_node_state = QuestNode.State.TRUE
	assert_false(control.is_condition_met())
	Quests.set_quest_node_state("q1", "task", QuestNode.State.TRUE)
	assert_false(control.is_condition_met(), "the quest is no longer active")


func test_find_node_with_id() -> void:
	var holder := add_node(Node3D.new())
	holder.name = "Statue"
	var identity := QuestIdentity.new()
	identity.id = "statue_id"
	holder.add_child(identity)
	var journal := _journal()
	assert_eq(QuestMessages.find_node_with_id("statue_id"), holder)
	assert_eq(QuestMessages.find_node_with_id("player"), journal)
	assert_eq(QuestMessages.find_node_with_id("Statue"), holder)
	assert_null(QuestMessages.find_node_with_id("ghost"))
	assert_null(QuestMessages.find_node_with_id(""))


func test_quest_media_registration() -> void:
	var database := QuestDatabase.new()
	var texture := load("res://addons/quests/icon.svg") as Texture2D
	database.images = [texture] as Array[Texture2D]
	var manager := QuestManager.new()
	manager.use_save_addon = false
	manager.quest_databases = [database] as Array[QuestDatabase]
	add_node(manager)
	assert_eq(Quests.get_image("res://addons/quests/icon.svg"), texture)
	assert_null(Quests.get_image(""))
	assert_null(Quests.get_image("res://nope.png"))


func test_icon_survives_clone() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.icon = load("res://addons/quests/icon.svg") as Texture2D
	var copy := make_quest_instance(asset)
	assert_not_null(copy.icon)
	assert_eq(copy.icon.get_width(), asset.icon.get_width())
