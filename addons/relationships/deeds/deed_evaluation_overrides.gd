@tool
@icon("../icons/deed.svg")
class_name DeedEvaluationOverrides
extends Node
## Lets a faction member see certain deeds differently. For example, a
## bandit might consider robbing merchants a good deed.
##
## Add it as a child of the character, next to its [FactionMember].

## The member whose [member FactionMember.evaluate_rumor] is replaced. If
## empty, the nearest [FactionMember] is used.
@export var member: FactionMember
@export var deed_overrides: Array[DeedOverride] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if member == null:
		member = FactionMember.find_nearest(self)
	if member == null:
		push_warning("Relationships: %s can't find a FactionMember." % get_path())
		return
	member.evaluate_rumor = evaluate_rumor


## Evaluates the rumor with the first matching override's values, or as usual
## if none matches.
func evaluate_rumor(rumor: Rumor, source: FactionMember) -> Rumor:
	if rumor == null:
		return null
	var database := member.get_database()
	for deed_override in deed_overrides:
		if deed_override == null or deed_override.tag != rumor.tag:
			continue
		var matches_target := deed_override.target_faction_id == rumor.target_faction_id
		if not matches_target and database != null:
			matches_target = database.faction_has_ancestor(rumor.target_faction_id, deed_override.target_faction_id)
		if not matches_target:
			continue
		if member.debug_evaluation:
			print("Relationships: %s uses an override to evaluate '%s'." % [member.get_path(), rumor.tag])
		var overridden := rumor.copy()
		overridden.impact = deed_override.impact
		overridden.aggression = deed_override.aggression
		overridden.traits = deed_override.traits.duplicate()
		return member.default_evaluate_rumor(overridden, source)
	return member.default_evaluate_rumor(rumor, source)
