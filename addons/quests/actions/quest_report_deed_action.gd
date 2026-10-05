class_name QuestReportDeedAction
extends QuestAction
## Reports a deed to the Relationships addon, so witnesses can react to it.
## Does nothing (with a warning) if the addon isn't installed.

## The character that committed the deed: a group name, [QuestIdentity] id or node
## name. Blank uses the quester's character (the node whose [QuestIdentity] has the quester's id).
@export var actor := ""
## The deed's tag, such as "attack" or "compliment".
@export var deed_tag := ""
## The faction (ID or name) the deed was done to, or a character found like the actor.
@export var target := ""
## Treat [member target] as a character instead of a faction.
@export var target_is_character := false
## Scales the deed's impact.
@export var magnitude := 1.0
## Impact (-100 to 100) used when the actor has no deed template for the tag.
@export_range(-100.0, 100.0) var impact := 0.0
## Aggression (-100 to 100) used when the actor has no deed template for the tag.
@export_range(-100.0, 100.0) var aggression := 0.0


func get_editor_name() -> String:
	if deed_tag.is_empty():
		return "Report Deed"
	return "Report Deed: %s -> %s '%s'" % [actor if not actor.is_empty() else "quester", target, deed_tag]


func execute() -> void:
	if deed_tag.is_empty():
		return
	if not QuestsRelationships.is_available():
		push_warning("Quests: Relationships isn't installed; can't report deed '%s'." % deed_tag)
		return
	var actor_key := QuestTags.replace_tags(actor if not actor.is_empty() else QuestTags.QUESTERID, quest)
	var actor_node := QuestSceneLookup.find_node(actor_key)
	if actor_node == null:
		push_warning("Quests: QuestReportDeedAction can't find actor '%s'." % actor_key)
		return
	var target_key := QuestTags.replace_tags(target, quest)
	var target_arg: Variant = target_key
	if target_is_character:
		target_arg = QuestSceneLookup.find_node(target_key)
		if target_arg == null:
			push_warning("Quests: QuestReportDeedAction can't find target '%s'." % target_key)
			return
	QuestsRelationships.report_deed(actor_node, deed_tag, target_arg, magnitude, impact, aggression)
