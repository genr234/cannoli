class_name QuestVerbRequirement
extends Resource
## A world model condition that must be true before a verb can be used.

## If true, the fact must NOT be present.
@export var negated := false
@export var domain_specifier: QuestDomainSpecifier
@export var entity_specifier: QuestEntitySpecifier
@export var min_count := 1
@export var max_count := 65535
## Optional extra check.
@export var requirement_function: QuestRequirementFunction


static func create(p_domain: QuestDomainSpecifier, p_entity: QuestEntitySpecifier, p_min := 1, p_max := 65535, p_negated := false) -> QuestVerbRequirement:
	var r := QuestVerbRequirement.new()
	r.domain_specifier = p_domain
	r.entity_specifier = p_entity
	r.min_count = p_min
	r.max_count = p_max
	r.negated = p_negated
	return r
