@tool
@icon("../icons/gossip.svg")
class_name GossipAnimation
extends Node
## Plays an animation when a faction member gossips.

## If empty, the nearest [FactionMember] is used.
@export var member: FactionMember
@export var animation_player: AnimationPlayer
@export var animation := &""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if member == null:
		member = FactionMember.find_nearest(self)
	if member != null:
		member.gossiped.connect(_on_gossiped)


func _on_gossiped(other: FactionMember) -> void:
	if other != null and animation_player != null and not animation.is_empty():
		animation_player.play(animation)
