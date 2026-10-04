@tool
@icon("../icons/deed.svg")
class_name DeedReactions
extends Node
## Reacts when a faction member witnesses a deed, choosing a reaction from
## the pleasure the deed caused and the member's temperament.

## Emitted with the index of the chosen entry in [member reactions].
signal reacted(reaction_index: int, rumor: Rumor)

## If empty, the nearest [FactionMember] is used.
@export var member: FactionMember
## Plays the chosen reaction's animation, if set.
@export var animation_player: AnimationPlayer
## Seconds before reacting again.
@export var time_between_reactions := 300.0
## The first reaction whose pleasure range and temperaments match is used.
@export var reactions: Array[RangeAnimation] = [
	RangeAnimation.create(&"", -100.0, -25.0),
	RangeAnimation.create(&"", -25.0, 25.0),
	RangeAnimation.create(&"", 25.0, 100.0),
]

## The [method RelationshipsTime.now] at which the member can react again.
var time_when_can_react := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if member == null:
		member = FactionMember.find_nearest(self)
	if member != null:
		member.deed_witnessed.connect(_on_deed_witnessed)


func _on_deed_witnessed(rumor: Rumor) -> void:
	if rumor == null or RelationshipsTime.now() < time_when_can_react:
		return
	time_when_can_react = RelationshipsTime.now() + time_between_reactions
	for i in reactions.size():
		var reaction := reactions[i]
		if reaction != null and reaction.applies_to(rumor.pleasure, member.pad):
			if animation_player != null and not reaction.animation.is_empty():
				animation_player.play(reaction.animation)
			reacted.emit(i, rumor)
			return
