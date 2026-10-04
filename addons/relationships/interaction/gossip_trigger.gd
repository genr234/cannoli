@tool
@icon("../icons/gossip.svg")
class_name GossipTrigger
extends TriggerInteractor
## Shares rumors with friendly faction members who enter an area.
##
## Both members share their long-term memories with each other, as long as
## this member's affinity to the other is above zero.

## The member that gossips. If empty, the nearest [FactionMember] is used.
@export var member: FactionMember
## Seconds before gossiping with the same member again.
@export var time_between_gossip := 300.0
## Members whose body is in this group never gossip.
@export var player_group := &"player"

var _last_gossip: Dictionary[FactionMember, float] = {}


func _ready() -> void:
	super()
	if not Engine.is_editor_hint() and member == null:
		member = FactionMember.find_nearest(self)


func _on_member_entered(other: FactionMember) -> void:
	try_gossip(other)


## Gossips with [param other] if they're friendly and haven't gossiped recently.
func try_gossip(other: FactionMember) -> void:
	if should_gossip(other):
		gossip(other)


func should_gossip(other: FactionMember) -> bool:
	if member == null or other == null or other == member or other.get_base_faction_id() == FactionDatabase.PLAYER_FACTION_ID:
		return false
	var other_body := other.get_body()
	if other_body != null and other_body.is_in_group(player_group):
		return false
	var too_recent := _last_gossip.has(other) and RelationshipsTime.now() < _last_gossip[other] + time_between_gossip
	return not too_recent and member.get_affinity(other) > 0.0


## Gossips with [param other] right away.
func gossip(other: FactionMember) -> void:
	if member == null or other == null:
		return
	update_last_gossip_time(other)
	for trigger in _gossip_triggers_of(other):
		trigger.update_last_gossip_time(member)
	member.share_rumors(other)
	other.share_rumors(member)
	member.gossiped.emit(other)
	other.gossiped.emit(member)


func update_last_gossip_time(other: FactionMember) -> void:
	_last_gossip[other] = RelationshipsTime.now()


func _gossip_triggers_of(other: FactionMember) -> Array[GossipTrigger]:
	var result: Array[GossipTrigger] = []
	var other_body := other.get_body()
	if other_body == null:
		return result
	for node in other_body.find_children("*", "", true, false):
		if node is GossipTrigger and node.member == other:
			result.append(node)
	return result
