extends QuestsTest

var journal: QuestJournal
var ui: FakeDialogueUI


func before_each() -> void:
	make_manager()
	journal = QuestTestHelpers.make_journal(self)
	ui = FakeDialogueUI.new()


func after_each() -> void:
	ui.free()


func _giver(assets: Array[Quest]) -> QuestGiver:
	var giver := QuestTestHelpers.make_giver(self, "npc", assets)
	giver.dialogue_ui = ui
	return giver


func _offer_quest(quest_id: String) -> Quest:
	var asset := QuestTestHelpers.simple_quest(quest_id)
	asset.offer_content_list.append(QuestTestContent.make("Please help"))
	asset.title = quest_id.capitalize()
	return asset


func test_giver_assigns_itself_to_its_quests() -> void:
	var giver := _giver([_offer_quest("q")])
	await frames(2)
	var quest := giver.find_quest("q")
	assert_not_null(quest)
	assert_eq(quest.quest_giver_id, "npc")
	assert_eq(quest.get_state(), Quest.State.WAITING_TO_START, "started after the frame")
	assert_eq(QuestTags.replace_tags("{QUESTGIVERID}", quest), "npc")


func test_list_registration_and_ids() -> void:
	var giver := _giver([])
	assert_eq(Quests.get_quest_list("npc"), giver)
	assert_eq(Quests.get_quest_list("player"), journal)
	assert_eq(Quests.get_journal(), journal)
	assert_eq(Quests.get_journal("player"), journal)
	assert_null(Quests.get_quest_list("nobody"))
	giver.free()
	assert_null(Quests.get_quest_list("npc"))


func test_list_id_from_identity_or_name() -> void:
	var character := add_node(Node3D.new())
	character.name = "Blacksmith"
	var list := QuestList.new()
	character.add_child(list)
	assert_eq(list.id, "Blacksmith", "falls back to the parent's name")
	var other := add_node(Node3D.new())
	var identity := QuestIdentity.new()
	identity.id = "smith_id"
	identity.display_name = "Old Smith"
	other.add_child(identity)
	var other_list := QuestList.new()
	other.add_child(other_list)
	assert_eq(other_list.id, "smith_id")
	assert_eq(other_list.display_name, "Old Smith")
	assert_eq(other_list.get_participant().display_name, "Old Smith")
	assert_eq(QuestIdentity.find_by_id("smith_id"), identity)
	assert_eq(QuestIdentity.find_for(other_list), identity)
	assert_eq(QuestIdentity.find_for(other), identity)


func test_single_offer_dialogue_and_accept() -> void:
	var giver := _giver([_offer_quest("q")])
	await frames(2)
	var seen: Array[String] = []
	QuestMessages.add_listener(self, QuestMessages.GREET, "npc", func(_a: QuestMessageArgs) -> void: seen.append("greet"))
	QuestMessages.add_listener(self, QuestMessages.GREETED, "npc", func(_a: QuestMessageArgs) -> void: seen.append("greeted"))
	QuestMessages.add_listener(self, QuestMessages.DISCUSS_QUEST, "q", func(_a: QuestMessageArgs) -> void: seen.append("discuss"))
	QuestMessages.add_listener(self, QuestMessages.DISCUSSED_QUEST, "q", func(_a: QuestMessageArgs) -> void: seen.append("discussed"))
	var started := [0]
	giver.dialogue_started.connect(func(_p: Node) -> void: started[0] += 1)
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "offer")
	assert_eq(ui.last_quest.id, "q")
	assert_eq(seen, ["greet", "discuss", "discussed", "greeted"])
	assert_eq(started[0], 1)
	ui.accept_handler.call(ui.last_quest)
	# The giver's quest is copied to the journal and started.
	var instance := journal.find_quest("q")
	assert_not_null(instance)
	assert_eq(instance.get_state(), Quest.State.ACTIVE)
	assert_eq(instance.quest_giver_id, "npc")
	assert_eq(instance.quester_id, "player")
	assert_eq(instance.times_accepted, 1)
	assert_eq(instance.get_node("task").get_state(), QuestNode.State.ACTIVE)
	assert_ne(instance, giver.find_quest("q"))
	assert_null(giver.find_quest("q"), "max_times 1: the giver is out of that quest")
	assert_true(giver.deleted_static_quests.has("q"))
	assert_eq(ui.last_call(), "close")


func test_giver_copy_keeps_cooldown_when_repeatable() -> void:
	QuestsTime.mode = QuestsTime.Mode.MANUAL
	var asset := _offer_quest("q")
	asset.max_times = 3
	asset.cooldown_seconds = 30.0
	var giver := _giver([asset])
	await frames(2)
	giver.start_dialogue(journal)
	ui.accept_handler.call(ui.last_quest)
	var giver_quest := giver.find_quest("q")
	assert_not_null(giver_quest)
	assert_eq(giver_quest.times_accepted, 1)
	assert_almost_eq(giver_quest.cooldown_seconds_remaining, 30.0)
	assert_eq(giver.get_offerable_quests(journal).size(), 0, "cooling down")
	QuestsTime.manual_time += 31.0
	assert_eq(giver.get_offerable_quests(journal).size(), 0, "the player's copy is still active")
	journal.find_quest("q").set_state(Quest.State.FAILED)
	assert_eq(giver.get_offerable_quests(journal).size(), 1, "cooldown over and the player finished")


func test_two_offers_show_quest_list() -> void:
	var giver := _giver([_offer_quest("a"), _offer_quest("b")])
	await frames(2)
	giver.offerable_quests_content = [QuestTestContent.make("Offers") as QuestContent]
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "list")
	assert_eq(ui.last_quests.size(), 2)
	assert_eq(ui.last_offerable_contents.size(), 1)
	ui.select_handler.call(giver.find_quest("a"))
	assert_eq(ui.last_call(), "offer")
	assert_eq(ui.last_quest.id, "a")
	ui.accept_handler.call(ui.last_quest)
	assert_eq(ui.last_call(), "list", "b is still offerable, so back to the list")
	assert_eq(ui.last_quests.size(), 2, "a (active) and b (offerable)")
	assert_not_null(journal.find_quest("a"))
	ui.select_handler.call(giver.find_quest("b"))
	ui.accept_handler.call(ui.last_quest)
	assert_eq(ui.last_call(), "close", "nothing left to offer")


func test_accept_with_more_offers_returns_to_list() -> void:
	var giver := _giver([_offer_quest("a"), _offer_quest("b"), _offer_quest("c")])
	await frames(2)
	giver.start_dialogue(journal)
	ui.select_handler.call(giver.find_quest("a"))
	ui.accept_handler.call(ui.last_quest)
	assert_eq(ui.last_call(), "list")
	assert_eq(ui.last_quests.size(), 3, "a is active, b and c are offerable")


func test_decline_goes_back_to_list() -> void:
	var giver := _giver([_offer_quest("a"), _offer_quest("b")])
	await frames(2)
	giver.start_dialogue(journal)
	ui.select_handler.call(giver.find_quest("a"))
	ui.decline_handler.call(ui.last_quest)
	assert_eq(ui.last_call(), "list")
	assert_null(journal.find_quest("a"))


func test_active_quest_dialogue() -> void:
	var asset := _offer_quest("q")
	var giver := _giver([asset])
	await frames(2)
	giver.start_dialogue(journal)
	ui.accept_handler.call(ui.last_quest)
	ui.calls.clear()
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "active")
	assert_eq(ui.last_quest.id, "q")
	assert_false(ui.back_handler.is_valid(), "only one quest, no back button")
	assert_eq(ui.last_quest.greeter_id, "player")
	ui.continue_handler.call(ui.last_quest)
	assert_eq(ui.last_call(), "close")


func test_active_quest_from_another_giver_that_lists_this_one_as_speaker() -> void:
	var asset := QuestTestHelpers.simple_quest("delivery")
	asset.quest_giver_id = "other_npc"
	asset.get_node("task").speaker = "npc"
	asset.get_node("task").get_state_info(QuestNode.State.ACTIVE).dialogue_content.append(QuestTestContent.make("Thanks for coming"))
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	var giver := _giver([])
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "active")
	assert_eq(ui.last_quest, quest)


func test_nothing_to_discuss() -> void:
	var giver := _giver([])
	giver.no_quests_content = [QuestTestContent.make("Nothing today") as QuestContent]
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "contents")
	assert_eq(ui.last_contents.size(), 1)
	assert_false(giver.has_offerable_or_active_quest(journal))


func test_unmet_offer_conditions() -> void:
	var asset := _offer_quest("q")
	asset.offer_condition_set.condition_list.append(QuestTestCondition.new())
	var giver := _giver([asset])
	await frames(2)
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "unmet")
	assert_eq(ui.last_quests.size(), 1)
	assert_true(giver.get_offerable_quests(journal).is_empty())


func test_requires_quests_blocks_the_offer() -> void:
	var asset := _offer_quest("second")
	asset.requires_quests = PackedStringArray(["first"])
	var giver := _giver([asset])
	await frames(2)
	assert_eq(giver.get_offerable_quests(journal).size(), 0)
	var first := journal.add_quest(QuestTestHelpers.simple_quest("first"))
	first.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(first, "task").fire()
	assert_eq(giver.get_offerable_quests(journal).size(), 1)


func test_completed_quest_dialogue_modes() -> void:
	var asset := _offer_quest("q")
	asset.get_state_info(Quest.State.SUCCESSFUL).dialogue_content.append(QuestTestContent.make("Well done"))
	var giver := _giver([asset])
	await frames(2)
	giver.start_dialogue(journal)
	ui.accept_handler.call(ui.last_quest)
	var quest := journal.find_quest("q")
	quest.set_state(Quest.State.SUCCESSFUL)
	ui.calls.clear()
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "completed", "global default shows completed quests")
	giver.completed_quest_dialogue_mode = QuestGiver.CompletedQuestDialogueMode.SHOW_NO_QUESTS
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "contents")
	giver.completed_quest_dialogue_mode = QuestGiver.CompletedQuestDialogueMode.SAME_AS_GLOBAL
	QuestManager.instance.completed_quest_dialogue_mode = QuestManager.CompletedQuestDialogueMode.SHOW_NO_QUESTS
	assert_eq(giver.get_completed_quest_dialogue_mode(), QuestGiver.CompletedQuestDialogueMode.SHOW_NO_QUESTS)
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "contents")


func test_specified_quest_dialogue() -> void:
	var giver := _giver([_offer_quest("a"), _offer_quest("b")])
	await frames(2)
	giver.start_specified_quest_dialogue(journal, "b")
	assert_eq(ui.last_call(), "offer")
	assert_eq(ui.last_quest.id, "b")
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "list", "the override is used once")


func test_dialogue_ended_signal_and_stop() -> void:
	var giver := _giver([_offer_quest("q")])
	await frames(2)
	var ended := [0]
	giver.dialogue_ended.connect(func() -> void: ended[0] += 1)
	giver.start_dialogue(journal)
	giver.stop_dialogue()
	assert_eq(ui.last_call(), "close")
	assert_eq(ended[0], 1)


func test_dialogue_uses_manager_ui_when_giver_has_none() -> void:
	QuestManager.instance.dialogue_ui = ui
	var giver := QuestTestHelpers.make_giver(self, "npc", [_offer_quest("q")])
	await frames(2)
	assert_eq(giver.get_dialogue_ui(), ui)
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "offer")
	QuestManager.instance.dialogue_ui = null


func test_player_found_by_group() -> void:
	var player := Node3D.new()
	player.name = "Player"
	add_node(player)
	player.add_to_group(&"player")
	var player_journal := QuestList.new()
	player_journal.id = "player_list"
	player.add_child(player_journal)
	var giver := _giver([_offer_quest("q")])
	await frames(2)
	assert_eq(giver.find_player(), player)
	giver.start_dialogue()
	ui.accept_handler.call(ui.last_quest)
	assert_not_null(player_journal.find_quest("q"))
	assert_null(journal.find_quest("q"))


func test_give_quest_to_quester_directly() -> void:
	var giver := _giver([_offer_quest("a"), _offer_quest("b")])
	await frames(2)
	giver.give_quest_to_quester(giver.find_quest("a"), "player")
	assert_eq(journal.find_quest("a").get_state(), Quest.State.ACTIVE)
	giver.give_all_quests_to_quester(journal)
	assert_eq(journal.find_quest("b").get_state(), Quest.State.ACTIVE)
	assert_eq(giver.quest_list.size(), 0)


func test_give_quest_replaces_an_old_finished_copy() -> void:
	var asset := _offer_quest("q")
	asset.max_times = 2
	asset.cooldown_seconds = 0.0
	var giver := _giver([asset])
	await frames(2)
	giver.start_dialogue(journal)
	ui.accept_handler.call(ui.last_quest)
	journal.find_quest("q").set_state(Quest.State.FAILED)
	giver.start_dialogue(journal)
	assert_eq(ui.last_call(), "offer")
	assert_null(journal.find_quest("q"), "the old copy is cleared before the new offer")
	ui.accept_handler.call(ui.last_quest)
	assert_eq(journal.find_quest("q").get_state(), Quest.State.ACTIVE)
	assert_null(giver.find_quest("q"), "accepted twice, so the giver is out of it")


func test_no_repeat_if_successful() -> void:
	var asset := _offer_quest("q")
	asset.max_times = 3
	asset.no_repeat_if_successful = true
	var giver := _giver([asset])
	await frames(2)
	giver.start_dialogue(journal)
	ui.accept_handler.call(ui.last_quest)
	var quest := journal.find_quest("q")
	quest.set_state(Quest.State.SUCCESSFUL)
	assert_eq(giver.get_offerable_quests(journal).size(), 0)


func test_giver_without_ui_warns_and_does_nothing() -> void:
	var giver := QuestTestHelpers.make_giver(self, "lonely", [])
	giver.start_dialogue(journal)
	assert_eq(ui.calls.size(), 0)


# Journal

func test_journal_deletes_completed_quests_when_not_remembering() -> void:
	journal.remember_completed_quests = false
	var quest := journal.add_quest(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task").fire()
	assert_null(journal.find_quest("q"))


func test_journal_remembers_completed_quests_by_default() -> void:
	var quest := journal.add_quest(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task").fire()
	assert_eq(journal.find_quest("q"), quest)
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)


func test_delete_when_complete() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.delete_when_complete = true
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	QuestTestHelpers.test_condition(quest, "task").fire()
	assert_null(journal.find_quest("q"))


func test_abandon_forgetting() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.is_abandonable = true
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	var abandoned: Array[String] = []
	QuestMessages.add_listener(self, QuestMessages.QUEST_ABANDONED, "q", func(a: QuestMessageArgs) -> void: abandoned.append(a.parameter))
	var action := QuestTestAction.new()
	asset.get_state_info(Quest.State.ABANDONED).action_list.append(action)
	journal.abandon_quest(quest)
	assert_null(journal.find_quest("q"))
	assert_eq(abandoned, ["q"])


func test_abandon_remembering() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.is_abandonable = true
	asset.remember_if_abandoned = true
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	journal.abandon_quest(quest)
	assert_eq(journal.find_quest("q"), quest)
	assert_eq(quest.get_state(), Quest.State.ABANDONED)
	assert_eq(quest.get_node("task").get_state(), QuestNode.State.INACTIVE)


func test_abandon_runs_abandoned_actions_when_forgetting() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.is_abandonable = true
	var action := QuestTestAction.new()
	asset.get_state_info(Quest.State.ABANDONED).action_list.append(action)
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	var instance_action: QuestTestAction = quest.get_state_info(Quest.State.ABANDONED).action_list[0]
	journal.abandon_quest(quest)
	assert_eq(instance_action.executed, 1)


func test_abandon_requires_abandonable() -> void:
	var quest := journal.add_quest(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	journal.abandon_quest(quest)
	assert_eq(quest.get_state(), Quest.State.ACTIVE)
	journal.abandon_quest(null)


func test_only_track_one_quest() -> void:
	journal.only_track_one_quest_at_a_time = true
	var a := journal.add_quest(QuestTestHelpers.simple_quest("a"))
	var b := journal.add_quest(QuestTestHelpers.simple_quest("b"))
	assert_false(a.show_in_track_hud, "tracking b untracked a")
	assert_true(b.show_in_track_hud)
	journal.set_tracking("a", true)
	assert_true(a.show_in_track_hud)
	assert_false(b.show_in_track_hud)


func test_completed_quests_are_untracked() -> void:
	var quest := journal.add_quest(QuestTestHelpers.simple_quest("q"))
	quest.set_state(Quest.State.ACTIVE)
	assert_true(quest.show_in_track_hud)
	QuestTestHelpers.test_condition(quest, "task").fire()
	assert_false(quest.show_in_track_hud)


class RecordingJournalUI:
	extends QuestJournalUI
	var calls: Array[String] = []

	func open(_journal: QuestJournal) -> void:
		calls.append("open")
		super(_journal)

	func close() -> void:
		calls.append("close")
		super()

	func repaint(_journal: QuestJournal) -> void:
		calls.append("repaint")


func test_journal_repaints_ui_on_changes() -> void:
	var recording := RecordingJournalUI.new()
	journal.journal_ui = recording
	var quest := journal.add_quest(QuestTestHelpers.simple_quest("q"))
	recording.calls.clear()
	quest.set_state(Quest.State.ACTIVE)
	assert_true(recording.calls.has("repaint"))
	recording.calls.clear()
	journal.show_journal_ui()
	assert_eq(recording.calls, ["open"])
	journal.toggle_journal_ui()
	assert_eq(recording.calls, ["open", "close"])
	recording.free()


func test_journal_uses_manager_ui() -> void:
	var recording := RecordingJournalUI.new()
	QuestManager.instance.journal_ui = recording
	assert_eq(journal.get_journal_ui(), recording)
	Quests.show_journal_ui()
	assert_eq(recording.calls.back(), "open")
	QuestManager.instance.journal_ui = null
	recording.free()


func test_forwarded_list_signals() -> void:
	var added: Array[String] = []
	var removed: Array[String] = []
	var states: Array[String] = []
	var nodes: Array[String] = []
	journal.quest_added.connect(func(q: Quest) -> void: added.append(q.id))
	journal.quest_removed.connect(func(id: String) -> void: removed.append(id))
	journal.quest_state_changed.connect(func(q: Quest) -> void: states.append(q.id))
	journal.quest_node_state_changed.connect(func(n: QuestNode) -> void: nodes.append(n.id))
	var quest := journal.add_quest(QuestTestHelpers.simple_quest("q"))
	assert_eq(added, ["q"])
	quest.set_state(Quest.State.ACTIVE)
	assert_true(states.has("q"))
	assert_true(nodes.has("task"))
	journal.delete_quest("q")
	assert_eq(removed, ["q"])


func test_list_quests_export_instantiated_on_ready() -> void:
	var list := QuestList.new()
	list.id = "pre"
	list.quests = [QuestTestHelpers.simple_quest("a")] as Array[Quest]
	add_node(list)
	assert_eq(list.quest_list.size(), 1)
	assert_true(list.quest_list[0].is_instance)
	assert_eq(list.quest_list[0].get_state(), Quest.State.DISABLED if false else Quest.State.WAITING_TO_START, "set by the deferred start")
	await frames(2)
	assert_eq(list.quest_list[0].get_state(), Quest.State.WAITING_TO_START)


func test_deleted_static_quests_are_not_added_again() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	journal.add_quest(asset)
	journal.delete_quest("q")
	assert_null(journal.add_quest(asset))
	journal.deleted_static_quests.clear()
	assert_not_null(journal.add_quest(asset))


func test_reset_to_original_state() -> void:
	var list := QuestList.new()
	list.id = "resettable"
	list.quests = [QuestTestHelpers.simple_quest("a")] as Array[Quest]
	add_node(list)
	list.quest_list[0].set_state(Quest.State.ACTIVE)
	list.add_quest(QuestTestHelpers.simple_quest("extra"))
	list.reset_to_original_state()
	await frames(2)
	assert_eq(list.quest_list.size(), 1)
	assert_eq(list.quest_list[0].id, "a")
	assert_eq(list.quest_list[0].get_state(), Quest.State.WAITING_TO_START)
	assert_eq(list.deleted_static_quests.size(), 0)
