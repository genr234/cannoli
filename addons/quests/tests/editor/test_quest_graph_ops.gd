extends QuestsTest

func _quest() -> Quest:
	return QuestGraphOps.new_quest("ops", "Ops")


func test_new_quest_has_start_node() -> void:
	var quest := _quest()
	assert_eq(quest.node_list.size(), 1, "one node")
	assert_eq(quest.node_list[0].node_type, QuestNode.Type.START, "it is the start node")


func test_create_and_connect() -> void:
	var quest := _quest()
	var start := quest.node_list[0]
	var node := QuestGraphOps.create_node(quest, QuestNode.Type.CONDITION, Vector2(100, 0), start.id)
	assert_true(start.children.has(node.id), "created node is linked from its parent")
	assert_true(not QuestGraphOps.connect_nodes(quest, start.id, node.id), "linking twice does nothing")
	assert_true(not QuestGraphOps.connect_nodes(quest, node.id, start.id), "nothing can lead into Start")
	var success := QuestGraphOps.create_node(quest, QuestNode.Type.SUCCESS, Vector2.ZERO, node.id)
	assert_true(not QuestGraphOps.connect_nodes(quest, success.id, node.id), "success nodes have no children")
	assert_true(QuestGraphOps.disconnect_nodes(quest, start.id, node.id), "unlink")
	assert_true(start.children.is_empty(), "link removed")


func test_unique_ids() -> void:
	var quest := _quest()
	var a := QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2.ZERO)
	var b := QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2.ZERO)
	assert_true(a.id != b.id, "ids differ")


func test_delete_nodes_cleans_links_and_protects_start() -> void:
	var quest := _quest()
	var a := QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2.ZERO, quest.node_list[0].id)
	var b := QuestGraphOps.create_node(quest, QuestNode.Type.SUCCESS, Vector2.ZERO, a.id)
	assert_eq(QuestGraphOps.delete_nodes(quest, [a.id, quest.node_list[0].id]), 1, "only the non-start node is deleted")
	assert_true(quest.node_list[0].children.is_empty(), "links to the deleted node are removed")
	assert_true(quest.node_list.has(b), "other nodes are kept")


func test_duplicate_nodes_remaps_children() -> void:
	var quest := _quest()
	var a := QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2.ZERO, quest.node_list[0].id)
	var b := QuestGraphOps.create_node(quest, QuestNode.Type.SUCCESS, Vector2.ZERO, a.id)
	var copies := QuestGraphOps.duplicate_nodes(quest, [a.id, b.id])
	assert_eq(copies.size(), 2, "both copied")
	assert_true(copies[0].children.has(copies[1].id), "copy links to the copied child, not the original")
	assert_true(not copies[0].children.has(b.id), "no link to the original child")
	assert_true(copies[0].id != a.id, "fresh id")


func test_snapshot_restore() -> void:
	var quest := _quest()
	var before := QuestGraphOps.snapshot(quest)
	var node := QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2(5, 5), quest.node_list[0].id)
	var after := QuestGraphOps.snapshot(quest)
	QuestGraphOps.restore(quest, before)
	assert_eq(quest.node_list.size(), 1, "undo removes the node")
	assert_true(quest.node_list[0].children.is_empty(), "undo restores links")
	QuestGraphOps.restore(quest, after)
	assert_true(quest.node_list.has(node), "redo restores the node")
	assert_true(quest.node_list[0].children.has(node.id), "redo restores links")


func test_arrange_places_children_below_parents() -> void:
	var quest := _quest()
	var a := QuestGraphOps.create_node(quest, QuestNode.Type.PASSTHROUGH, Vector2.ZERO, quest.node_list[0].id)
	var b := QuestGraphOps.create_node(quest, QuestNode.Type.SUCCESS, Vector2.ZERO, a.id)
	QuestGraphOps.arrange(quest, [])
	assert_true(b.editor_position.y > a.editor_position.y, "child is on a lower level")


func test_rename_counter_updates_references() -> void:
	var quest := _quest()
	QuestGraphOps.add_counter(quest, "wolves")
	var node := QuestGraphOps.create_node(quest, QuestNode.Type.CONDITION, Vector2.ZERO, quest.node_list[0].id)
	var condition := QuestCounterCondition.new()
	condition.counter_name = "wolves"
	condition.required_counter_value = QuestNumber.literal(2)
	node.condition_set.condition_list.append(condition)
	QuestGraphOps.rename_counter(quest, "wolves", "hounds")
	assert_eq(condition.counter_name, "hounds", "condition follows the rename")
	assert_eq(quest.counter_list[0].name, "hounds", "counter renamed")
