class_name QuestFactSpecifier
extends Resource
## Specifies a [QuestFact] relative to a world model.

@export var negate := false
@export var domain_specifier: QuestDomainSpecifier
@export var entity_specifier: QuestEntitySpecifier
@export var count := 1


func get_fact(world_model: QuestWorldModel) -> QuestFact:
	return QuestFact.new(domain_specifier.get_domain_type(world_model), entity_specifier.get_entity_type(world_model), count)
