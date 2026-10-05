extends QuestsTest

var fx: QuestsGeneratorFixture
var watch_signal_count := 0


func before_each() -> void:
	QuestGeneratorData.reset_runtime_data()
	fx = QuestsGeneratorFixture.new()
	make_manager()


func after_each() -> void:
	fx = null
	QuestGeneratorData.reset_static_state()


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


func test_domain_finds_entities_deep_below_a_body() -> void:
	var body := Node2D.new()
	var mid := Node.new()
	var deeper := Node.new()
	var even_deeper := Node.new()
	var entity := QuestEntity.new()
	body.add_child(mid)
	mid.add_child(deeper)
	deeper.add_child(even_deeper)
	even_deeper.add_child(entity)
	add_node(body)
	assert_eq(QuestDomain.find_entity(body), entity, "all descendants are searched")
	assert_null(QuestDomain.find_entity(body, 2), "a depth limit can still be given")


func test_domain_emits_entity_added_every_time() -> void:
	var domain := QuestDomain.new()
	add_node(domain)
	var entity := QuestEntity.new()
	add_node(entity)
	watch_signal_count = 0
	domain.entity_added.connect(func(_e: QuestEntity) -> void: watch_signal_count += 1)
	domain.add_entity(entity)
	domain.add_entity(entity)
	assert_eq(domain.entities.size(), 1, "an entity is only listed once")
	assert_eq(watch_signal_count, 2, "the event is raised on every call, like the original")


func test_disabled_reward_systems_are_not_recorded() -> void:
	var npc := _make_npc(1)
	var generator: QuestGeneratorEntity = npc.generator
	var disabled := QuestXPRewardSystem.new()
	disabled.process_mode = Node.PROCESS_MODE_DISABLED
	generator.get_parent().add_child(disabled)
	generator.reward_systems.clear()
	generator.record_reward_systems()
	assert_eq(generator.reward_systems.size(), 1, "only the enabled sibling is recorded")
	assert_true(not generator.reward_systems.has(disabled), "the disabled one is skipped")


func test_generated_quest_that_is_not_taken_is_disposed() -> void:
	var npc := _make_npc(3)
	var generator: QuestGeneratorEntity = npc.generator
	await _generate_and_wait(generator)
	assert_eq(generator.get_generated_quest_count(), 1, "the maximum is reached")
	var extra := QuestBuilder.new("extra", "extra_quest", "Extra").to_quest()
	track_quest(extra)
	Quests.register_quest_instance(extra)
	generator._on_generated_quest(extra)
	assert_eq((npc.giver as QuestGiver).quest_list.size(), 1, "the extra quest was not added")
	assert_eq(extra.get_state(), Quest.State.DISABLED, "it was disposed of")
	assert_null(Quests.get_quest_instance("extra_quest"), "and unregistered")


func test_weak_statics_do_not_keep_types_alive() -> void:
	var player := QuestPlayerEntityType.new()
	assert_eq(QuestPlayerEntityType.instance, player, "the newest player entity type is the instance")
	player = null
	assert_null(QuestPlayerEntityType.instance, "the instance is held weakly")
	QuestGeneratorData.reset_static_state()
	assert_true(QuestDomainType.player_domain_instance == null, "static state can be reset")
	QuestDomainType.set_player_domain_instance(null)
	assert_true(QuestDomainType.player_domain_instance != null, "a default player domain is made on demand")
