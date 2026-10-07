@tool
@icon("res://addons/behaviors/icons/relationship.svg")
class_name BehaviorAddDeed
extends BehaviorAction
## Reports a deed done by the actor, so factions can react to it.
##
## The actor needs a faction member. When it has a deed reporter whose library knows the
## tag, the library's template is used. Otherwise the deed is built from [member impact]
## and [member aggression]. Needs the Relationships package. Fails, with one warning,
## when it is missing.

## The name of the deed.
@export var tag: String = ""
## Who the deed was done to: a faction ID or name, or a node with a faction member.
## Bind it to a variable to use a node.
@export var target: Variant = ""
## A node to use as the target when [member target] is empty, relative to the actor.
@export var target_path: NodePath = NodePath()
## Scales the impact of the deed.
@export_range(0.0, 10.0, 0.01, "or_greater") var magnitude: float = 1.0
## How much the deed improves (positive) or hurts (negative) the target's opinion, with
## no template.
@export_range(-100.0, 100.0, 0.1) var impact: float = 0.0
## How aggressive the deed was, with no template.
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.0

var _warned: bool = false


func _on_update(_delta: float) -> Status:
	if not BehaviorsRelationships.has_manager():
		if not _warned:
			_warned = true
			push_warning("%s: the Relationships package is not available." % get_display_name())
		return Status.FAILURE
	var who: Variant = target
	if (who == null or (who is String and who.is_empty())) and not target_path.is_empty():
		who = get_node_from_actor(target_path)
	if who is String and who.is_valid_int():
		who = int(who)
	return Status.SUCCESS if BehaviorsRelationships.report_deed(actor, tag, who, magnitude, impact, aggression) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not BehaviorsRelationships.is_available():
		warnings.append("Requires the Relationships package.")
	if tag.is_empty():
		warnings.append("Add Deed has no tag.")
	return warnings


func _get_graph_text() -> String:
	return tag
