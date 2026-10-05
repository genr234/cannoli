extends QuestsTest


class Emitter:
	extends Node
	signal fired(value: int)
	signal plain


class Listener:
	extends RefCounted
	var received: Array[QuestMessageArgs] = []

	func on_message(args: QuestMessageArgs) -> void:
		received.append(args)


func before_each() -> void:
	make_manager()


func _prefab() -> PackedScene:
	var path := "user://quests_test_prefab.tscn"
	var content := Node3D.new()
	content.name = "Wolf"
	var scene := PackedScene.new()
	scene.pack(content)
	content.free()
	ResourceSaver.save(scene, path)
	return load(path) as PackedScene


func _prefab_2d() -> PackedScene:
	var path := "user://quests_test_prefab_2d.tscn"
	var content := Node2D.new()
	content.name = "Rat"
	var scene := PackedScene.new()
	scene.pack(content)
	content.free()
	ResourceSaver.save(scene, path)
	return load(path) as PackedScene


func _spawned(spawner: QuestSpawner) -> Array[Node]:
	var result: Array[Node] = []
	for child in spawner.get_children():
		if child is Node3D or child is Node2D:
			if child is Marker3D or child is Marker2D:
				continue
			result.append(child)
	return result


func test_spawner_radius_3d() -> void:
	var base := Node3D.new()
	base.position = Vector3(100, 0, 50)
	add_node(base)
	var spawner := QuestSpawner.new()
	spawner.spawner_name = "wolves"
	spawner.prefabs = [_prefab()]
	spawner.min_count = 3
	spawner.radius = 5.0
	base.add_child(spawner)
	spawner.start_spawning()
	var wolves := _spawned(spawner)
	assert_eq(wolves.size(), 3)
	assert_eq(spawner.spawn_count, 3)
	assert_eq(spawner.spawned_entities.size(), 3)
	for wolf in wolves:
		var offset: Vector3 = wolf.global_position - base.global_position
		assert_true(absf(offset.x) <= 5.0 and absf(offset.z) <= 5.0 and offset.y == 0.0, "within radius on the X-Z plane")
		assert_not_null(wolf.get_node_or_null("QuestSpawnedEntity"))
	assert_eq(QuestSpawner.find_spawner("wolves"), spawner)
	# Freeing one makes room again.
	wolves[0].free()
	assert_eq(spawner.spawn_count, 2)
	assert_eq(spawner.spawned_entities.size(), 2)
	spawner.start_spawning()
	assert_eq(_spawned(spawner).size(), 3, "refills up to the minimum")


func test_spawner_messages_start_and_despawn() -> void:
	var spawner := QuestSpawner.new()
	spawner.spawner_name = "rats"
	spawner.prefabs = [_prefab_2d()]
	spawner.min_count = 2
	add_node(spawner)
	await frames(1)
	assert_eq(_spawned(spawner).size(), 0, "waits to be started")
	QuestMessages.start_spawner("rats")
	assert_eq(_spawned(spawner).size(), 2)
	QuestMessages.start_spawner("other")
	assert_eq(_spawned(spawner).size(), 2, "other spawner's message ignored")
	QuestMessages.despawn_spawner("rats")
	assert_eq(spawner.spawn_count, 0)
	await frames(2)
	assert_eq(_spawned(spawner).size(), 0, "despawned entities are freed")


func test_spawner_spawnpoints_2d() -> void:
	var base := Node2D.new()
	add_node(base)
	var spawner := QuestSpawner.new()
	spawner.prefabs = [_prefab_2d()]
	spawner.position_type = QuestSpawner.PositionType.SPAWNPOINTS
	spawner.min_count = 5
	for position in [Vector2(10, 10), Vector2(50, 50)]:
		var marker := Marker2D.new()
		marker.position = position
		spawner.add_child(marker)
	base.add_child(spawner)
	spawner.start_spawning()
	var rats := _spawned(spawner)
	assert_eq(rats.size(), 2, "one per spawn point")
	var positions: Array[Vector2] = []
	for rat in rats:
		positions.append((rat as Node2D).global_position)
	assert_true(positions.has(Vector2(10, 10)) and positions.has(Vector2(50, 50)))


func test_spawner_keeps_spawning_to_max() -> void:
	var spawner := QuestSpawner.new()
	spawner.prefabs = [_prefab_2d()]
	spawner.min_count = 1
	spawner.max_count = 3
	spawner.spawn_rate = 0.05
	spawner.stop_when_min_reached = false
	spawner.auto_start = true
	add_node(spawner)
	await root.get_tree().create_timer(0.5).timeout
	assert_eq(spawner.spawn_count, 3)
	spawner.stop_spawning()


func test_spawner_weights() -> void:
	var spawner := QuestSpawner.new()
	spawner.prefabs = [_prefab(), _prefab_2d()]
	spawner.prefab_weights = PackedFloat32Array([0.0, 1.0])
	spawner.min_count = 4
	add_node(spawner)
	spawner.start_spawning()
	for node in _spawned(spawner):
		assert_true(node is Node2D, "zero-weight prefab never spawns")


func test_spawner_save_and_restore() -> void:
	var spawner := QuestSpawner.new()
	spawner.spawner_name = "saved"
	spawner.prefabs = [_prefab_2d()]
	spawner.min_count = 2
	add_node(spawner)
	spawner.start_spawning()
	var data := spawner.record_data()
	assert_eq(data["entities"].size(), 2)
	spawner.despawn_all()
	await frames(2)
	spawner.apply_data(data)
	assert_eq(_spawned(spawner).size(), 2)
	assert_eq(spawner.spawn_count, 2)


func test_spawned_entity() -> void:
	var spawner := QuestSpawner.new()
	spawner.spawner_name = "ent"
	add_node(spawner)
	var holder := Node2D.new()
	spawner.add_child(holder)
	var entity := QuestSpawnedEntity.new()
	holder.add_child(entity)
	assert_eq(entity.get_spawned_node(), holder)
	entity.apply_data("ent")
	assert_eq(spawner.spawn_count, 1)
	assert_eq(entity.record_data(), "ent")
	holder.free()
	assert_eq(spawner.spawn_count, 0)


func _indicator() -> QuestIndicator:
	var indicator := QuestIndicator.new()
	for child_name in ["Offer", "OfferDisabled", "Talk", "Custom0"]:
		var node := Node3D.new()
		node.name = child_name
		node.visible = false
		indicator.add_child(node)
	return indicator


func test_indicator_shows_children_by_state_name() -> void:
	var indicator := _indicator()
	add_node(indicator)
	indicator.set_indicator(Quest.IndicatorState.OFFER, true)
	assert_true((indicator.get_node("Offer") as Node3D).visible)
	assert_false((indicator.get_node("Talk") as Node3D).visible)
	indicator.set_indicator(Quest.IndicatorState.OFFER_DISABLED, true)
	indicator.set_indicator(Quest.IndicatorState.CUSTOM_0, true)
	assert_true((indicator.get_node("OfferDisabled") as Node3D).visible, "names ignore underscores")
	assert_true((indicator.get_node("Custom0") as Node3D).visible)
	indicator.hide_all_indicators()
	for child in indicator.get_children():
		assert_false((child as Node3D).visible)
	assert_eq(indicator.get_indicator_node(Quest.IndicatorState.NONE), null)


func test_indicator_assigned_nodes_and_2d() -> void:
	var indicator := QuestIndicator.new()
	var mark := Sprite2D.new()
	var custom := Control.new()
	indicator.add_child(mark)
	indicator.add_child(custom)
	indicator.interact = mark
	indicator.custom = [null, custom]
	add_node(indicator)
	indicator.set_indicator(Quest.IndicatorState.INTERACT, true)
	assert_true(mark.visible)
	indicator.set_indicator(Quest.IndicatorState.CUSTOM_1, false)
	assert_false(custom.visible)
	indicator.hide_all_indicators()
	assert_false(mark.visible)
	assert_eq(mark.process_mode, Node.PROCESS_MODE_DISABLED)


func _make_character(id: String) -> Node:
	var character := Node3D.new()
	character.name = "Elder"
	var identity := QuestIdentity.new()
	identity.id = id
	character.add_child(identity)
	return character


func test_indicator_manager_messages_and_priority() -> void:
	var character := _make_character("elder")
	var manager := QuestIndicatorManager.new()
	var indicator := _indicator()
	manager.add_child(indicator)
	character.add_child(manager)
	add_node(character)
	await frames(2)
	assert_eq(manager.get_entity_id(), "elder")
	assert_eq(manager.get_highest_priority_state(), Quest.IndicatorState.NONE)
	QuestMessages.set_indicator_state(null, "elder", "quest_a", Quest.IndicatorState.OFFER)
	assert_true((indicator.get_node("Offer") as Node3D).visible)
	QuestMessages.set_indicator_state(null, "elder", "quest_b", Quest.IndicatorState.CUSTOM_0)
	assert_eq(manager.get_highest_priority_state(), Quest.IndicatorState.CUSTOM_0, "highest index wins")
	assert_false((indicator.get_node("Offer") as Node3D).visible)
	assert_true((indicator.get_node("Custom0") as Node3D).visible)
	QuestMessages.set_indicator_state(null, "someone_else", "quest_c", Quest.IndicatorState.TALK)
	assert_false((indicator.get_node("Talk") as Node3D).visible, "message for another entity ignored")
	# A quest replaces its own earlier state.
	QuestMessages.set_indicator_state(null, "elder", "quest_b", Quest.IndicatorState.NONE)
	assert_eq(manager.get_highest_priority_state(), Quest.IndicatorState.OFFER)


func test_indicator_manager_save_data() -> void:
	var character := _make_character("elder")
	var manager := QuestIndicatorManager.new()
	var indicator := _indicator()
	manager.add_child(indicator)
	character.add_child(manager)
	add_node(character)
	await frames(2)
	manager.set_indicator_state("quest_a", Quest.IndicatorState.TALK)
	var data := manager.record_data()
	manager.set_indicator_state("quest_a", Quest.IndicatorState.NONE)
	assert_eq(manager.get_highest_priority_state(), Quest.IndicatorState.NONE)
	manager.apply_data(data)
	assert_eq(manager.get_highest_priority_state(), Quest.IndicatorState.TALK)
	assert_true((indicator.get_node("Talk") as Node3D).visible)
	assert_eq(data["states"][Quest.IndicatorState.TALK], ["quest_a"])


func test_indicator_manager_refreshes_from_quests() -> void:
	var journal := PartsTestUtil.make_journal(self)
	var character := _make_character("elder")
	var giver := QuestGiver.new()
	giver.id = "elder"
	var asset := PartsTestUtil.make_quest("fetch")
	giver.quests = [asset]
	character.add_child(giver)
	var manager := QuestIndicatorManager.new()
	var indicator := _indicator()
	manager.add_child(indicator)
	character.add_child(manager)
	add_node(character)
	await frames(3)
	assert_eq(manager.get_highest_priority_state(), Quest.IndicatorState.OFFER, "giver has a quest to offer")
	assert_true((indicator.get_node("Offer") as Node3D).visible)
	Quests.give_quest_to_quester(asset, journal)
	QuestMessages.refresh_indicator(null, "elder")
	await frames(3)
	assert_eq(manager.get_highest_priority_state(), Quest.IndicatorState.NONE, "player already has it")
	assert_false((indicator.get_node("Offer") as Node3D).visible)


func test_signal_relay_forwards_signal_with_argument() -> void:
	var emitter := Emitter.new()
	add_node(emitter)
	var relay := QuestSignalRelay.new()
	relay.message = "Ding"
	relay.parameter = "bell"
	relay.value_source = QuestSignalRelay.ValueSource.SIGNAL_ARGUMENT
	relay.sender_id = "tower"
	relay.source = emitter
	relay.signal_name = &"fired"
	add_node(relay)
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "Ding", "bell", listener.on_message)
	emitter.fired.emit(9)
	assert_eq(listener.received.size(), 1)
	assert_eq(listener.received[0].first_value(), 9)
	assert_eq(listener.received[0].get_sender_id(), "tower")


func test_signal_relay_literal_value_once_and_manual_connection() -> void:
	var emitter := Emitter.new()
	add_node(emitter)
	var relay := QuestSignalRelay.new()
	relay.message = "Ping"
	relay.value_source = QuestSignalRelay.ValueSource.LITERAL
	relay.value = QuestMessageValue.from_string("hello")
	relay.once = true
	add_node(relay)
	emitter.plain.connect(relay.relay)
	emitter.fired.connect(relay.relay)
	var listener := Listener.new()
	QuestMessages.add_listener(listener, "Ping", "", listener.on_message)
	emitter.plain.emit()
	emitter.fired.emit(1)
	assert_eq(listener.received.size(), 1, "once")
	assert_eq(listener.received[0].first_value(), "hello")
	relay.enabled = false
	relay.once = false
	relay.trigger()
	assert_eq(listener.received.size(), 1, "disabled")
	relay.enabled = true
	relay.trigger()
	assert_eq(listener.received.size(), 2)


func test_signal_relay_drives_message_condition() -> void:
	var emitter := Emitter.new()
	add_node(emitter)
	var relay := QuestSignalRelay.new()
	relay.message = "Gate Opened"
	relay.source = emitter
	relay.signal_name = &"plain"
	add_node(relay)
	var condition := QuestMessageCondition.new()
	condition.message = "Gate Opened"
	condition.set_runtime_references(PartsTestUtil.make_quest("q"), null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	await frames(2)
	emitter.plain.emit()
	assert_eq(hits.count, 1)
