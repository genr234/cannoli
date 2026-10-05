extends QuestsTest

var fx: QuestsGeneratorFixture


func before_each() -> void:
	QuestGeneratorData.reset_runtime_data()
	fx = QuestsGeneratorFixture.new()


func after_each() -> void:
	fx = null
	QuestGeneratorData.reset_static_state()


func _planner(rng_seed := 1234) -> QuestPlanner:
	var planner := QuestPlanner.new()
	planner.rng.seed = rng_seed
	planner.frame_slicing = false
	return planner


func _step_names(plan: QuestPlan) -> Array[String]:
	var names: Array[String] = []
	for step in plan.steps:
		names.append("%s:%d" % [step, step.required_counter_value])
	return names


func test_goal_selection_picks_most_urgent_fact_and_verb() -> void:
	var planner := _planner()
	var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(3, 0, 1))
	assert_true(plan != null, "a plan is found")
	assert_eq(plan.goal.fact.entity_type, fx.orc_type, "goal is about the orcs")
	assert_eq(plan.goal.action, fx.kill, "goal verb is Kill")
	assert_true(plan.motive != null and plan.motive.text.begins_with("Please go"), "motive chosen from the verb")


func test_goal_counter_value_follows_count_curves() -> void:
	for rng_seed in 20:
		var planner := _planner(rng_seed + 1)
		var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(3))
		var count := plan.goal.required_counter_value
		assert_true(count >= 2 and count <= 3, "required count %d is within the curves for 3 orcs" % count)


func test_no_urgent_fact_means_no_plan() -> void:
	var planner := _planner()
	var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 2, 0))
	assert_true(plan == null, "iron has no urgency function")


func test_ignore_list_prevents_goal() -> void:
	var planner := _planner()
	var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(3), PackedStringArray(["Orc"]))
	assert_true(plan == null, "orcs are ignored")


func test_multi_step_plan_bfs() -> void:
	var planner := _planner()
	var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 2, 1))
	assert_true(plan != null, "a plan is found")
	assert_eq(plan.steps.size(), 2, "collect then craft")
	assert_eq(plan.steps[0].action, fx.collect, "first collect the iron")
	assert_eq(plan.steps[1].action, fx.craft, "then craft the sword")
	assert_eq(plan.goal, plan.steps[1], "the goal is the last step")


func test_unreachable_goal_gives_up() -> void:
	var planner := _planner()
	var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 0, 1))
	assert_true(plan == null, "no iron anywhere, so crafting is impossible")


func test_visited_state_dedupe_keeps_the_plan() -> void:
	var with_dedupe := _planner(99)
	var without_dedupe := _planner(99)
	without_dedupe.skip_visited_states = false
	var a := await with_dedupe.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 2, 1))
	var b := await without_dedupe.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 2, 1))
	assert_eq(_step_names(a), _step_names(b), "same plan with and without dedupe")


func test_search_depth_limit_stops_the_search() -> void:
	var limited := _planner()
	limited.max_search_depth = 1
	var plan_limited := await limited.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 2, 1))
	assert_true(plan_limited == null, "one state examined is not enough for a two step plan")
	var enough := _planner()
	enough.max_search_depth = 2
	var plan := await enough.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 2, 1))
	assert_true(plan != null, "two states are enough")


func test_backfill_raises_step_counts_to_verb_requirement() -> void:
	fx.collect.completion.required_value = 3
	var planner := _planner()
	var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 5, 1))
	assert_eq(plan.steps[0].action, fx.collect, "collect step")
	assert_eq(plan.steps[0].required_counter_value, 3, "collect count is raised to the verb's required value")


func test_threaded_plan_matches_main_thread_plan() -> void:
	var main_planner := _planner(777)
	var thread_planner := _planner(777)
	for world in [fx.new_world_model(4, 0, 1), fx.new_world_model(0, 2, 1), fx.new_world_model(1, 1, 1)]:
		main_planner.rng.seed = 777
		thread_planner.rng.seed = 777
		var a := await main_planner.make_plan(fx.villager_type, fx.village, QuestWorldModel.copy_of(world))
		var b := await thread_planner.make_plan_threaded(fx.villager_type, fx.village, QuestWorldModel.copy_of(world), PackedStringArray(), null)
		assert_true(a != null and b != null, "both find a plan")
		assert_eq(_step_names(a), _step_names(b), "same steps on a thread")
		assert_eq(a.motive, b.motive, "same motive on a thread")


func test_frame_slicing_waits_for_frames() -> void:
	QuestPlanner.max_steps_per_frame = 1
	QuestPlanner.max_goal_action_checks_per_frame = 1
	var planner := QuestPlanner.new()
	planner.rng.seed = 5
	var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(0, 2, 1))
	QuestPlanner.max_steps_per_frame = 100
	QuestPlanner.max_goal_action_checks_per_frame = 100
	assert_true(plan != null and plan.steps.size() == 2, "plan is still found when work is spread over frames")


func test_drive_alignment_prefers_matching_motive() -> void:
	var peaceful := QuestVerb.new()
	peaceful.resource_name = "Scare"
	peaceful.requirements = fx.kill.requirements
	peaceful.effects = fx.kill.effects
	peaceful.motives = [QuestMotive.create("Scare them.", [QuestDriveValue.create(fx.safety, -100.0)])]
	fx.orc_type.actions = [fx.kill, peaceful]
	var planner := _planner()
	var plan := await planner.make_plan(fx.villager_type, fx.village, fx.new_world_model(3))
	assert_eq(plan.goal.action, fx.kill, "the villager values safety, so the matching motive wins")
