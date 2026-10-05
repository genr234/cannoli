extends QuestsTest

func _valid_quest() -> Quest:
	var quest := QuestGraphOps.new_quest("valid", "Valid")
	QuestWizards.add_message_node(quest, "", {
		"message": "Explored", "parameter": "Cave", "hud_text": "Explore", "journal_text": "j", "dialogue_text": "d",
		"leads_to_success": true,
	})
	return quest


func _kinds(quest: Quest) -> PackedStringArray:
	var kinds := PackedStringArray()
	for issue in QuestValidator.validate_issues(quest):
		kinds.append(issue.kind)
	return kinds


func test_valid_quest_has_no_problems() -> void:
	assert_eq(QuestValidator.validate(_valid_quest()), [] as Array[String], "a quest built by the wizard is valid")


func test_empty_title_and_id() -> void:
	var quest := _valid_quest()
	quest.title = "  "
	quest.id = ""
	var kinds := _kinds(quest)
	assert_true(kinds.has("title"), "empty title found")
	assert_true(kinds.has("quest_id"), "empty id found")


func test_no_success_node() -> void:
	var quest := QuestGraphOps.new_quest("q", "Q")
	QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2.ZERO, "q.start")
	assert_true(_kinds(quest).has("no_success"), "missing success node found")


func test_duplicate_and_missing_children() -> void:
	var quest := _valid_quest()
	var passthrough := QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2.ZERO, quest.node_list[0].id)
	passthrough.id = quest.node_list[1].id
	passthrough.children = PackedStringArray(["nowhere"])
	var kinds := _kinds(quest)
	assert_true(kinds.has("duplicate_id"), "duplicate node id found")
	assert_true(kinds.has("missing_child"), "child pointing at a missing id found")


func test_unreachable_node() -> void:
	var quest := _valid_quest()
	var island := QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2.ZERO)
	var unreachable := QuestValidator.get_unreachable_nodes(quest)
	assert_eq(unreachable.size(), 1, "one unreachable node")
	assert_true(unreachable[0] == island, "it is the unlinked node")
	assert_true(_kinds(quest).has("unreachable"), "reported as a problem")


func test_missing_counter_reference() -> void:
	var quest := _valid_quest()
	var node := quest.node_list[1]
	var condition := QuestCounterCondition.new()
	condition.counter_name = "ghost"
	condition.required_counter_value = QuestNumber.literal(3)
	node.condition_set.condition_list.append(condition)
	assert_true(QuestValidator.find_missing_counters(quest).has("ghost"), "missing counter listed")
	assert_true(_kinds(quest).has("missing_counter"), "missing counter reported")
	QuestGraphOps.add_counter(quest, "ghost")
	assert_true(not _kinds(quest).has("missing_counter"), "defining the counter clears the problem")


func test_missing_node_reference() -> void:
	var quest := _valid_quest()
	var condition := QuestNodeStateCondition.new()
	condition.required_node_id = "missing"
	quest.node_list[1].condition_set.condition_list.append(condition)
	assert_true(_kinds(quest).has("missing_node"), "reference to a missing node reported")


func test_database_duplicate_ids() -> void:
	var database := QuestDatabase.new()
	database.quest_assets.append(_valid_quest())
	database.quest_assets.append(_valid_quest())
	var problems := QuestValidator.validate_database(database)
	var found := false
	for problem in problems:
		found = found or problem.begins_with("Duplicate quest id")
	assert_true(found, "duplicate quest id found in database")


func test_required_quest_must_exist() -> void:
	var quest := _valid_quest()
	quest.requires_quests = PackedStringArray(["other"])
	assert_true(not QuestValidator.validate_issues(quest, PackedStringArray(["valid"])).is_empty(), "unknown prerequisite reported")
	assert_true(QuestValidator.validate_issues(quest, PackedStringArray(["valid", "other"])).is_empty(), "known prerequisite accepted")
