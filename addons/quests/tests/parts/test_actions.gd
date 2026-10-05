extends QuestsTest

var _journal: QuestJournal
var _manager: QuestManager


class Target:
	extends Node
	var calls: Array = []

	func record(a: Variant = null, b: Variant = null) -> void:
		calls.append([a, b])


class Listener:
	extends RefCounted
	var received: Array[QuestMessageArgs] = []

	func on_message(args: QuestMessageArgs) -> void:
		received.append(args)


func before_each() -> void:
	_manager = make_manager()
	_journal = PartsTestUtil.make_journal(self)


func _listen(message: String) -> Listener:
	var listener := Listener.new()
	QuestMessages.add_listener(listener, message, "", listener.on_message)
	return listener


func test_set_quest_state_action() -> void:
	var other := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("other"))
	var action := QuestSetQuestStateAction.new()
	action.quest_id = "other"
	action.state = Quest.State.ACTIVE
	action.set_runtime_references(PartsTestUtil.make_quest("q"), null)
	action.execute()
	assert_eq(other.get_state(), Quest.State.ACTIVE)
	assert_eq(action.get_editor_name(), "Set Quest State: Quest 'other' to Active")


func test_set_quest_state_action_this_quest_sets_nodes() -> void:
	var asset := PartsTestUtil.make_quest("q")
	asset.node_list.append(QuestNode.create("step", "Step", QuestNode.Type.PASSTHROUGH))
	var quest := PartsTestUtil.give(_journal, asset)
	var action := QuestSetQuestStateAction.new()
	action.state = Quest.State.SUCCESSFUL
	action.set_quest_nodes_to_same = true
	action.set_runtime_references(quest, null)
	action.execute()
	assert_eq(quest.get_state(), Quest.State.SUCCESSFUL)
	assert_eq(quest.get_node("step").get_state(), QuestNode.State.TRUE)
	assert_eq(action.get_editor_name(), "Set Quest State: Successful")


func test_set_node_state_action() -> void:
	var asset := PartsTestUtil.make_quest("q")
	asset.node_list.append(QuestNode.create("step", "Step", QuestNode.Type.CONDITION))
	var quest := PartsTestUtil.give(_journal, asset)
	var action := QuestSetNodeStateAction.new()
	action.node_id = "step"
	action.state = QuestNode.State.ACTIVE
	action.set_runtime_references(quest, null)
	action.execute()
	assert_eq(quest.get_node("step").get_state(), QuestNode.State.ACTIVE)
	var by_id := QuestSetNodeStateAction.new()
	by_id.quest_id = "q"
	by_id.node_id = "step"
	by_id.state = QuestNode.State.TRUE
	by_id.execute()
	assert_eq(quest.get_node("step").get_state(), QuestNode.State.TRUE)
	assert_eq(by_id.get_editor_name(), "Set Quest Node State: Quest 'q' Node 'step' to True")


func test_set_counter_action() -> void:
	var quest := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("q", ["n"]))
	var counter := quest.get_counter("n")
	var action := QuestSetCounterAction.new()
	action.counter_name = "n"
	action.operation_value = 5
	action.set_runtime_references(quest, null)
	action.execute()
	assert_eq(counter.current_value, 5)
	action.operation = QuestSetCounterAction.Operation.MODIFY_BY_VALUE
	action.operation_value = 3
	action.execute()
	assert_eq(counter.current_value, 8)
	action.operation = QuestSetCounterAction.Operation.RANDOMIZE
	action.operation_value = 20
	action.max_value = 22
	for i in 10:
		action.execute()
		assert_true(counter.current_value >= 20 and counter.current_value <= 22)
	assert_eq(action.get_editor_name(), "Set Counter: n to random in [20,22]")


func test_message_action() -> void:
	var quest := PartsTestUtil.make_quest("q")
	quest.quest_giver_id = "elder"
	quest.initialize()
	var listener := _listen("Hello")
	var action := QuestMessageAction.new()
	action.message = "Hello"
	action.parameter = "{QUESTGIVERID}"
	action.value = QuestMessageValue.from_int(4)
	action.set_runtime_references(quest, null)
	action.execute()
	assert_eq(listener.received.size(), 1)
	var args := listener.received[0]
	assert_eq(args.parameter, "elder")
	assert_eq(args.get_sender_id(), "elder", "default sender is the quest giver")
	assert_eq(args.first_value(), 4)
	assert_eq(action.get_editor_name(), "Message: Hello {QUESTGIVERID} 4")
	action.value = QuestMessageValue.from_string("hi {QUESTGIVERID}")
	action.execute()
	assert_eq(listener.received[1].first_value(), "hi elder")


func test_alert_action() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var body := QuestBodyContent.new()
	body.text = "Done"
	var action := QuestAlertAction.new()
	action.content_list.append(body)
	action.set_runtime_references(quest, null)
	assert_eq(body.quest, quest, "propagates runtime references")
	var received: Array = []
	_manager.quest_alert.connect(func(quest_id: String, contents: Array[QuestContent]) -> void: received.append([quest_id, contents]))
	action.execute()
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], "q")
	assert_eq(received[0][1][0], body)
	assert_eq(action.get_editor_name(), "Alert: Text: Done")


func test_set_indicator_and_tracking_actions() -> void:
	var quest := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("q"))
	var indicator := QuestSetIndicatorAction.new()
	indicator.entity_id = "elder"
	indicator.indicator_state = Quest.IndicatorState.TALK
	indicator.set_runtime_references(quest, null)
	indicator.execute()
	assert_eq(quest.get_indicator_state("elder"), Quest.IndicatorState.TALK)
	assert_eq(indicator.get_editor_name(), "Set Indicator:  elder Talk")
	var tracking := QuestSetTrackingAction.new()
	tracking.show_in_track_hud = false
	tracking.set_runtime_references(quest, null)
	tracking.execute()
	assert_false(quest.show_in_track_hud)
	var by_id := QuestSetTrackingAction.new()
	by_id.quest_id = "q"
	by_id.show_in_track_hud = true
	by_id.execute()
	assert_true(quest.show_in_track_hud)


func test_give_quest_action() -> void:
	var giver_quest := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("giver"))
	giver_quest.quest_giver_id = "elder"
	Quests.register_quest_asset(PartsTestUtil.make_quest("reward_quest"))
	var action := QuestGiveQuestAction.new()
	action.quest_id_to_give = "reward_quest"
	action.set_runtime_references(giver_quest, null)
	action.execute()
	var given := _journal.find_quest("reward_quest")
	assert_not_null(given)
	assert_eq(given.get_state(), Quest.State.ACTIVE)
	assert_eq(given.quest_giver_id, "elder")
	assert_eq(action.get_editor_name(), "Give Quest 'reward_quest' to Player")


func test_control_spawner_action() -> void:
	var listener := Listener.new()
	for message in [QuestMessages.START_SPAWNER, QuestMessages.STOP_SPAWNER, QuestMessages.DESPAWN_SPAWNER]:
		QuestMessages.add_listener(listener, message, "wolves", listener.on_message)
	var action := QuestControlSpawnerAction.new()
	action.spawner_name = "wolves"
	for state in [QuestControlSpawnerAction.ControlState.START, QuestControlSpawnerAction.ControlState.STOP, QuestControlSpawnerAction.ControlState.DESPAWN]:
		action.state = state
		action.execute()
	assert_eq(listener.received.size(), 3)
	assert_eq(listener.received[0].message, QuestMessages.START_SPAWNER)
	assert_eq(listener.received[1].message, QuestMessages.STOP_SPAWNER)
	assert_eq(listener.received[2].message, QuestMessages.DESPAWN_SPAWNER)
	assert_eq(action.get_editor_name(), "Control Spawner: Despawn wolves")


func test_call_method_action() -> void:
	var a := Target.new()
	a.add_to_group("doors")
	add_node(a)
	var b := Target.new()
	b.add_to_group("doors")
	add_node(b)
	var quest := PartsTestUtil.make_quest("q")
	quest.quest_giver_id = "elder"
	quest.initialize()
	var action := QuestCallMethodAction.new()
	action.target = "doors"
	action.method = "record"
	action.arguments = ["open", "{QUESTGIVERID}"]
	action.set_runtime_references(quest, null)
	action.execute()
	assert_eq(a.calls, [["open", "elder"]])
	assert_eq(b.calls, [["open", "elder"]])
	action.deferred = true
	action.execute()
	assert_eq(a.calls.size(), 1)
	await frames(1)
	assert_eq(a.calls.size(), 2)
	assert_eq(action.get_editor_name(), "Call Method: doors.record()")


func test_call_method_action_by_identity_and_child_path() -> void:
	var character := Node.new()
	character.name = "Elder"
	var identity := QuestIdentity.new()
	identity.id = "elder"
	character.add_child(identity)
	var inner := Target.new()
	inner.name = "Inner"
	character.add_child(inner)
	add_node(character)
	var action := QuestCallMethodAction.new()
	action.target = "elder"
	action.child_path = ^"Inner"
	action.method = "record"
	action.arguments = [1]
	action.execute()
	assert_eq(inner.calls, [[1, null]])
	action.target = "missing"
	action.execute()
	assert_eq(inner.calls.size(), 1)


func test_activate_node_action() -> void:
	var node := Node3D.new()
	node.add_to_group("props")
	add_node(node)
	var action := QuestActivateNodeAction.new()
	action.target = "props"
	action.state = false
	action.execute()
	assert_false(node.visible)
	assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED)
	action.state = true
	action.execute()
	assert_true(node.visible)
	assert_eq(node.process_mode, Node.PROCESS_MODE_INHERIT)
	action.state = false
	action.mode = QuestActivateNodeAction.Mode.VISIBILITY
	action.execute()
	assert_false(node.visible)
	assert_eq(node.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(action.get_editor_name(), "Deactivate Node: 'props'")


func test_instantiate_action() -> void:
	var root_2d := Node2D.new()
	add_node(root_2d)
	var marker := Marker2D.new()
	marker.position = Vector2(30, 40)
	marker.add_to_group("spawn_here")
	root_2d.add_child(marker)
	var content := Node2D.new()
	content.name = "Crate"
	var scene := PackedScene.new()
	scene.pack(content)
	content.free()
	var action := QuestInstantiateAction.new()
	action.scene = scene
	action.location = "spawn_here"
	action.parent = "spawn_here"
	action.use_original_name = true
	action.execute()
	var crate := marker.get_node_or_null("Crate") as Node2D
	assert_not_null(crate)
	assert_eq(crate.global_position, Vector2(30, 40))


func test_audio_action() -> void:
	var player := AudioStreamPlayer.new()
	player.add_to_group("speaker")
	add_node(player)
	var stream := AudioStreamWAV.new()
	var action := QuestAudioAction.new()
	action.audio = stream
	action.use_audio_source_on.type = QuestAudioSourceIdentifier.Type.NODE_WITH_GROUP
	action.use_audio_source_on.id = "speaker"
	action.interrupt_previous_clip = true
	action.execute()
	assert_eq(player.stream, stream)
	assert_eq(action.get_audio().size(), 1)
	action.interrupt_previous_clip = false
	var children_before := player.get_child_count()
	action.execute()
	assert_eq(player.get_child_count(), children_before + 1, "one-shot adds a temporary player")
	# A host without a player gets one.
	var host := Node.new()
	host.add_to_group("quiet")
	add_node(host)
	action.use_audio_source_on.id = "quiet"
	action.interrupt_previous_clip = true
	action.execute()
	var created := host.get_child(0) as AudioStreamPlayer
	assert_not_null(created)
	assert_eq(created.stream, stream)


func test_animation_action() -> void:
	var character := Node.new()
	character.add_to_group("hero")
	var animation_player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 1.0
	library.add_animation("wave", animation)
	animation_player.add_animation_library("", library)
	character.add_child(animation_player)
	var tree := AnimationTree.new()
	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node("Blend", AnimationNodeBlend2.new())
	tree.tree_root = blend_tree
	character.add_child(tree)
	add_node(character)
	tree.anim_player = tree.get_path_to(animation_player)
	var action := QuestAnimationAction.new()
	action.target_node = "hero"
	action.target = "wave"
	action.execute()
	assert_eq(str(animation_player.current_animation), "wave")
	action.action = QuestAnimationAction.AnimationControl.STOP
	action.execute()
	assert_eq(str(animation_player.current_animation), "")
	action.action = QuestAnimationAction.AnimationControl.SET_FLOAT
	action.target = "Blend/blend_amount"
	action.float_value = 0.75
	action.execute()
	assert_almost_eq(float(tree.get("parameters/Blend/blend_amount")), 0.75)
	assert_eq(action.get_editor_name(), "Animation on hero: Set Blend/blend_amount to 0.75")


func test_reward_action() -> void:
	var quest := PartsTestUtil.give(_journal, PartsTestUtil.make_quest("q", ["gold"]))
	quest.quest_giver_id = "elder"
	var listener := _listen(QuestRewardAction.REWARD_MESSAGE)
	var action := QuestRewardAction.new()
	action.reward_id = "gold"
	action.amount = 25
	action.counter_name = "gold"
	action.set_runtime_references(quest, null)
	action.execute()
	assert_eq(quest.get_counter("gold").current_value, 25)
	assert_eq(listener.received.size(), 1)
	assert_eq(listener.received[0].parameter, "gold")
	assert_eq(listener.received[0].first_value(), 25)
	assert_eq(action.get_editor_name(), "Reward: 25 gold")


func test_report_deed_action_without_actor_does_not_crash() -> void:
	var action := QuestReportDeedAction.new()
	action.deed_tag = "attack"
	action.actor = "nobody"
	action.target = "Villagers"
	action.execute()
	assert_eq(action.get_editor_name(), "Report Deed: nobody -> Villagers 'attack'")
