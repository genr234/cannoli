class_name Rumor
extends RefCounted
## A faction member's subjective memory of a [Deed].

## The [member Deed.id] of the deed this rumor is about.
var deed_id := ""
var category: DeedCategory
var tag := ""
var actor_faction_id := 0
var target_faction_id := 0
var impact := 0.0
var aggression := 0.0
var actor_power_level := 1.0
var traits := PackedFloat32Array()
## How many times the deed was repeated. Repeating an attack raises the count
## instead of creating a new rumor for every swing.
var count := 1
## How much the member believes the rumor, from 0 to 100. It's higher when the
## member likes the source.
var confidence := 0.0
## The pleasure this rumor caused the member.
var pleasure := 0.0
## The arousal this rumor caused the member.
var arousal := 0.0
## The dominance change this rumor caused the member.
var dominance := 0.0
var permitted_evaluators := Deed.PermittedEvaluators.EVERYONE
var min_affinity_effect := -100.0
var max_affinity_effect := 100.0
## How many times the rumor was passed on before reaching this member. 0
## means the member witnessed the deed itself.
var hops := 0
## Whether the rumor was important enough to remember.
var memorable := false
## The [method RelationshipsTime.now] at which the rumor leaves short-term memory.
var short_term_expiration := 0.0
## The [method RelationshipsTime.now] at which the rumor leaves long-term memory.
var long_term_expiration := 0.0
## Free for your own use.
var custom_data: Variant = null


static func from_deed(deed: Deed) -> Rumor:
	var rumor := Rumor.new()
	rumor.deed_id = deed.id
	rumor.category = deed.category
	rumor.tag = deed.tag
	rumor.actor_faction_id = deed.actor_faction_id
	rumor.target_faction_id = deed.target_faction_id
	rumor.impact = deed.impact
	rumor.aggression = deed.aggression
	rumor.actor_power_level = deed.actor_power_level
	rumor.traits = deed.traits.duplicate()
	rumor.permitted_evaluators = deed.permitted_evaluators
	rumor.min_affinity_effect = deed.min_affinity_effect
	rumor.max_affinity_effect = deed.max_affinity_effect
	return rumor


## Returns a copy of the rumor's content, without its expiration and memorable state.
func copy() -> Rumor:
	var rumor := Rumor.new()
	rumor.deed_id = deed_id
	rumor.category = category
	rumor.tag = tag
	rumor.actor_faction_id = actor_faction_id
	rumor.target_faction_id = target_faction_id
	rumor.impact = impact
	rumor.aggression = aggression
	rumor.actor_power_level = actor_power_level
	rumor.traits = traits.duplicate()
	rumor.confidence = confidence
	rumor.pleasure = pleasure
	rumor.arousal = arousal
	rumor.dominance = dominance
	rumor.permitted_evaluators = permitted_evaluators
	rumor.min_affinity_effect = min_affinity_effect
	rumor.max_affinity_effect = max_affinity_effect
	rumor.hops = hops
	return rumor


func is_expired_from_short_term() -> bool:
	return RelationshipsTime.now() > short_term_expiration


func is_expired_from_long_term() -> bool:
	return RelationshipsTime.now() > long_term_expiration


## Makes the rumor expire, so it's forgotten at the next memory cleanup.
func expire() -> void:
	short_term_expiration = 0.0
	long_term_expiration = 0.0


func record_data(short_term_left: float, trait_definitions: Array[TraitDefinition]) -> Dictionary:
	return {
		"deed_id": deed_id,
		"category": category.resource_path if category != null else "",
		"tag": tag,
		"actor": actor_faction_id,
		"target": target_faction_id,
		"impact": impact,
		"aggression": aggression,
		"actor_power_level": actor_power_level,
		"traits": FactionDatabase.traits_to_dictionary(traits, trait_definitions),
		"hops": hops,
		"count": count,
		"confidence": confidence,
		"pleasure": pleasure,
		"arousal": arousal,
		"dominance": dominance,
		"permitted_evaluators": permitted_evaluators,
		"min_affinity_effect": min_affinity_effect,
		"max_affinity_effect": max_affinity_effect,
		"short_term_left": short_term_left,
		"long_term_left": long_term_expiration - RelationshipsTime.now(),
	}


static func from_data(data: Dictionary, trait_definitions: Array[TraitDefinition]) -> Rumor:
	var rumor := Rumor.new()
	rumor.deed_id = str(data.get("deed_id", ""))
	var category_path := str(data.get("category", ""))
	if not category_path.is_empty() and ResourceLoader.exists(category_path):
		rumor.category = load(category_path) as DeedCategory
	rumor.tag = str(data.get("tag", ""))
	rumor.actor_faction_id = int(data.get("actor", 0))
	rumor.target_faction_id = int(data.get("target", 0))
	rumor.impact = float(data.get("impact", 0.0))
	rumor.aggression = float(data.get("aggression", 0.0))
	rumor.actor_power_level = float(data.get("actor_power_level", 1.0))
	rumor.traits = FactionDatabase.traits_from_data(data.get("traits", []), trait_definitions)
	rumor.hops = int(data.get("hops", 0))
	rumor.count = int(data.get("count", 1))
	rumor.confidence = float(data.get("confidence", 0.0))
	rumor.pleasure = float(data.get("pleasure", 0.0))
	rumor.arousal = float(data.get("arousal", 0.0))
	rumor.dominance = float(data.get("dominance", 0.0))
	rumor.permitted_evaluators = int(data.get("permitted_evaluators", Deed.PermittedEvaluators.EVERYONE))
	rumor.min_affinity_effect = float(data.get("min_affinity_effect", -100.0))
	rumor.max_affinity_effect = float(data.get("max_affinity_effect", 100.0))
	rumor.memorable = true
	var short_term_left := float(data.get("short_term_left", 0.0))
	rumor.short_term_expiration = RelationshipsTime.now() + short_term_left if short_term_left > 0.0 else 0.0
	rumor.long_term_expiration = RelationshipsTime.now() + float(data.get("long_term_left", 0.0))
	return rumor
