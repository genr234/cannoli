class_name QuestPlanStep
extends RefCounted
## One step in a [QuestPlan]: do [member action] to [member fact].

var fact: QuestFact
var action: QuestVerb
var required_counter_value := 1


func _init(p_fact: QuestFact = null, p_action: QuestVerb = null, p_required_counter_value := 1) -> void:
	fact = p_fact
	action = p_action
	required_counter_value = mini(p_fact.count, p_required_counter_value) if p_fact != null else p_required_counter_value


func _to_string() -> String:
	return "%s:%s" % [
		action.get_asset_name() if action != null else "(no-action)",
		fact.entity_type.get_asset_name() if fact != null and fact.entity_type != null else "(no-entity)"]
