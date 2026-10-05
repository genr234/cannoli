class_name QuestModifyAffinityAction
extends QuestAction
## Changes one faction's personal affinity toward another with the Relationships
## addon. Does nothing (with a warning) if the addon isn't installed.

enum Operation { MODIFY_BY, SET_TO }

## Faction ID or name of the judge. Can contain tags such as {QUESTERID}.
@export var judge_faction := ""
## Faction ID or name of the subject. Can contain tags such as {QUESTERID}.
@export var subject_faction := ""
@export var operation := Operation.MODIFY_BY
## The amount to change the affinity by, or the affinity to set.
@export var amount := 0.0


func get_editor_name() -> String:
	if judge_faction.is_empty():
		return "Modify Affinity"
	var operator := "+=" if operation == Operation.MODIFY_BY else "="
	return "Modify Affinity: %s -> %s %s %s" % [judge_faction, subject_faction, operator, str(amount)]


func execute() -> void:
	if not QuestsRelationships.is_available():
		push_warning("Quests: Relationships isn't installed; can't modify affinity.")
		return
	var judge := QuestTags.replace_tags(judge_faction, quest)
	var subject := QuestTags.replace_tags(subject_faction, quest)
	if operation == Operation.MODIFY_BY:
		QuestsRelationships.modify_affinity(judge, subject, amount)
	else:
		QuestsRelationships.set_affinity(judge, subject, amount)
