extends QuestsTest

var fx: QuestsGeneratorFixture


func before_each() -> void:
	QuestGeneratorData.reset_runtime_data()
	fx = QuestsGeneratorFixture.new()


func after_each() -> void:
	fx = null
	QuestGeneratorData.reset_static_state()


func test_threat_urgency_uses_affinity_and_count() -> void:
	var wm := fx.new_world_model(3)
	var urgency := wm.compute_urgency_simple()
	assert_almost_eq(urgency, 240.0, "threat urgency = count multiplier (3) * 80")
	assert_eq(wm.most_urgent_fact.entity_type, fx.orc_type, "orcs are the most urgent fact")


func test_literal_urgency_and_cumulative() -> void:
	var wm := fx.new_world_model(1, 0, 1)
	var urgency := wm.compute_urgency_simple()
	assert_almost_eq(urgency, 90.0, "80 for one orc + 10 for the sword")
	assert_eq(wm.most_urgent_fact.entity_type, fx.orc_type, "orc is more urgent than the sword")


func test_most_urgent_facts_keeps_top_n_ascending() -> void:
	var wm := fx.new_world_model(1, 0, 1)
	var mode := QuestUrgentFactSelectionMode.create(QuestUrgentFactSelectionMode.Criterion.WEIGHTED, 2)
	wm.compute_urgency(mode)
	assert_eq(wm.most_urgent_facts.size(), 2, "two facts kept")
	assert_eq(wm.most_urgent_facts[0].entity_type, fx.sword_type, "least urgent first")
	assert_eq(wm.most_urgent_facts[1].entity_type, fx.orc_type, "most urgent last")


func test_selection_criteria_adjust_urgency() -> void:
	var squared := QuestUrgentFactSelectionMode.create(QuestUrgentFactSelectionMode.Criterion.WEIGHTED_SQUARED, 1)
	var equal := QuestUrgentFactSelectionMode.create(QuestUrgentFactSelectionMode.Criterion.EQUAL_WEIGHT, 1)
	assert_almost_eq(squared.adjust_urgency(3.0), 9.0, "squared")
	assert_eq(equal.adjust_urgency(3.0), 1.0, "equal weight")
	var global := QuestUrgentFactSelectionMode.create(QuestUrgentFactSelectionMode.Criterion.SAME_AS_GLOBAL_SETTING, 1)
	var saved := QuestGeneratorData.global_goal_selection
	QuestGeneratorData.global_goal_selection = squared
	assert_eq(global.adjust_urgency(4.0), 16.0, "same as global uses the global mode")
	QuestGeneratorData.global_goal_selection = saved


func test_ignore_list_skips_entity_types() -> void:
	var wm := fx.new_world_model(3, 0, 1)
	var urgency := wm.compute_urgency_simple(PackedStringArray(["Orc"]))
	assert_almost_eq(urgency, 10.0, "orc ignored")
	assert_eq(wm.most_urgent_fact.entity_type, fx.sword_type, "sword is the only candidate")


func test_state_key_ignores_fact_order() -> void:
	var a := fx.new_world_model(2, 1, 0)
	var b := QuestWorldModel.new(QuestFact.new(fx.village, fx.villager_type, 1))
	b.add_entity_type(fx.forest, fx.iron_type, 1)
	b.add_entity_type(fx.forest, fx.orc_type, 2)
	assert_eq(a.get_state_key(), b.get_state_key(), "same facts in a different order")
	b.add_entity_type(fx.forest, fx.orc_type, 1)
	assert_true(a.get_state_key() != b.get_state_key(), "different count")


func test_apply_action_and_requirements() -> void:
	var wm := fx.new_world_model(2, 1, 1)
	var iron_fact := wm.find_fact(fx.forest, fx.iron_type)
	assert_true(wm.are_requirements_met(fx.collect.requirements, iron_fact), "iron is in its domain")
	assert_true(not wm.are_requirements_met(fx.craft.requirements, wm.find_fact(fx.village, fx.sword_type)), "no iron with the quester yet")
	wm.apply_action(iron_fact, fx.collect)
	assert_true(wm.find_fact(fx.forest, fx.iron_type) == null, "iron removed from the forest")
	assert_true(wm.contains_fact(fx.player_domain, fx.iron_type, 1, 10), "iron added to the player domain")
	assert_true(wm.are_requirements_met(fx.craft.requirements, wm.find_fact(fx.village, fx.sword_type)), "craft is now possible")


func test_negated_requirement() -> void:
	var wm := fx.new_world_model(1)
	var req := QuestVerbRequirement.create(fx.this_domain(), QuestEntitySpecifier.other(fx.iron_type), 1, 65535, true)
	assert_true(wm.are_requirements_met([req] as Array[QuestVerbRequirement], wm.find_fact(fx.forest, fx.orc_type)), "no iron, so a negated requirement holds")


func test_copy_is_deep() -> void:
	var wm := fx.new_world_model(2)
	var copy := QuestWorldModel.copy_of(wm)
	copy.add_entity_type(fx.forest, fx.orc_type, 5)
	assert_eq(wm.find_fact(fx.forest, fx.orc_type).count, 2, "original unchanged")
	assert_eq(copy.find_fact(fx.forest, fx.orc_type).count, 7, "copy changed")


func test_add_and_remove_facts() -> void:
	var wm := fx.new_world_model(2)
	wm.add_fact(QuestFact.new(fx.forest, fx.orc_type, 1))
	assert_eq(wm.find_fact(fx.forest, fx.orc_type).count, 2, "add_fact keeps the larger count")
	wm.remove_fact(QuestFact.new(fx.forest, fx.orc_type, 1))
	assert_eq(wm.find_fact(fx.forest, fx.orc_type).count, 1, "remove_fact subtracts")
	wm.remove_entity_type(fx.forest, fx.orc_type, 1)
	assert_true(wm.find_fact(fx.forest, fx.orc_type) == null, "fact is removed when its count reaches zero")


func test_faction_requirement_function() -> void:
	var req := QuestFactionRequirement.new()
	req.judge = QuestEntitySpecifier.create(QuestEntitySpecifier.Type.QUEST_GIVER)
	req.subject = QuestEntitySpecifier.other(fx.orc_type)
	req.min_faction = -100.0
	req.max_faction = -50.0
	var wm := fx.new_world_model(1)
	assert_true(req.is_true(wm), "villagers' -80 is within [-100,-50]")
	req.max_faction = -90.0
	assert_true(not req.is_true(wm), "-80 is outside [-100,-90]")


func test_drive_alignment_urgency() -> void:
	var orc_drive := QuestDriveValue.create(fx.safety, 100.0)
	fx.orc_type.original_drive_values = [orc_drive]
	var urgency := QuestDriveAlignmentUrgency.new()
	var wm := fx.new_world_model(1)
	wm.observed = wm.find_fact(fx.forest, fx.orc_type)
	assert_almost_eq(urgency.compute(wm), 1.0, "identical drive values align fully")
	fx.orc_type.drive_values[0].value = 0.0
	assert_almost_eq(urgency.compute(wm), 0.5, "100 apart is half aligned")


func test_relationships_cache_overrides_factions() -> void:
	fx.villager_type.relationships_faction = "A"
	fx.orc_type.relationships_faction = "B"
	var wm := fx.new_world_model(2)
	wm.affinity_cache = {"A|B": -50.0}
	wm.use_affinity_cache = true
	assert_eq(QuestAffinity.get_affinity(fx.villager_type, fx.orc_type, wm), -50.0, "cache wins over QuestFaction")
	assert_almost_eq(wm.compute_urgency_simple(), 100.0, "threat = 2 * 50")
	wm.use_affinity_cache = false
	if not QuestAffinity.is_relationships_available():
		assert_eq(QuestAffinity.get_affinity(fx.villager_type, fx.orc_type, wm), -80.0, "falls back to QuestFaction")


func test_entity_type_helpers() -> void:
	assert_eq(fx.orc_type.get_descriptor(1), "Orc", "singular")
	assert_eq(fx.orc_type.get_descriptor(3), "3 Orcs", "plural")
	var bus := QuestEntityType.new()
	bus.resource_name = "Bus"
	assert_eq(bus.get_plural_display_name(), "Buses", "words ending in s get es")
	bus.is_unique = true
	assert_eq(bus.get_descriptor(4), "Bus", "unique types are never plural")
	var child := QuestEntityType.new()
	child.parents = [fx.orc_type]
	assert_eq(child.get_faction(), fx.orc_faction, "faction inherited from parent")
	assert_eq(child.get_all_actions().size(), 1, "actions inherited from parent")
	assert_eq(child.get_urgency_functions().size(), 1, "urgency functions inherited from parent")
	assert_eq(child.get_reward_multiplier(QuestRewardMultiplier.Category.XP), 1.0, "default multiplier")


func test_default_count_curves() -> void:
	assert_eq(QuestCurves.evaluate(fx.orc_type.min_count_in_action, 1), 1.0, "min curve at 1")
	assert_eq(QuestCurves.evaluate(fx.orc_type.min_count_in_action, 10), 2.0, "min curve flat after 2")
	assert_eq(QuestCurves.evaluate(fx.orc_type.max_count_in_action, 10), 10.0, "max curve at 10")
	assert_eq(QuestCurves.evaluate(fx.orc_type.max_count_in_action, 20), 15.0, "max curve at 20")
	assert_eq(QuestCurves.evaluate(fx.orc_type.max_count_in_action, 100), 15.0, "clamped past the last key")
