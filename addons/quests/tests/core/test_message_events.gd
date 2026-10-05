extends QuestsTest


func _entry(message: String, parameter := "", sender_id := "", target_id := "") -> QuestMessageListenEntry:
	var entry := QuestMessageListenEntry.new()
	entry.message = message
	entry.parameter = parameter
	entry.required_sender_id = sender_id
	entry.required_target_id = target_id
	return entry


func test_listens_and_filters() -> void:
	var events := QuestMessageEvents.new()
	events.messages_to_listen_for = [_entry("Hello", "", "alice"), _entry("Bye", "now")] as Array[QuestMessageListenEntry]
	add_node(events)
	var heard: Array[int] = []
	events.message_received.connect(func(_a: QuestMessageArgs, i: int) -> void: heard.append(i))
	QuestMessages.send("bob", null, "Hello")
	QuestMessages.send("alice", null, "Hello")
	QuestMessages.send(null, null, "Bye", "later")
	QuestMessages.send(null, null, "Bye", "now")
	assert_eq(heard, [0, 1])


func test_stops_listening_when_removed() -> void:
	var events := QuestMessageEvents.new()
	events.messages_to_listen_for = [_entry("Hello")] as Array[QuestMessageListenEntry]
	add_node(events)
	var heard := [0]
	events.message_received.connect(func(_a: QuestMessageArgs, _i: int) -> void: heard[0] += 1)
	root.remove_child(events)
	QuestMessages.send(null, null, "Hello")
	assert_eq(heard[0], 0)
	root.add_child(events)
	QuestMessages.send(null, null, "Hello")
	assert_eq(heard[0], 1)


func test_required_node_participant() -> void:
	var holder := add_node(Node.new())
	var other := Node.new()
	other.name = "Other"
	holder.add_child(other)
	var events := QuestMessageEvents.new()
	var entry := _entry("Hit")
	entry.required_sender_path = NodePath("../Other")
	events.messages_to_listen_for = [entry] as Array[QuestMessageListenEntry]
	holder.add_child(events)
	var heard := [0]
	events.message_received.connect(func(_a: QuestMessageArgs, _i: int) -> void: heard[0] += 1)
	QuestMessages.send(holder, null, "Hit")
	assert_eq(heard[0], 0)
	QuestMessages.send(other, null, "Hit")
	assert_eq(heard[0], 1)


func test_sends_messages() -> void:
	var events := QuestMessageEvents.new()
	var by_id := QuestMessageSendEntry.new()
	by_id.target_id = "npc"
	by_id.message = "Poke"
	by_id.parameter = "hard"
	events.messages_to_send = [by_id] as Array[QuestMessageSendEntry]
	add_node(events)
	var heard: Array[QuestMessageArgs] = []
	QuestMessages.add_listener(self, "Poke", "", func(a: QuestMessageArgs) -> void: heard.append(a))
	events.send_to_message_system(0)
	events.send_to_message_system(5)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0].parameter, "hard")
	assert_eq(heard[0].get_target_id(), "npc")
	assert_eq(heard[0].sender, events)
