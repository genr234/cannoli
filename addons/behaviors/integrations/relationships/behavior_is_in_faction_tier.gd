@tool
@icon("res://addons/behaviors/icons/relationship.svg")
class_name BehaviorIsInFactionTier
extends BehaviorCondition
## Succeeds when a faction's affinity toward another is in a named tier.
##
## Tiers are the named bands of the Relationships package, such as "Friendly" or
## "Hostile". Needs that package. Fails, with one warning, when it is missing.

## The faction that feels the affinity, by ID or name. Empty uses the faction of the
## actor's faction member.
@export var judge: String = ""
## The faction it feels toward, by ID or name. Empty uses the actor's faction.
@export var subject: String = ""
## The name of the tier.
@export var tier_name: String = ""
## Also succeeds in any higher tier.
@export var at_least: bool = false
## The variable that receives the name of the current tier.
@export var store_tier: String = ""

var _warned: bool = false


func _on_update(_delta: float) -> Status:
	if not BehaviorsRelationships.has_manager():
		if not _warned:
			_warned = true
			push_warning("%s: the Relationships package is not available." % get_display_name())
		return Status.FAILURE
	var judge_faction: Variant = int(judge) if judge.is_valid_int() else judge
	var subject_faction: Variant = int(subject) if subject.is_valid_int() else subject
	if not store_tier.is_empty():
		set_var(StringName(store_tier), BehaviorsRelationships.get_tier_name(actor, judge_faction, subject_faction))
	return Status.SUCCESS if BehaviorsRelationships.is_tier(actor, judge_faction, subject_faction, tier_name, at_least) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not BehaviorsRelationships.is_available():
		warnings.append("Requires the Relationships package.")
	if tier_name.is_empty():
		warnings.append("Is In Faction Tier has no tier name.")
	return warnings


func _get_graph_text() -> String:
	return ("%s+" if at_least else "%s") % tier_name
