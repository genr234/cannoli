extends QuestsTest

var fx: QuestsGeneratorFixture
var watch_signal_count := 0


func before_each() -> void:
	QuestGeneratorData.reset_runtime_data()
	fx = QuestsGeneratorFixture.new()
	make_manager()


func _make_npc(orcs: int, thread := false, on_start := false) -> Dictionary:
	var npc := Node.new()
	var giver := QuestGiver.new()
	giver.id = "captain"
	giver.display_name = "Captain Molly"
	npc.add_child(giver)
	var generator := QuestGeneratorEntity.new()
	generator.entity_type = fx.villager_type
	generator.domain_type = fx.village
	generator.use_thread = thread
	generator.random_seed = 11
	generator.generate_quest_on_start = on_start
	npc.add_child(generator)
	var domain := QuestDomain.new()
	domain.domain_type = fx.forest
	npc.add_child(domain)
	generator.domains = [domain] as Array[QuestDomain]
	var xp := QuestXPRewardSystem.new()
	npc.add_child(xp)
	add_node(npc)
	for i in orcs:
		var orc_body := Node.new()
		var entity := QuestEntity.new()
		entity.entity_type = fx.orc_type
		orc_body.add_child(entity)
		add_node(orc_body)
		domain.add_entity(entity)
	return {"giver": giver, "generator": generator, "domain": domain}


func _generate_and_wait(generator: QuestGeneratorEntity) -> void:
	generator.generate_quest()
	var waited := 0
	while generator.is_generating and waited < 200:
		await frames(1)
		waited += 1
	await frames(1)


func test_generates_a_quest_from_domain_entities() -> void:
	var npc := _make_npc(3)
	var generator: QuestGeneratorEntity = npc.generator
	var giver: QuestGiver = npc.giver
	watch_signal_count = 0
	generator.generated_quest.connect(func(_q: Quest) -> void: watch_signal_count += 1)
	await _generate_and_wait(generator)
	assert_eq(giver.quest_list.size(), 1, "a quest was added to the giver")
	assert_eq(watch_signal_count, 1, "generated_quest emitted")
	var quest := giver.quest_list[0]
	assert_true(quest.is_procedurally_generated, "quest is generated")
	assert_eq(quest.goal_entity_type_name, "Orc", "about the orcs")
	assert_eq(generator.get_generated_quest_count(), 1, "count")


func test_max_quests_to_generate_is_respected() -> void:
	var npc := _make_npc(3)
	var generator: QuestGeneratorEntity = npc.generator
	await _generate_and_wait(generator)
	await _generate_and_wait(generator)
	assert_eq((npc.giver as QuestGiver).quest_list.size(), 1, "only one quest with the default maximum")


func test_existing_goal_is_not_generated_again() -> void:
	var npc := _make_npc(3)
	var generator: QuestGeneratorEntity = npc.generator
	generator.max_quests_to_generate = 3
	await _generate_and_wait(generator)
	await _generate_and_wait(generator)
	assert_eq((npc.giver as QuestGiver).quest_list.size(), 1, "orcs already have a quest, nothing else is urgent")


func test_nothing_urgent_generates_nothing() -> void:
	var npc := _make_npc(0)
	await _generate_and_wait(npc.generator)
	assert_eq((npc.giver as QuestGiver).quest_list.size(), 0, "no entities, no quest")
	assert_true(not npc.generator.is_generating, "generation finished")


func test_threaded_generation() -> void:
	var npc := _make_npc(3, true)
	await _generate_and_wait(npc.generator)
	assert_eq((npc.giver as QuestGiver).quest_list.size(), 1, "quest generated on a worker thread")
	assert_eq((npc.giver as QuestGiver).quest_list[0].goal_entity_type_name, "Orc", "about the orcs")


func test_generate_on_start() -> void:
	var npc := _make_npc(2, false, true)
	await frames(10)
	assert_eq((npc.giver as QuestGiver).quest_list.size(), 1, "quest generated on start")


func test_world_model_signal_can_add_facts() -> void:
	var npc := _make_npc(0)
	var generator: QuestGeneratorEntity = npc.generator
	generator.world_model_updating.connect(func(wm: QuestWorldModel) -> void: wm.add_entity_type(fx.forest, fx.orc_type, 2))
	await _generate_and_wait(generator)
	assert_eq((npc.giver as QuestGiver).quest_list.size(), 1, "facts added by the signal are used")


func test_reward_systems_nearby_are_recorded() -> void:
	var npc := _make_npc(1)
	assert_eq((npc.generator as QuestGeneratorEntity).reward_systems.size(), 1, "sibling reward system found")


func test_entity_ids_come_from_the_giver() -> void:
	var npc := _make_npc(1)
	assert_eq((npc.generator as QuestGeneratorEntity).get_id(), "captain", "id")
	assert_eq((npc.generator as QuestGeneratorEntity).get_display_name(), "Captain Molly", "display name")


func test_domain_tracks_entities_entering_areas() -> void:
	var area := Area2D.new()
	var domain := QuestDomain.new()
	domain.domain_type = fx.forest
	area.add_child(domain)
	add_node(area)
	var body := Node2D.new()
	var entity := QuestEntity.new()
	entity.entity_type = fx.orc_type
	body.add_child(entity)
	add_node(body)
	area.body_entered.emit(body)
	assert_eq(domain.entities.size(), 1, "entity added when its body enters")
	var wm := QuestWorldModel.new(QuestFact.new(fx.village, fx.villager_type, 1))
	domain.add_entities_to_world_model(wm)
	assert_true(wm.contains_fact(fx.forest, fx.orc_type, 1, 1), "world model has the entity")
	area.body_exited.emit(body)
	assert_eq(domain.entities.size(), 0, "entity removed when its body exits")


func test_domain_drops_freed_entities() -> void:
	var domain := QuestDomain.new()
	add_node(domain)
	var entity := QuestEntity.new()
	add_node(entity)
	domain.add_entity(entity)
	assert_eq(domain.entities.size(), 1, "added")
	entity.get_parent().remove_child(entity)
	assert_eq(domain.entities.size(), 0, "removed when the entity leaves the tree")
	entity.free()
