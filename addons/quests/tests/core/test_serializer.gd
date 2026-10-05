extends QuestsTest

var journal: QuestJournal


func before_each() -> void:
	make_manager()
	journal = QuestTestHelpers.make_journal(self)


func _rich_asset() -> Quest:
	var asset := QuestTestHelpers.chain("rich", [QuestTestHelpers.condition_node("task", 2, QuestConditionSet.Mode.MIN),
			QuestTestHelpers.node("done", QuestNode.Type.SUCCESS)])
	asset.title = "Rich {#count}"
	asset.group = "Main"
	asset.labels = PackedStringArray(["a", "b"])
	asset.is_procedurally_generated = true
	asset.requires_quests = PackedStringArray(["other"])
	asset.time_limit = 90.0
	asset.cooldown_seconds = 12.0
	asset.max_times = 4
	asset.icon = load("res://addons/quests/icon.svg") as Texture2D
	asset.tag_dictionary["{ITEM}"] = "key"
	var counter := QuestCounter.create("count", 1, 0, 9)
	counter.display_name = "Things"
	counter.objective_goal = QuestNumber.from_counter("count", QuestNumber.ValueType.COUNTER_MAX_VALUE)
	counter.message_event_list.append(QuestCounterMessageEvent.create("Found", "thing", QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE, 2))
	asset.counter_list.append(counter)
	asset.offer_content_list.append(QuestTestContent.make("Take it"))
	var action := QuestTestRichAction.new()
	action.text = "hello"
	action.amount = 8
	action.ratio = 0.5
	action.flag = false
	action.position = Vector2(3, 4)
	action.tint = Color.RED
	action.names = PackedStringArray(["x", "y"])
	action.number = QuestNumber.literal(5)
	action.value = QuestMessageValue.from_string("v")
	action.texture = load("res://addons/quests/icon.svg") as Texture2D
	action.mapping = {"k": 1, "j": "two"}
	action.kind = QuestNode.Type.FAILURE
	var inner := QuestTestAction.new()
	inner.label = "inner"
	action.nested.append(inner)
	asset.get_state_info(Quest.State.ACTIVE).action_list.append(action)
	asset.get_node("task").get_state_info(QuestNode.State.TRUE).journal_content.append(QuestTestContent.make("done {ITEM}"))
	asset.get_node("task").join_mode = QuestNode.JoinMode.MIN
	asset.get_node("task").join_min_count = 2
	asset.get_node("task").speaker = "guard"
	asset.get_node("task").tag_dictionary["{N}"] = "node tag"
	asset.get_node("task").is_optional = true
	return asset


func _assert_json_safe(value: Variant, path := "root") -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			pass
		TYPE_ARRAY:
			for i in value.size():
				_assert_json_safe(value[i], "%s[%d]" % [path, i])
		TYPE_DICTIONARY:
			for key in value:
				assert_eq(typeof(key), TYPE_STRING, "%s has a non-string key" % path)
				_assert_json_safe(value[key], "%s.%s" % [path, key])
		_:
			assert_true(false, "%s holds a %s" % [path, type_string(typeof(value))])


func _through_json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func test_state_round_trip() -> void:
	var asset := QuestTestHelpers.chain("q", [QuestTestHelpers.condition_node("task", 2), QuestTestHelpers.node("done", QuestNode.Type.SUCCESS)])
	asset.counter_list.append(QuestCounter.create("c", 0, 0, 20))
	asset.time_limit = 50.0
	var quest := journal.add_quest(asset)
	quest.assign_quester(QuestParticipant.new("player", "Hero"))
	quest.set_state(Quest.State.ACTIVE)
	quest.get_counter("c").set_value(7)
	QuestTestHelpers.test_condition(quest, "task", 1).fire()
	quest.times_accepted = 3
	quest.show_in_track_hud = false
	quest.set_indicator_state("npc", Quest.IndicatorState.TALK)
	var data := QuestSerializer.state_to_dict(quest)
	_assert_json_safe(data)
	data = _through_json(data)
	var fresh := make_quest_instance(asset)
	QuestSerializer.apply_state(fresh, data)
	assert_eq(fresh.get_state(), Quest.State.ACTIVE)
	assert_eq(fresh.get_counter("c").current_value, 7)
	assert_eq(fresh.times_accepted, 3)
	assert_false(fresh.show_in_track_hud)
	assert_eq(fresh.quester_id, "player")
	assert_eq(fresh.get_node("task").get_state(), QuestNode.State.ACTIVE)
	assert_eq(fresh.get_node("q.start" if false else "done").get_state(), QuestNode.State.INACTIVE)
	assert_eq(fresh.get_start_node().get_state(), QuestNode.State.TRUE)
	assert_false(QuestTestHelpers.test_condition(fresh, "task", 0).already_true)
	assert_true(QuestTestHelpers.test_condition(fresh, "task", 1).already_true)
	assert_eq(fresh.get_node("task").condition_set.num_true_conditions, 1)
	assert_eq(fresh.get_indicator_state("npc"), Quest.IndicatorState.TALK)
	assert_almost_eq(fresh.time_remaining, 50.0)
	# The restored quest keeps working: the remaining condition finishes it.
	assert_true(QuestTestHelpers.test_condition(fresh, "task", 0).is_checking, "active nodes check their conditions again")
	QuestTestHelpers.test_condition(fresh, "task", 0).fire()
	assert_eq(fresh.get_state(), Quest.State.SUCCESSFUL)


func test_waiting_quest_saves_only_the_basics() -> void:
	var asset := QuestTestHelpers.counter_quest("q", "c")
	var quest := journal.add_quest(asset)
	quest.get_counter("c").set_value(4)
	var data := QuestSerializer.state_to_dict(quest)
	assert_false(data.has("counters"))
	assert_false(data.has("nodes"))
	assert_eq(data.state, Quest.State.WAITING_TO_START)
	quest.save_all_if_waiting_to_start = true
	data = QuestSerializer.state_to_dict(quest)
	assert_eq(data.counters, {"c": 4})
	assert_true(data.has("nodes"))
	var fresh := make_quest_instance(asset)
	QuestSerializer.apply_state(fresh, _through_json(QuestSerializer.state_to_dict(quest)))
	assert_eq(fresh.get_state(), Quest.State.WAITING_TO_START)
	assert_eq(fresh.get_counter("c").current_value, 4)


func test_apply_state_ignores_unknown_counters_and_nodes() -> void:
	var asset := QuestTestHelpers.counter_quest("q", "c")
	var fresh := make_quest_instance(asset)
	QuestSerializer.apply_state(fresh, {"state": Quest.State.FAILED, "counters": {"gone": 3}, "nodes": [{"id": "nope", "state": 2}]})
	assert_eq(fresh.get_state(), Quest.State.FAILED)
	assert_eq(fresh.get_counter("c").current_value, 0)


func test_full_quest_round_trip() -> void:
	var asset := _rich_asset()
	var quest := make_quest_instance(asset)
	quest.assign_quester(QuestParticipant.new("player", "Hero"))
	quest.set_state(Quest.State.ACTIVE)
	quest.get_counter("count").set_value(5)
	var data := QuestSerializer.quest_to_dict(quest)
	_assert_json_safe(data)
	data = _through_json(data)
	var copy := track_quest(QuestSerializer.dict_to_quest(data))
	assert_not_null(copy)
	assert_true(copy.is_instance)
	assert_eq(copy.id, "rich")
	assert_eq(copy.title, "Rich {#count}")
	assert_eq(copy.group, "Main")
	assert_eq(copy.labels, PackedStringArray(["a", "b"]))
	assert_true(copy.is_procedurally_generated)
	assert_eq(copy.requires_quests, PackedStringArray(["other"]))
	assert_almost_eq(copy.time_limit, 90.0)
	assert_almost_eq(copy.cooldown_seconds, 12.0)
	assert_eq(copy.max_times, 4)
	assert_eq(copy.icon.resource_path, "res://addons/quests/icon.svg")
	assert_eq(copy.tag_dictionary["{ITEM}"], "key")
	assert_eq(copy.node_list.size(), 3)
	assert_eq(copy.get_node("task").node_type, QuestNode.Type.CONDITION)
	assert_eq(copy.get_node("task").join_mode, QuestNode.JoinMode.MIN)
	assert_eq(copy.get_node("task").join_min_count, 2)
	assert_eq(copy.get_node("task").speaker, "guard")
	assert_true(copy.get_node("task").is_optional)
	assert_eq(copy.get_node("task").tag_dictionary["{N}"], "node tag")
	assert_eq(copy.get_start_node().children, PackedStringArray(["task"]))
	assert_eq(copy.get_node("task").condition_set.condition_count_mode, QuestConditionSet.Mode.MIN)
	assert_eq(copy.get_node("task").condition_set.condition_list.size(), 2)
	assert_true(copy.get_node("task").condition_set.condition_list[0] is QuestTestCondition)
	assert_eq(copy.get_node("task").child_list[0].id, "done", "runtime references are wired")
	var counter := copy.get_counter("count")
	assert_eq(counter.current_value, 5, "runtime state is restored")
	assert_eq(counter.display_name, "Things")
	assert_eq(counter.objective_goal.value_type, QuestNumber.ValueType.COUNTER_MAX_VALUE)
	assert_eq(counter.objective_goal.counter_name, "count")
	assert_eq(counter.message_event_list.size(), 1)
	assert_eq(counter.message_event_list[0].message, "Found")
	assert_eq(counter.message_event_list[0].literal_value, 2)
	assert_eq(copy.get_state(), Quest.State.ACTIVE)
	assert_eq(copy.quester_id, "player")
	assert_eq((copy.offer_content_list[0] as QuestTestContent).text, "Take it")
	assert_eq(copy.get_node("task").get_state_info(QuestNode.State.TRUE).journal_content.size(), 1)
	var action := copy.get_state_info(Quest.State.ACTIVE).action_list[0] as QuestTestRichAction
	assert_not_null(action)
	assert_eq(action.text, "hello")
	assert_eq(action.amount, 8)
	assert_eq(typeof(action.amount), TYPE_INT)
	assert_almost_eq(action.ratio, 0.5)
	assert_false(action.flag)
	assert_eq(action.position, Vector2(3, 4))
	assert_eq(action.tint, Color.RED)
	assert_eq(action.names, PackedStringArray(["x", "y"]))
	assert_eq(action.number.literal_value, 5)
	assert_eq(action.value.string_value, "v")
	assert_eq(action.value.value_type, QuestMessageValue.ValueType.STRING)
	assert_eq(action.texture.resource_path, "res://addons/quests/icon.svg")
	assert_eq(action.mapping.size(), 2)
	assert_eq(action.mapping["k"], 1, "JSON turns the number into a float, which still equals 1")
	assert_eq(action.mapping["j"], "two")
	assert_eq(action.kind, QuestNode.Type.FAILURE)
	assert_eq(action.nested.size(), 1)
	assert_eq((action.nested[0] as QuestTestAction).label, "inner")
	assert_eq(action.quest, copy, "references are wired to the restored quest")


func test_full_quest_keeps_working() -> void:
	var asset := QuestTestHelpers.simple_quest("gen")
	asset.is_procedurally_generated = true
	var quest := make_quest_instance(asset)
	quest.set_state(Quest.State.ACTIVE)
	var copy := track_quest(QuestSerializer.dict_to_quest(_through_json(QuestSerializer.quest_to_dict(quest))))
	assert_eq(copy.get_state(), Quest.State.ACTIVE)
	assert_eq(copy.get_node("task").get_state(), QuestNode.State.ACTIVE)
	QuestTestHelpers.test_condition(copy, "task").fire()
	assert_eq(copy.get_state(), Quest.State.SUCCESSFUL)


func test_dict_to_quest_rejects_bad_data() -> void:
	assert_null(QuestSerializer.dict_to_quest({}))
	assert_null(QuestSerializer.dict_to_quest({"definition": {"type": "NoSuchClassAnywhere", "props": {}}}))


func test_value_encoding() -> void:
	assert_eq(QuestSerializer.encode_value(&"sn"), "sn")
	assert_eq(QuestSerializer.decode_value(QuestSerializer.encode_value(Vector3(1, 2, 3))), Vector3(1, 2, 3))
	assert_eq(QuestSerializer.decode_value(QuestSerializer.encode_value([1, [2, "x"], {"a": Vector2.ONE}])), [1, [2, "x"], {"a": Vector2.ONE}])
	assert_null(QuestSerializer.encode_resource(null))
	var number: QuestNumber = QuestSerializer.decode_resource(QuestSerializer.encode_resource(QuestNumber.literal(9)))
	assert_eq(number.literal_value, 9)
