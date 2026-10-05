extends QuestsTest


func _quest() -> Quest:
	var asset := QuestTestHelpers.simple_quest("rat_hunt")
	asset.title = "Rat Hunt"
	asset.counter_list.append(QuestCounter.create("rats", 3, 0, 12))
	asset.counter_list.append(QuestCounter.create("timer", 125, 0, 9000))
	return make_quest_instance(asset)


func test_quest_tags() -> void:
	var quest := _quest()
	assert_eq(QuestTags.replace_tags("{QUEST} ({QUESTID})", quest), "Rat Hunt (rat_hunt)")


func test_text_without_tags_is_unchanged() -> void:
	assert_eq(QuestTags.replace_tags("plain text", null), "plain text")
	assert_eq(QuestTags.replace_tags("", null), "")


func test_counter_tags() -> void:
	var quest := _quest()
	assert_eq(QuestTags.replace_tags("{#rats}", quest), "3")
	assert_eq(QuestTags.replace_tags("{<#rats}", quest), "0")
	assert_eq(QuestTags.replace_tags("{>#rats}", quest), "12")
	assert_eq(QuestTags.replace_tags("Kill {#rats} of {>#rats} rats.", quest), "Kill 3 of 12 rats.")
	assert_eq(QuestTags.replace_tags("{:timer}", quest), "02:05")
	assert_eq(QuestTags.replace_tags("{#missing}", quest), "{#missing}", "unknown counters stay as written")


func test_cross_quest_counter_tag() -> void:
	make_manager()
	var journal := QuestTestHelpers.make_journal(self)
	var other := journal.add_quest(_quest())
	other.get_counter("rats").set_value(9)
	var asset := QuestTestHelpers.simple_quest("other")
	var quest := journal.add_quest(asset)
	assert_eq(QuestTags.replace_tags("{#rat_hunt:rats}", quest), "9")


func test_dictionary_tags_and_quester_tags() -> void:
	var quest := _quest()
	quest.assign_quest_giver(QuestParticipant.new("elder", "Elder Mara"))
	quest.assign_quester(QuestParticipant.new("hero", "Aria"))
	assert_eq(QuestTags.replace_tags("{QUESTGIVER} asks {QUESTER}", quest), "Elder Mara asks Aria")
	assert_eq(QuestTags.replace_tags("{QUESTGIVERID}/{QUESTERID}", quest), "elder/hero")
	quest.tag_dictionary["{TARGET}"] = "rat"
	assert_eq(QuestTags.replace_tags("Kill the {TARGET}", quest), "Kill the rat")
	assert_eq(quest.quester_id, "hero")


func test_greeter_properties() -> void:
	var quest := _quest()
	quest.greeter_id = "bob"
	quest.greeter = "Bob"
	assert_eq(QuestTags.replace_tags("{GREETER} {GREETERID}", quest), "Bob bob")
	assert_eq(quest.greeter_id, "bob")


func test_active_node_tags_win() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.tag_dictionary["{PLACE}"] = "the quest place"
	asset.get_node("task").tag_dictionary["{PLACE}"] = "the node place"
	var quest := make_quest_instance(asset)
	assert_eq(QuestTags.replace_tags("{PLACE}", quest), "the quest place", "node isn't active yet")
	quest.set_state(Quest.State.ACTIVE)
	assert_eq(QuestTags.replace_tags("{PLACE}", quest), "the node place")


func test_unknown_tag_becomes_its_word() -> void:
	assert_eq(QuestTags.replace_tags("Go to {Village}.", null), "Go to Village.")


func test_translation() -> void:
	var translation := Translation.new()
	translation.locale = "xx"
	translation.add_message("Hello", "Bonjour")
	translation.add_message("Village", "Hameau")
	translation.add_message("Go to {Village}.", "Allez au {Village}.")
	TranslationServer.add_translation(translation)
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("xx")
	assert_eq(QuestTags.replace_tags("Hello", null), "Bonjour")
	assert_eq(QuestTags.replace_tags("Go to {Village}.", null), "Allez au Hameau.")
	TranslationServer.set_locale(previous)
	TranslationServer.remove_translation(translation)
	assert_eq(QuestTags.replace_tags("Hello", null), "Hello")


func test_content_text_replaces_tags() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.title = "Title"
	var content := QuestTestContent.make("About {QUEST}")
	asset.offer_content_list.append(content)
	var quest := make_quest_instance(asset)
	assert_eq((quest.offer_content_list[0] as QuestTestContent).get_text(), "About Title")


func test_add_tags_to_dictionary() -> void:
	var dictionary := {}
	QuestTags.add_tags_to_dictionary(dictionary, "Bring {ITEM} to {QUESTGIVER}; {#count} {:time} {>#max} {QUEST}")
	assert_true(dictionary.has("{ITEM}"))
	assert_true(dictionary.has("{QUESTGIVER}"))
	assert_false(dictionary.has("{#count}"), "counter tags are dynamic")
	assert_false(dictionary.has("{:time}"))
	assert_eq(dictionary["{ITEM}"], "")
	dictionary["{ITEM}"] = "sword"
	QuestTags.add_tags_to_dictionary(dictionary, "{ITEM}")
	assert_eq(dictionary["{ITEM}"], "sword", "existing values are kept")


func test_content_tags_reach_dictionary_on_initialize() -> void:
	var asset := QuestTestHelpers.simple_quest("q")
	asset.get_node("task").get_state_info(QuestNode.State.ACTIVE).journal_content.append(QuestTestContent.make("Find {ARTIFACT}"))
	var quest := make_quest_instance(asset)
	assert_true(quest.tag_dictionary.has("{ARTIFACT}"))
	assert_false(asset.tag_dictionary.has("{ARTIFACT}"))


func test_seconds_to_time_string() -> void:
	assert_eq(QuestTags.seconds_to_time_string(0), "0")
	assert_eq(QuestTags.seconds_to_time_string(59), "59")
	assert_eq(QuestTags.seconds_to_time_string(60), "01:00")
	assert_eq(QuestTags.seconds_to_time_string(3599), "59:59")
	assert_eq(QuestTags.seconds_to_time_string(3661), "01:01:01")
	assert_eq(QuestTags.seconds_to_time_string(86400 + 3661), "1d, 01:01:01")


func test_get_id_by_specifier() -> void:
	assert_eq(QuestTags.get_id_by_specifier(QuestMessages.Participant.ANY, "x"), "")
	assert_eq(QuestTags.get_id_by_specifier(QuestMessages.Participant.QUESTER, "x"), QuestTags.QUESTERID)
	assert_eq(QuestTags.get_id_by_specifier(QuestMessages.Participant.QUEST_GIVER, "x"), QuestTags.QUESTGIVERID)
	assert_eq(QuestTags.get_id_by_specifier(QuestMessages.Participant.OTHER, "x"), "x")
