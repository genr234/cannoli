extends QuestsTest

func test_every_template_makes_a_valid_quest() -> void:
	for template_id: String in QuestWizards.get_templates():
		var params := QuestWizards.defaults(QuestWizards.get_templates()[template_id].fields)
		params["title"] = "Template " + template_id
		params["previous_id"] = "first"
		var quest := QuestWizards.create_from_template(template_id, params)
		assert_true(quest != null, "%s creates a quest" % template_id)
		if quest == null:
			continue
		var problems := QuestValidator.validate(quest, PackedStringArray(["first", quest.id]))
		assert_eq(problems, [] as Array[String], "%s has no validator problems" % template_id)


func test_collect_template_counts_messages() -> void:
	var quest := QuestWizards.create_from_template(QuestWizards.TEMPLATE_COLLECT, {"title": "Herbs", "item": "Herb", "count": 3})
	assert_eq(quest.counter_list.size(), 1, "one counter")
	assert_eq(quest.counter_list[0].max_value, 3, "counter goal")
	assert_eq(quest.counter_list[0].message_event_list[0].message, "Collected", "increments on Collected")
	assert_eq(quest.counter_list[0].message_event_list[0].parameter, "Herb", "parameter is the item")


func test_chain_and_timed_template_use_new_quest_features() -> void:
	var chain := QuestWizards.create_from_template(QuestWizards.TEMPLATE_CHAIN, {"title": "Second", "previous_id": "first"})
	assert_eq(chain.requires_quests, PackedStringArray(["first"]), "chain requires the previous quest")
	var timed := QuestWizards.create_from_template(QuestWizards.TEMPLATE_TIMED_DELIVERY, {"title": "Rush", "seconds": 90})
	assert_eq(timed.time_limit, 90.0, "time limit set")


func test_wizard_inserts_node_before_success() -> void:
	var quest := QuestGraphOps.new_quest("w", "W")
	QuestWizards.add_return_node(quest, "", QuestWizards.defaults(QuestWizards.get_wizards()[QuestWizards.RETURN].fields))
	var wizard_node := QuestGraphOps.find_node(quest, quest.node_list[0].children[0])
	assert_eq(wizard_node.node_type, QuestNode.Type.CONDITION, "start leads to the new condition node")
	var success := QuestGraphOps.find_node(quest, wizard_node.children[0])
	assert_eq(success.node_type, QuestNode.Type.SUCCESS, "which leads to success")
	QuestWizards.add_message_node(quest, "", {"message": "Hello", "leads_to_success": true})
	assert_eq(quest.node_list[0].children.size(), 1, "a second wizard inserts into the chain")
