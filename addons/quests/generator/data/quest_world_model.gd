class_name QuestWorldModel
extends RefCounted
## What a quest giver believes about the world: the facts it knows, and the fact
## it is currently looking at. The planner copies and changes world models to
## project the effects of verbs into the future.
##
## A world model contains only plain data and references to read-only
## resources, so it can be used on a worker thread.

## The quest giver's own fact.
var observer: QuestFact
## The fact currently being evaluated.
var observed: QuestFact
var facts: Array[QuestFact] = []
## The most urgent facts found by the last call to [method compute_urgency], least urgent first.
var most_urgent_facts: Array[QuestFact] = []
## The most urgent fact found by the last call to [method compute_urgency_simple].
var most_urgent_fact: QuestFact
## Affinities between Relationships addon factions, filled by the planner for
## threaded planning. Keys are "judge|subject".
var affinity_cache: Dictionary = {}
var use_affinity_cache := false


func _init(p_observer: QuestFact = null) -> void:
	observer = p_observer


## Returns a deep copy of [param source].
static func copy_of(source: QuestWorldModel) -> QuestWorldModel:
	var wm := QuestWorldModel.new(QuestFact.copy_of(source.observer))
	wm.observed = QuestFact.copy_of(source.observed)
	for fact in source.facts:
		wm.facts.append(QuestFact.copy_of(fact))
	wm.affinity_cache = source.affinity_cache
	wm.use_affinity_cache = source.use_affinity_cache
	return wm


func find_fact(domain_type: QuestDomainType, entity_type: QuestEntityType) -> QuestFact:
	for f in facts:
		if f.domain_type == domain_type and f.entity_type == entity_type:
			return f
	return null


func contains_fact(domain_type: QuestDomainType, entity_type: QuestEntityType, min_count: int, max_count: int) -> bool:
	var fact := find_fact(domain_type, entity_type)
	return fact != null and min_count <= fact.count and fact.count <= max_count


func add_entity_type(domain_type: QuestDomainType, entity_type: QuestEntityType, count := 1) -> void:
	if domain_type == null or entity_type == null:
		return
	var fact := find_fact(domain_type, entity_type)
	if fact != null:
		fact.count += count
	else:
		facts.append(QuestFact.new(domain_type, entity_type, count))


func remove_entity_type(domain_type: QuestDomainType, entity_type: QuestEntityType, count := 1) -> void:
	var existing := find_fact(domain_type, entity_type)
	if existing != null:
		if count < existing.count:
			existing.count -= count
		else:
			facts.erase(existing)


func add_fact(fact: QuestFact) -> void:
	var existing := find_fact(fact.domain_type, fact.entity_type)
	if existing != null:
		existing.count = maxi(existing.count, fact.count)
	else:
		facts.append(QuestFact.copy_of(fact))


func remove_fact(fact: QuestFact) -> void:
	var existing := find_fact(fact.domain_type, fact.entity_type)
	if existing != null:
		if fact.count < existing.count:
			existing.count -= fact.count
		else:
			facts.erase(existing)


## A string that is equal for two world models if they contain the same
## (domain type, entity type, count) facts, regardless of order. Used by the
## planner to skip states it has already seen.
func get_state_key() -> String:
	var parts := PackedStringArray()
	for f in facts:
		parts.append("%d:%d:%d" % [
			f.domain_type.get_instance_id() if f.domain_type != null else 0,
			f.entity_type.get_instance_id() if f.entity_type != null else 0,
			f.count])
	parts.sort()
	return ";".join(parts)


## Computes the urgency of every fact and returns their sum. Sets each fact's
## [member QuestFact.urgency] and fills [member most_urgent_facts] with up to
## [member QuestUrgentFactSelectionMode.max_facts] facts, least urgent first.
## Facts whose entity type name is in [param ignore_list] are skipped.
func compute_urgency(selection_mode: QuestUrgentFactSelectionMode, ignore_list: PackedStringArray = PackedStringArray(), debug := false) -> float:
	var top: Array[QuestFact] = []
	var max_urgent := selection_mode.max_facts
	var cumulative := 0.0
	var min_top_urgency := -INF
	var debug_info := ""
	if Quests.debug and observer != null and observer.entity_type != null:
		debug_info = "Quests: WORLD MODEL: (observer:%s)\n" % observer.entity_type.get_asset_name()
	for fact in facts:
		if fact == null or fact.entity_type == null:
			continue
		if _should_ignore(fact.entity_type.get_asset_name(), ignore_list):
			continue
		observed = fact
		var urgency := selection_mode.adjust_urgency(get_fact_urgency(fact))
		fact.urgency = urgency
		cumulative += urgency
		if urgency > 0.0 and (top.size() < max_urgent or urgency > min_top_urgency):
			if top.size() >= max_urgent:
				top.remove_at(0)
			var added := false
			for j in top.size():
				if top[j].urgency > urgency:
					top.insert(j, fact)
					added = true
					break
			if not added:
				top.append(fact)
			min_top_urgency = top[0].urgency
		if debug:
			debug_info += "Domain:%s, EntityType:%s, Count:%d\n   Urgency:%s\n" % [
					fact.domain_type.get_asset_name() if fact.domain_type != null else "", fact.entity_type.get_asset_name(), fact.count, urgency]
	if debug:
		if not top.is_empty():
			var most := top[top.size() - 1]
			debug_info += "MOST URGENT: %s, Urgency:%s\n" % [most, min_top_urgency]
		debug_info += "CUMULATIVE URGENCY: %s" % cumulative
		print("Quests: " + debug_info)
	most_urgent_facts = top
	return cumulative


## Computes urgency considering only the single most urgent fact, which is
## stored in [member most_urgent_fact]. Returns the cumulative urgency.
func compute_urgency_simple(ignore_list: PackedStringArray = PackedStringArray()) -> float:
	var urgency := compute_urgency(QuestUrgentFactSelectionMode.most_urgent(), ignore_list)
	most_urgent_fact = most_urgent_facts[0] if not most_urgent_facts.is_empty() else null
	return urgency


## The summed urgency of one fact, using its entity type's urgency functions.
func get_fact_urgency(fact: QuestFact) -> float:
	if fact == null or fact.entity_type == null:
		return 0.0
	var urgency := 0.0
	for function in fact.entity_type.get_urgency_functions():
		if function == null:
			continue
		urgency += function.compute(self)
	return urgency


func _should_ignore(entity_type_name: String, ignore_list: PackedStringArray) -> bool:
	if entity_type_name.is_empty() or ignore_list.is_empty():
		return false
	return ignore_list.has(entity_type_name)


## Applies a verb's effects as if it were done to [param fact].
func apply_action(fact: QuestFact, action: QuestVerb) -> void:
	observed = fact
	for effect in action.effects:
		var domain_type := effect.domain_specifier.get_domain_type(self)
		var entity_type := effect.entity_specifier.get_entity_type(self)
		match effect.operation:
			QuestVerbEffect.Operation.ADD:
				add_entity_type(domain_type, entity_type, effect.count)
			QuestVerbEffect.Operation.REMOVE:
				remove_entity_type(domain_type, entity_type, effect.count)


## True if every requirement is met. If [param fact] is given, "this entity"
## specifiers refer to it.
func are_requirements_met(requirements: Array[QuestVerbRequirement], fact: QuestFact = null) -> bool:
	var current_observed := observed
	if fact != null:
		observed = fact
	var result := true
	for requirement in requirements:
		var domain_type := requirement.domain_specifier.get_domain_type(self)
		var entity_type := requirement.entity_specifier.get_entity_type(self)
		var contains := contains_fact(domain_type, entity_type, requirement.min_count, requirement.max_count)
		if not requirement.negated and not contains:
			result = false
			break
		if requirement.negated and contains:
			result = false
			break
		if requirement.requirement_function != null and not requirement.requirement_function.is_true(self):
			result = false
			break
	if fact != null:
		observed = current_observed
	return result
