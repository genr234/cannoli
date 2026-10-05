extends QuestsTest


class Listener:
	extends RefCounted
	var received: Array[QuestMessageArgs] = []

	func on_message(args: QuestMessageArgs) -> void:
		received.append(args)


func test_message_and_parameter_filtering() -> void:
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "Hello", "world", listener.on_message)
	QuestMessages.send(null, null, "Hello", "world")
	QuestMessages.send(null, null, "Hello", "moon")
	QuestMessages.send(null, null, "Other", "world")
	QuestMessages.send(null, null, "Hello", "")
	assert_eq(listener.received.size(), 1)
	assert_eq(listener.received[0].parameter, "world")


func test_empty_parameter_receives_everything() -> void:
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "Hello", "", listener.on_message)
	QuestMessages.send(null, null, "Hello", "a")
	QuestMessages.send(null, null, "Hello", "b")
	QuestMessages.send(null, null, "Hello")
	QuestMessages.send(null, null, "Bye")
	assert_eq(listener.received.size(), 3)


func test_args_content() -> void:
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "Give", "", listener.on_message)
	QuestMessages.send("alice", "bob", "Give", "coin", [5, "gold"])
	var args := listener.received[0]
	assert_eq(args.sender, "alice")
	assert_eq(args.target, "bob")
	assert_eq(args.message, "Give")
	assert_eq(args.values, [5, "gold"])
	assert_eq(args.first_value(), 5)
	assert_eq(args.int_value(), 5)
	assert_eq(args.get_sender_id(), "alice")
	assert_eq(args.get_target_id(), "bob")
	assert_true(args.is_sender("alice"))
	assert_true(args.is_sender(""))
	assert_false(args.is_sender("bob"))
	assert_true(args.is_target("bob"))
	assert_false(args.is_target("alice"))
	assert_true(args.has_target())
	assert_true(args.matches("Give", "coin"))
	assert_true(args.matches("Give"))
	assert_false(args.matches("Give", "gem"))


func test_args_without_values() -> void:
	var args := QuestMessageArgs.new(null, null, "M", "")
	assert_null(args.first_value())
	assert_eq(args.int_value(), 0)
	assert_false(args.has_target())
	assert_eq(args.get_sender_id(), "")


func test_remove_listener() -> void:
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "A", "", listener.on_message)
	QuestMessages.add_listener(listener, "B", "x", listener.on_message)
	QuestMessages.add_listener(listener, "B", "y", listener.on_message)
	QuestMessages.remove_listener(listener, "B", "x")
	QuestMessages.send(null, null, "B", "x")
	QuestMessages.send(null, null, "B", "y")
	assert_eq(listener.received.size(), 1)
	QuestMessages.remove_listener(listener, "A")
	QuestMessages.send(null, null, "A")
	assert_eq(listener.received.size(), 1)
	QuestMessages.remove_listener(listener)
	QuestMessages.send(null, null, "B", "y")
	assert_eq(listener.received.size(), 1)
	assert_eq(QuestMessages.get_listener_count(), 0)


func test_duplicate_registration_is_ignored() -> void:
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "A", "", listener.on_message)
	QuestMessages.add_listener(listener, "A", "", listener.on_message)
	QuestMessages.send(null, null, "A")
	assert_eq(listener.received.size(), 1)
	assert_true(QuestMessages.is_listener_registered(listener, "A", "any"))
	assert_false(QuestMessages.is_listener_registered(listener, "B"))


func test_removing_a_listener_while_sending() -> void:
	var first := Listener.new()
	var second := Listener.new()
	QuestMessages.add_listener(first, "A", "", func(args: QuestMessageArgs) -> void:
		first.received.append(args)
		QuestMessages.remove_listener(second))
	QuestMessages.add_listener(second, "A", "", second.on_message)
	QuestMessages.send(null, null, "A")
	assert_eq(first.received.size(), 1)
	assert_eq(second.received.size(), 0, "removed before its turn")
	assert_eq(QuestMessages.get_listener_count(), 1)


func test_listener_added_while_sending_hears_the_same_message() -> void:
	var late := Listener.new()
	var early := Listener.new()
	QuestMessages.add_listener(early, "A", "", func(args: QuestMessageArgs) -> void:
		early.received.append(args)
		QuestMessages.add_listener(late, "A", "", late.on_message))
	QuestMessages.send(null, null, "A")
	assert_eq(late.received.size(), 1)


func test_same_frame_listeners_can_be_deferred() -> void:
	QuestMessages.allow_receive_same_frame_added = false
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "A", "", listener.on_message)
	QuestMessages.send(null, null, "A")
	assert_eq(listener.received.size(), 0)
	await frames(2)
	QuestMessages.send(null, null, "A")
	assert_eq(listener.received.size(), 1)


func test_freed_listeners_are_dropped() -> void:
	var node := Node.new()
	var hits := [0]
	QuestMessages.add_listener(node, "A", "", func(_args: QuestMessageArgs) -> void: hits[0] += 1)
	node.free()
	QuestMessages.send(null, null, "A")
	assert_eq(hits[0], 0)
	assert_eq(QuestMessages.get_listener_count(), 0)


func test_send_composite() -> void:
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "Get", "", listener.on_message)
	QuestMessages.send_composite(null, "Get")
	QuestMessages.send_composite(null, "Get:Coin")
	QuestMessages.send_composite(null, "Get:Coin:5")
	QuestMessages.send_composite(null, "Get:Coin:five")
	QuestMessages.send_composite(null, "")
	assert_eq(listener.received.size(), 4)
	assert_eq(listener.received[0].parameter, "")
	assert_eq(listener.received[1].parameter, "Coin")
	assert_eq(listener.received[1].values, [])
	assert_eq(listener.received[2].values, [5])
	assert_eq(listener.received[3].values, ["five"])


func test_get_id() -> void:
	assert_eq(QuestMessages.get_id(null), "")
	assert_eq(QuestMessages.get_id("abc"), "abc")
	assert_eq(QuestMessages.get_id(&"sn"), "sn")
	var quest := Quest.create("q1")
	assert_eq(QuestMessages.get_id(quest), "q1")
	var character := add_node(Node3D.new())
	character.name = "Guard"
	assert_eq(QuestMessages.get_id(character), "Guard", "falls back to the node name")
	var identity := QuestIdentity.new()
	identity.id = "guard_1"
	character.add_child(identity)
	assert_eq(QuestMessages.get_id(character), "guard_1")
	var child := Node.new()
	character.add_child(child)
	assert_eq(QuestMessages.get_id(child), "guard_1", "found on an ancestor")
	var list := QuestList.new()
	list.id = "list_1"
	character.add_child(list)
	assert_eq(QuestMessages.get_id(character), "list_1", "a quest list outranks an identity")
	assert_eq(QuestMessages.get_id(list), "list_1")
	assert_eq(QuestMessages.get_id(identity), "guard_1")


func test_get_id_with_custom_provider() -> void:
	var node := add_node(Node.new())
	node.set_script(preload("res://addons/quests/tests/core/quest_id_provider.gd"))
	assert_eq(QuestMessages.get_id(node), "provided_id")


func test_is_required_id() -> void:
	assert_true(QuestMessages.is_required_id("x", ""))
	assert_true(QuestMessages.is_required_id("x", "x"))
	assert_false(QuestMessages.is_required_id("x", "y"))
	assert_false(QuestMessages.is_required_id(null, "y"))
	assert_true(QuestMessages.is_required_id(null, ""))


func test_manager_message_sent_signal() -> void:
	var manager := make_manager()
	var seen: Array[String] = []
	manager.message_sent.connect(func(args: QuestMessageArgs) -> void: seen.append(args.message))
	QuestMessages.send(null, null, "Ping")
	assert_eq(seen, ["Ping"])


func test_helper_senders_use_documented_formats() -> void:
	var listener := Listener.new()
	for message in [QuestMessages.QUEST_ABANDONED, QuestMessages.QUEST_TRACK_TOGGLE_CHANGED, QuestMessages.REFRESH_UIS,
			QuestMessages.REFRESH_INDICATOR, QuestMessages.GREET, QuestMessages.GREETED, QuestMessages.DISCUSS_QUEST,
			QuestMessages.DISCUSSED_QUEST, QuestMessages.QUEST_ALERT, QuestMessages.SET_INDICATOR_STATE, QuestMessages.START_SPAWNER]:
		QuestMessages.add_listener(listener, message, "", listener.on_message)
	QuestMessages.quest_abandoned("s", "q")
	QuestMessages.quest_track_toggle_changed("s", "q", false)
	QuestMessages.refresh_uis("s")
	QuestMessages.refresh_indicator("s", "npc")
	QuestMessages.greet("player", "npc_node", "npc")
	QuestMessages.discuss_quest("player", "npc_node", "npc", "q")
	QuestMessages.start_spawner("wolves")
	var by_message := {}
	for args in listener.received:
		by_message[args.message] = args
	assert_eq(by_message[QuestMessages.QUEST_ABANDONED].parameter, "q")
	assert_eq(by_message[QuestMessages.QUEST_TRACK_TOGGLE_CHANGED].values, [false])
	assert_eq(by_message[QuestMessages.REFRESH_INDICATOR].parameter, "npc")
	assert_eq(by_message[QuestMessages.REFRESH_INDICATOR].get_target_id(), "npc")
	assert_eq(by_message[QuestMessages.GREET].parameter, "npc")
	assert_eq(by_message[QuestMessages.GREET].get_sender_id(), "player")
	assert_eq(by_message[QuestMessages.DISCUSS_QUEST].parameter, "q")
	assert_eq(by_message[QuestMessages.DISCUSS_QUEST].values, ["npc"])
	assert_eq(by_message[QuestMessages.START_SPAWNER].parameter, "wolves")
