extends QuestsTest

var fx: QuestsGeneratorFixture


func before_each() -> void:
	QuestGeneratorData.reset_runtime_data()
	fx = QuestsGeneratorFixture.new()


func after_each() -> void:
	fx = null
	QuestGeneratorData.reset_static_state()


func test_runtime_drive_values_start_as_copies() -> void:
	var runtime := fx.villager_type.drive_values
	assert_eq(runtime.size(), 1, "one drive value")
	runtime[0].value = 10.0
	assert_eq(fx.villager_type.original_drive_values[0].value, 100.0, "the authored value is unchanged")
	assert_eq(fx.villager_type.drive_values[0].value, 10.0, "the runtime value persists")


func test_drive_values_found_through_parents() -> void:
	var child := QuestEntityType.new()
	child.parents = [fx.villager_type]
	var found := child.look_up_drive_value(fx.safety)
	assert_true(found != null and found.value == 100.0, "inherited drive value")
	assert_true(child.look_up_drive_value(QuestDrive.new()) == null, "unknown drive")


func test_record_and_apply_round_trip() -> void:
	fx.villager_type.drive_values[0].value = 25.0
	var recorded := QuestGeneratorData.record_generator_data()
	var json := JSON.stringify(recorded)
	var parsed: Dictionary = JSON.parse_string(json)
	assert_true(parsed.has("entity_types"), "recorded data survives JSON")
	fx.villager_type.drive_values[0].value = 90.0
	QuestGeneratorData.apply_generator_data(parsed)
	assert_eq(fx.villager_type.drive_values[0].value, 25.0, "value restored")


func test_apply_ignores_unknown_entity_types() -> void:
	QuestGeneratorData.apply_generator_data({"entity_types": {"name:Nobody": {"name:Safety": 1.0}}})
	QuestGeneratorData.apply_generator_data({})
	assert_true(true, "no error for unknown types or empty data")


func test_apply_by_name_after_reset() -> void:
	fx.villager_type.drive_values[0].value = 33.0
	var recorded := QuestGeneratorData.record_generator_data()
	QuestGeneratorData.reset_runtime_data()
	QuestGeneratorData.register_entity_type(fx.villager_type)
	QuestGeneratorData.apply_generator_data(recorded)
	assert_eq(fx.villager_type.drive_values[0].value, 33.0, "types registered by name are found")


func test_player_domain_instance() -> void:
	assert_eq(QuestDomainType.player_domain_instance, fx.player_domain, "the player domain registers itself")
	assert_eq(fx.player_domain.get_type_name(), "Player's Domain", "type name")
	QuestDomainType.set_player_domain_instance(null)
	assert_true(QuestDomainType.player_domain_instance != null, "an instance always exists")


func test_manager_saves_generator_data() -> void:
	var manager := make_manager()
	fx.villager_type.drive_values[0].value = 12.0
	var data := manager.record_data()
	assert_true(data.has("generator") and data.generator.has("entity_types"), "manager data includes generator data")
	fx.villager_type.drive_values[0].value = 77.0
	manager.apply_data(JSON.parse_string(JSON.stringify(data)))
	assert_eq(fx.villager_type.drive_values[0].value, 12.0, "manager restores generator data")
