extends QuestsTest
## Journal options and static API parity checks.


func _generated(quest_id: String) -> Quest:
	var quest := QuestTestHelpers.simple_quest(quest_id)
	quest.is_procedurally_generated = true
	return quest


func test_journal_defaults_remember_generated_quests() -> void:
	make_manager()
	var journal := QuestTestHelpers.make_journal(self)
	assert_false(journal.only_remember_handwritten_quests, "generated quests are remembered by default")
	assert_true(journal.remember_completed_quests)
	assert_false(journal.compress_completed_procgen_quests)
	var quest := journal.add_quest(_generated("gen1"))
	quest.set_state(Quest.State.ACTIVE)
	quest.set_state(Quest.State.SUCCESSFUL)
	assert_not_null(journal.find_quest("gen1"), "completed generated quest stays")


func test_journal_only_remember_handwritten() -> void:
	make_manager()
	var journal := QuestTestHelpers.make_journal(self)
	journal.only_remember_handwritten_quests = true
	var generated := journal.add_quest(_generated("gen2"))
	var handwritten := journal.add_quest(QuestTestHelpers.simple_quest("hand"))
	generated.set_state(Quest.State.ACTIVE)
	handwritten.set_state(Quest.State.ACTIVE)
	generated.set_state(Quest.State.SUCCESSFUL)
	handwritten.set_state(Quest.State.SUCCESSFUL)
	assert_null(journal.find_quest("gen2"), "generated quest forgotten")
	assert_not_null(journal.find_quest("hand"), "handwritten quest remembered")


func test_journal_compresses_completed_generated_quests() -> void:
	make_manager()
	var journal := QuestTestHelpers.make_journal(self)
	journal.compress_completed_procgen_quests = true
	var asset := _generated("gen3")
	var info := asset.get_state_info(Quest.State.ACTIVE)
	var body := QuestBodyContent.new()
	body.text = "Do it"
	info.journal_content.append(body)
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	quest.set_state(Quest.State.SUCCESSFUL)
	assert_true(quest.get_state_info(Quest.State.ACTIVE).journal_content.is_empty(), "inactive state content removed")


func test_static_abandon_quest() -> void:
	make_manager()
	var journal := QuestTestHelpers.make_journal(self)
	var asset := QuestTestHelpers.simple_quest("ab")
	asset.is_abandonable = true
	asset.remember_if_abandoned = true
	var quest := journal.add_quest(asset)
	quest.set_state(Quest.State.ACTIVE)
	assert_true(Quests.abandon_quest("ab"))
	assert_eq(quest.get_state(), Quest.State.ABANDONED)
	assert_false(Quests.abandon_quest("missing"))
