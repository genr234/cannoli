extends QuestsTest
## Word tags and dialects (text tables per quest giver).


func _quest_with_text(text: String) -> Quest:
	var asset := QuestTestHelpers.simple_quest("dialect_q")
	var body := QuestBodyContent.new()
	body.text = text
	asset.get_state_info(Quest.State.ACTIVE).journal_content.append(body)
	return asset.clone()


func test_unknown_word_tag_in_content_shows_the_word() -> void:
	var quest := _quest_with_text("{Hello} there")
	var body: QuestContent = quest.get_state_info(Quest.State.ACTIVE).journal_content[0]
	assert_eq(body.get_text(), "Hello there", "a word tag with no translation shows the word")


func test_quest_giver_dialect_replaces_word_tags() -> void:
	var quest := _quest_with_text("{Hello} traveler")
	var table := {"Hello": "Ahoy"}
	quest.assign_quest_giver(QuestParticipant.new("pirate", "Pirate", null, table))
	var body: QuestContent = quest.get_state_info(Quest.State.ACTIVE).journal_content[0]
	assert_eq(body.get_text(), "Ahoy traveler")


func test_dialect_alternatives_are_chosen_when_the_giver_is_assigned() -> void:
	var quest := _quest_with_text("{Hello} traveler")
	quest.assign_quest_giver(QuestParticipant.new("knight", "Knight", null, {"Hello": "Huzzah|Greetings"}))
	var body: QuestContent = quest.get_state_info(Quest.State.ACTIVE).journal_content[0]
	var first := body.get_text()
	assert_true(first == "Huzzah traveler" or first == "Greetings traveler", "one alternative chosen: " + first)
	for i in 5:
		assert_eq(body.get_text(), first, "choice is stable")


func test_giver_node_provides_its_dialect() -> void:
	make_manager()
	var giver := QuestGiver.new()
	giver.id = "pirate2"
	giver.text_table = {"Hello": "Ahoy"}
	var asset := _quest_with_text("{Hello}!")
	giver.quests = [asset]
	add_node(giver)
	var instance := giver.find_quest("dialect_q")
	var body: QuestContent = instance.get_state_info(Quest.State.ACTIVE).journal_content[0]
	assert_eq(body.get_text(), "Ahoy!")


func test_speaker_dialect_is_used_for_dialogue_text() -> void:
	var quest := _quest_with_text("{Hello}")
	var speaker := QuestParticipant.new("other", "Other", null, {"Hello": "Yo"})
	var node := quest.get_node("task")
	node.speaker = "other"
	var body := QuestBodyContent.new()
	body.text = "{Hello}"
	node.get_state_info(QuestNode.State.INACTIVE).dialogue_content.append(body)
	quest.set_runtime_references()
	quest.set_state(Quest.State.ACTIVE, false)
	node.set_state_raw(QuestNode.State.INACTIVE)
	var list := quest.get_content_list(QuestContent.Category.DIALOGUE, speaker)
	assert_eq(list.size(), 1)
	assert_eq(list[0].get_text(), "Yo")
