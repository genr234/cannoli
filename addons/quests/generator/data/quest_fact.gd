class_name QuestFact
extends RefCounted
## "There are [member count] entities of [member entity_type] in [member domain_type]."
## A fact is one entry in a [QuestWorldModel].

var domain_type: QuestDomainType
var entity_type: QuestEntityType
var count := 0
## Computed by [method QuestWorldModel.compute_urgency].
var urgency := 0.0


func _init(p_domain_type: QuestDomainType = null, p_entity_type: QuestEntityType = null, p_count := 0, p_urgency := 0.0) -> void:
	domain_type = p_domain_type
	entity_type = p_entity_type
	count = p_count
	urgency = p_urgency


## Returns a copy of [param source], or null if it is null.
static func copy_of(source: QuestFact) -> QuestFact:
	if source == null:
		return null
	return QuestFact.new(source.domain_type, source.entity_type, source.count, source.urgency)


func _to_string() -> String:
	return "%d %s in %s" % [count,
			entity_type.get_asset_name() if entity_type != null else "(no-entity)",
			domain_type.get_asset_name() if domain_type != null else "(no-domain)"]
