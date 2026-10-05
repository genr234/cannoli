class_name QuestPlanner
extends RefCounted
## Generates quests. Picks the fact that is most urgent to a quest giver,
## chooses a verb that relieves it, searches (breadth-first) for the steps that
## make the verb possible, and converts the plan to a [Quest].
##
## Work is spread over frames using the limits below, which
## [QuestGeneratorEntity] copies from [QuestManager]. Alternatively, with
## [member use_thread], goal selection and the search run on a worker thread
## against a copy of the world model.
##
## [method make_plan] and [method generate_quest] must be awaited or fired and
## forgotten; they only wait for frames when frame slicing is on.

## Planners allowed to work at the same time. Others wait for a free slot.
static var max_simultaneous_planners := 5
## When choosing a goal, check this many verbs per frame.
static var max_goal_action_checks_per_frame := 100
## When searching for a plan, evaluate this many steps per frame.
static var max_steps_per_frame := 100
static var default_max_search_depth := 1000
static var detailed_debug := false

static var _active_planners := 0

## The most plan states to examine before giving up.
var max_search_depth := default_max_search_depth
## Skip world model states that have already been seen during the search.
var skip_visited_states := true
## Scores how well a motive's drive values match the quest giver's.
var drive_alignment_method := QuestDriveAlignmentMethod.Method.DIFFERENCE
## Run goal selection and search on a worker thread.
var use_thread := false
## Wait for frames while working, as limited by the per-frame settings. Turn
## off to plan in one go. Always off for threaded planning.
var frame_slicing := true
## Random numbers used by the planner. Set its seed for repeatable results.
var rng := RandomNumberGenerator.new()
## Converts the plan to a quest. Replace to customize generated quests.
var plan_to_quest_builder := QuestPlanToQuestBuilder.new()

## The goal chosen by the last run.
var goal: QuestPlanStep
## The motive chosen for the goal.
var motive: QuestMotive
## The plan found by the last run.
var plan: QuestPlan

var _entity: QuestEntity
var _entity_type: QuestEntityType
var _world_model: QuestWorldModel
var _ignore_list := PackedStringArray()
var _goal_selection_mode: QuestUrgentFactSelectionMode
var _cancel := false
var _slicing := true
var _thread_result: QuestPlan
var _master_steps: Dictionary = {}


func _init() -> void:
	rng.randomize()


## Stops generation. The callback given to [method generate_quest] is still called, with null.
func cancel_generation() -> void:
	_cancel = true


## Generates a quest for [param entity] and calls [param generated_quest] with it,
## or with null if no quest could be made. Returns immediately; work continues
## over the next frames.
func generate_quest(entity: QuestEntity, group: String, domain_type: QuestDomainType, world_model: QuestWorldModel,
		require_return_to_complete: bool, rewards_ui_contents: Array[QuestContent], reward_systems: Array[QuestRewardSystem],
		existing_quests: Array[Quest], generated_quest: Callable, goal_selection_mode: QuestUrgentFactSelectionMode,
		generate_abandonable_quests: bool) -> void:
	if entity == null or domain_type == null or world_model == null:
		return
	_generate_quest_async(entity, group, domain_type, world_model, require_return_to_complete, rewards_ui_contents,
			reward_systems, existing_quests, generated_quest, goal_selection_mode, generate_abandonable_quests)


func _generate_quest_async(entity: QuestEntity, group: String, domain_type: QuestDomainType, world_model: QuestWorldModel,
		require_return_to_complete: bool, rewards_ui_contents: Array[QuestContent], reward_systems: Array[QuestRewardSystem],
		existing_quests: Array[Quest], generated_quest: Callable, goal_selection_mode: QuestUrgentFactSelectionMode,
		generate_abandonable_quests: bool) -> void:
	_cancel = false
	_entity = entity
	_entity_type = entity.entity_type
	var quest: Quest = null
	while _active_planners >= max_simultaneous_planners and not _cancel:
		await _next_frame()
	if not _cancel:
		_active_planners += 1
		var result: QuestPlan
		var ignore_list := _make_ignore_list(existing_quests)
		if use_thread:
			result = await make_plan_threaded(_entity_type, domain_type, world_model, ignore_list, goal_selection_mode)
		else:
			result = await make_plan(_entity_type, domain_type, world_model, ignore_list, goal_selection_mode)
		_active_planners -= 1
		if result != null and not _cancel and is_instance_valid(entity):
			if detailed_debug:
				_log_plan(result)
			quest = plan_to_quest_builder.convert_plan_to_quest(entity, group, result.goal, result.motive, result,
					require_return_to_complete, rewards_ui_contents, reward_systems)
			if generate_abandonable_quests and quest != null:
				quest.is_abandonable = true
	if generated_quest.is_valid():
		generated_quest.call(quest)


## Chooses a goal and finds a plan to achieve it, without building a quest.
## Returns the plan, whose [member QuestPlan.goal] and [member QuestPlan.motive]
## are set, or null if nothing is urgent or no plan was found. Only waits for
## frames if [member frame_slicing] is on.
func make_plan(observer_type: QuestEntityType, domain_type: QuestDomainType, world_model: QuestWorldModel,
		ignore_list := PackedStringArray(), goal_selection_mode: QuestUrgentFactSelectionMode = null) -> QuestPlan:
	_slicing = frame_slicing
	_entity_type = observer_type
	_world_model = world_model
	_ignore_list = ignore_list
	_goal_selection_mode = goal_selection_mode if goal_selection_mode != null else QuestUrgentFactSelectionMode.most_urgent()
	_master_steps = {}
	goal = null
	motive = null
	plan = null
	_world_model.observer = QuestFact.new(domain_type, observer_type, 1)
	await _determine_goal()
	if _cancel or goal == null:
		return null
	await _generate_plan()
	if _cancel or plan == null:
		return null
	_backfill_minimum_counter_values()
	plan.goal = goal
	plan.motive = motive
	return plan


## Like [method make_plan], but goal selection and the search run on a worker
## thread against a copy of [param world_model]. Waits for the thread without
## blocking the main thread.
func make_plan_threaded(observer_type: QuestEntityType, domain_type: QuestDomainType, world_model: QuestWorldModel,
		ignore_list: PackedStringArray, goal_selection_mode: QuestUrgentFactSelectionMode) -> QuestPlan:
	var snapshot := QuestWorldModel.copy_of(world_model)
	_prepare_for_thread(observer_type, snapshot)
	var saved_slicing := frame_slicing
	frame_slicing = false
	var job := func() -> void:
		_thread_result = await make_plan(observer_type, domain_type, snapshot, ignore_list, goal_selection_mode)
	var task_id := WorkerThreadPool.add_task(job, false, "Quests: plan quest")
	while not WorkerThreadPool.is_task_completed(task_id):
		await _next_frame()
	WorkerThreadPool.wait_for_task_completion(task_id)
	frame_slicing = saved_slicing
	return _thread_result


## Does everything that needs the scene tree before planning on a thread:
## creates runtime drive values and caches Relationships affinities.
func _prepare_for_thread(observer_type: QuestEntityType, snapshot: QuestWorldModel) -> void:
	var types := _collect_entity_types(observer_type, snapshot)
	for t in types:
		QuestGeneratorData.get_runtime_drive_values(t as QuestEntityType)
	if QuestAffinity.is_relationships_available():
		snapshot.affinity_cache = {}
		QuestAffinity.fill_cache(types, snapshot.affinity_cache)
		snapshot.use_affinity_cache = true


func _collect_entity_types(observer_type: QuestEntityType, snapshot: QuestWorldModel) -> Array:
	var seen: Dictionary = {}
	var queue: Array[QuestEntityType] = []
	_enqueue_type(observer_type, seen, queue)
	_enqueue_type(QuestPlayerEntityType.instance, seen, queue)
	for fact in snapshot.facts:
		_enqueue_type(fact.entity_type, seen, queue)
	var verbs_seen: Dictionary = {}
	var head := 0
	while head < queue.size():
		var et := queue[head]
		head += 1
		for parent in et.parents:
			_enqueue_type(parent, seen, queue)
		for verb in et.actions:
			if verb == null or verbs_seen.has(verb):
				continue
			verbs_seen[verb] = true
			for requirement in verb.requirements:
				if requirement == null:
					continue
				_enqueue_specifier(requirement.entity_specifier, seen, queue)
				var function := requirement.requirement_function as QuestFactionRequirement
				if function != null:
					_enqueue_specifier(function.judge, seen, queue)
					_enqueue_specifier(function.subject, seen, queue)
			for effect in verb.effects:
				if effect != null:
					_enqueue_specifier(effect.entity_specifier, seen, queue)
	return queue


func _enqueue_specifier(specifier: QuestEntitySpecifier, seen: Dictionary, queue: Array[QuestEntityType]) -> void:
	if specifier != null:
		_enqueue_type(specifier.entity_type, seen, queue)


func _enqueue_type(entity_type: QuestEntityType, seen: Dictionary, queue: Array[QuestEntityType]) -> void:
	if entity_type != null and not seen.has(entity_type):
		seen[entity_type] = true
		queue.append(entity_type)


func _next_frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame


func _make_ignore_list(existing_quests: Array[Quest]) -> PackedStringArray:
	var list := PackedStringArray()
	for quest in existing_quests:
		if quest == null:
			continue
		var type_name := quest.goal_entity_type_name
		if type_name.is_empty() or list.has(type_name):
			continue
		list.append(type_name)
	return list


func _debug_enabled() -> bool:
	return Quests.debug or detailed_debug


func _entity_name() -> String:
	if _entity != null and is_instance_valid(_entity):
		return _entity.get_display_name()
	return _entity_type.get_display_name() if _entity_type != null else ""


#region Determine goal

func _determine_goal() -> void:
	var cumulative := _world_model.compute_urgency(_goal_selection_mode, _ignore_list, detailed_debug)
	var most_urgent_fact := _choose_weighted_most_urgent_fact(_world_model.most_urgent_facts)
	if cumulative <= 0.0 or most_urgent_fact == null:
		if _debug_enabled():
			print("Quests: [Generator] %s: No facts are currently urgent for %s. Not generating a new quest." % [_entity_name(), _entity_name()])
		return
	if _debug_enabled():
		print("Quests: [Generator] %s: Most urgent fact: %s" % [_entity_name(), most_urgent_fact])
	var best_urgency := INF
	var best_action: QuestVerb = null
	var best_motive: QuestMotive = null
	var actions := _get_entity_actions(most_urgent_fact.entity_type)
	if actions == null:
		return
	var num_checks := 0
	for action in actions:
		num_checks += 1
		if num_checks > max_goal_action_checks_per_frame:
			num_checks = 0
			if _slicing:
				await _next_frame()
		if action == null:
			continue
		var wm := QuestWorldModel.copy_of(_world_model)
		wm.apply_action(most_urgent_fact, action)
		var new_urgency := wm.compute_urgency_simple()
		var best_motive_for_action := _choose_best_motive(action.motives)
		var weighted_urgency := new_urgency
		if best_motive_for_action != null:
			weighted_urgency = new_urgency - (_get_drive_alignment(best_motive_for_action.drive_values) * new_urgency)
		if weighted_urgency < best_urgency:
			best_urgency = weighted_urgency
			best_action = action
			best_motive = best_motive_for_action
	if best_action == null:
		return
	motive = best_motive
	goal = QuestPlanStep.new(most_urgent_fact, best_action, _choose_required_counter_value(most_urgent_fact))
	if _debug_enabled():
		print("Quests: [Generator] %s: Goal: %s %s" % [_entity_name(), best_action.get_asset_name(), most_urgent_fact])


func _choose_required_counter_value(fact: QuestFact) -> int:
	var min_value := mini(fact.count, QuestCurves.ceil_value(QuestCurves.evaluate(fact.entity_type.min_count_in_action, fact.count)))
	var max_value := QuestCurves.ceil_value(QuestCurves.evaluate(fact.entity_type.max_count_in_action, fact.count))
	max_value = maxi(max_value, min_value)
	return rng.randi_range(min_value, max_value)


func _choose_weighted_most_urgent_fact(most_urgent_facts: Array[QuestFact]) -> QuestFact:
	if most_urgent_facts.is_empty():
		return null
	var total_weight := 0.0
	for fact in most_urgent_facts:
		if fact != null:
			total_weight += fact.urgency
	var random_value := rng.randf() * total_weight
	var min_weight := 0.0
	for fact in most_urgent_facts:
		if fact == null:
			continue
		var max_weight := min_weight + fact.urgency
		if min_weight <= random_value and random_value <= max_weight:
			return fact
		min_weight = max_weight
	return null

#endregion
#region Motives

func _choose_best_motive(motives: Array[QuestMotive]) -> QuestMotive:
	var best: QuestMotive = null
	var best_alignment := -INF
	for m in motives:
		if m == null:
			continue
		var alignment := _get_drive_alignment(m.drive_values)
		if detailed_debug:
			print("Quests: [Generator] Motive Alignment: entity=%s motive=%s alignment=%s" % [_entity_name(), m.text, alignment])
		if alignment > best_alignment:
			best_alignment = alignment
			best = m
	return best


func _get_drive_alignment(drive_values: Array[QuestDriveValue]) -> float:
	var total := 0.0
	var count := 0
	for drive_value in drive_values:
		if drive_value == null or drive_value.drive == null:
			continue
		var entity_drive_value := _lookup_entity_drive_value(drive_value.drive)
		if entity_drive_value == null:
			continue
		total += QuestDriveAlignmentMethod.alignment(drive_alignment_method, absf(drive_value.value - entity_drive_value.value))
		count += 1
	return 0.0 if count == 0 else total / float(count)


func _lookup_entity_drive_value(drive: QuestDrive) -> QuestDriveValue:
	if drive == null or _entity_type == null:
		return null
	return _entity_type.look_up_drive_value(drive)

#endregion
#region Generate plan

func _generate_plan() -> void:
	await _bfs(_world_model, goal)


func _bfs(initial_world_model: QuestWorldModel, goal_step: QuestPlanStep) -> void:
	if _slicing:
		await _next_frame()
	var queue: Array[QuestPlan] = [QuestPlan.new(null, null, initial_world_model)]
	var head := 0
	var visited: Dictionary = {}
	if skip_visited_states:
		visited[initial_world_model.get_state_key()] = true
	var num_steps_checked := 0
	var safeguard := 0
	while head < queue.size() and safeguard < max_search_depth:
		safeguard += 1
		num_steps_checked += 1
		if num_steps_checked > max_steps_per_frame:
			num_steps_checked = 0
			if _slicing:
				await _next_frame()
			if _cancel:
				return
		var current := queue[head]
		head += 1
		if current.world_model.are_requirements_met(goal_step.action.requirements, goal_step.fact):
			plan = QuestPlan.new(current, goal_step, null)
			return
		var last_step: QuestPlanStep = current.steps[current.steps.size() - 1] if not current.steps.is_empty() else null
		for fact in current.world_model.facts:
			var actions := _get_entity_actions(fact.entity_type)
			if actions == null:
				continue
			for action in actions:
				if fact == null or fact.entity_type == null or action == null:
					continue
				if last_step != null and fact == last_step.fact and action == last_step.action:
					continue
				if not current.world_model.are_requirements_met(action.requirements):
					continue
				var new_world_model := QuestWorldModel.copy_of(current.world_model)
				new_world_model.apply_action(fact, action)
				if skip_visited_states:
					var key := new_world_model.get_state_key()
					if visited.has(key):
						continue
					visited[key] = true
				queue.append(QuestPlan.new(current, _get_step(fact, action), new_world_model))
	if _debug_enabled():
		print("Quests: [Generator] Could not create quest. Exceeded safeguard while generating plan to %s %s." % [
				goal_step.action.get_asset_name(), goal_step.fact.entity_type.get_asset_name()])


## The verbs for an entity type, including those of its ancestors.
func _get_entity_actions(entity_type: QuestEntityType) -> Array[QuestVerb]:
	if entity_type == null:
		return [] as Array[QuestVerb]
	return entity_type.get_all_actions()


func _get_step(fact: QuestFact, action: QuestVerb) -> QuestPlanStep:
	var key := "%d:%d" % [fact.get_instance_id(), action.get_instance_id()]
	if _master_steps.has(key):
		return _master_steps[key]
	var step := QuestPlanStep.new(fact, action)
	_master_steps[key] = step
	return step


func _backfill_minimum_counter_values() -> void:
	var required_counter_value: Dictionary = {}
	for step in plan.steps:
		if step.action.completion.mode != QuestVerbCompletion.Mode.COUNTER:
			continue
		var counter_name := step.action.completion.base_counter_name
		var step_required := step.action.completion.required_value
		if not required_counter_value.has(counter_name):
			required_counter_value[counter_name] = step_required
		else:
			required_counter_value[counter_name] = maxi(required_counter_value[counter_name], step_required)
	for step in plan.steps:
		if step.action.completion.mode != QuestVerbCompletion.Mode.COUNTER:
			continue
		step.required_counter_value = maxi(step.required_counter_value, required_counter_value[step.action.completion.base_counter_name])


func _log_plan(logged_plan: QuestPlan) -> void:
	var s := "Quests: [Generator] Plan (%d steps):\n" % logged_plan.steps.size()
	for step in logged_plan.steps:
		s += "   %s\n" % step if step.fact != null else "   (null)\n"
	print(s)

#endregion
