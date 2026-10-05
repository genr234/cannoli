extends QuestsTest
## Parity checks for scene components: saving spawners and indicators, data sync.


func _prefab_2d() -> PackedScene:
	var path := "user://quests_test_prefab_audit.tscn"
	var content := Node2D.new()
	content.name = "Rat"
	var scene := PackedScene.new()
	scene.pack(content)
	content.free()
	ResourceSaver.save(scene, path)
	return load(path) as PackedScene


func test_manager_saves_and_restores_spawners() -> void:
	var manager := make_manager()
	var spawner := QuestSpawner.new()
	spawner.spawner_name = "rats_save"
	spawner.prefabs = [_prefab_2d()]
	spawner.min_count = 2
	add_node(spawner)
	spawner.start_spawning()
	assert_eq(spawner.spawn_count, 2)
	var data := manager.record_data()
	assert_true(data.spawners.has("rats_save"), "spawner is in the saved data")
	assert_eq(data.spawners["rats_save"].entities.size(), 2)
	spawner.despawn_all()
	assert_eq(spawner.spawn_count, 0)
	manager.apply_data(data)
	assert_eq(spawner.spawn_count, 2, "entities are restored")
	assert_eq(spawner.spawned_entities.size(), 2)


func test_manager_saves_indicator_states() -> void:
	var manager := make_manager()
	var host := Node.new()
	var indicator_manager := QuestIndicatorManager.new()
	host.add_child(indicator_manager)
	add_node(host)
	indicator_manager._my_id = "npc_audit"
	indicator_manager.set_indicator_state("q1", Quest.IndicatorState.TALK)
	var data := manager.record_data()
	assert_true(data.indicators.has("npc_audit"))
	indicator_manager._initialize_states()
	manager.apply_data(data)
	assert_eq(indicator_manager.states[Quest.IndicatorState.TALK], PackedStringArray(["q1"]))


func test_data_synchronizer_round_trip() -> void:
	make_manager()
	var counter := QuestCounter.create("gold", 0, 0, 1000, QuestCounter.UpdateMode.DATA_SYNC)
	var quest := Quest.create("sync_q")
	quest.counter_list.append(counter)
	var instance := make_quest_instance(quest)
	counter = instance.get_counter("gold")
	counter.set_listeners(true)
	var sync := QuestDataSynchronizer.new()
	sync.data_source_name = "gold"
	add_node(sync)
	var requests := []
	sync.request_data_source_change_value.connect(func(value: Variant) -> void: requests.append(value))
	sync.data_source_value_changed(250)
	assert_eq(counter.current_value, 250, "counter follows the data source")
	assert_eq(requests.size(), 0)
	counter.set_value(10)
	assert_eq(requests, [10], "counter changes are requested from the source")
