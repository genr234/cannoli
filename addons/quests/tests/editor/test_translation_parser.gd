extends QuestsTest

const Parser := preload("res://addons/quests/editor/quest_text_extractor.gd")


func _quest() -> Quest:
	var quest := QuestGraphOps.new_quest("tr", "Wolf Hunt")
	quest.group = "Forest"
	QuestGraphOps.add_counter(quest, "wolves").display_name = "Wolves slain"
	var body := QuestBodyContent.new()
	body.text = "Hello {QUESTER}, mind the {Wolf Pack}. {#wolves}/{>#wolves}"
	quest.offer_content_list.append(body)
	var heading := QuestHeadingContent.new()
	heading.use_quest_title = true
	heading.text = "Should not be extracted"
	quest.node_list[0].state_info_list[QuestNode.State.ACTIVE].journal_content.append(heading)
	return quest


func _texts(entries: Array[Dictionary]) -> PackedStringArray:
	var texts := PackedStringArray()
	for entry in entries:
		texts.append(entry.text)
	return texts


func test_extracts_player_facing_strings() -> void:
	var texts := _texts(Parser.extract(_quest()))
	assert_true(texts.has("Wolf Hunt"), "title")
	assert_true(texts.has("Forest"), "group")
	assert_true(texts.has("Wolves slain"), "counter display name")
	assert_true(texts.has("Hello {QUESTER}, mind the {Wolf Pack}. {#wolves}/{>#wolves}"), "content text")
	assert_true(not texts.has("Should not be extracted"), "heading that uses the quest title")
	assert_true(not texts.has("wolves"), "counter ids are not translatable")


func test_extracts_tag_words_but_not_built_ins_or_counters() -> void:
	var texts := _texts(Parser.extract(_quest()))
	assert_true(texts.has("Wolf Pack"), "{Word} tag is a translation key")
	assert_true(not texts.has("QUESTER"), "built-in tag")
	assert_true(not texts.has("#wolves"), "counter tag")


func test_strings_are_unique() -> void:
	var quest := _quest()
	quest.offer_content_list.append(quest.offer_content_list[0].duplicate())
	var texts := _texts(Parser.extract(quest))
	var count := 0
	for text in texts:
		if text.begins_with("Hello"):
			count += 1
	assert_eq(count, 1, "duplicate text appears once")


func test_parse_file_reads_tres_for_pot_generation() -> void:
	var path := "user://quests_editor_test_parse.tres"
	assert_eq(ResourceSaver.save(_quest(), path), OK, "saved")
	var entries := Parser.parse_file(path)
	var ids := PackedStringArray()
	for entry in entries:
		ids.append(entry[0])
	assert_true(ids.has("Wolf Hunt"), "title in POT entries")
	assert_true(entries[0].size() == 4, "entry has msgid, context, plural and comment")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_database_with_embedded_quests() -> void:
	var database := QuestDatabase.new()
	database.quest_assets.append(_quest())
	assert_true(_texts(Parser.extract(database)).has("Wolf Hunt"), "quests inside a database are found")
