@tool
@icon("../icons/greeting.svg")
class_name GreetingTrigger
extends TriggerInteractor
## Greets faction members who enter an area, choosing a greeting from the
## affinity to them and the member's current temperament.

## Emitted with the index of the chosen entry in [member greetings], or -1 if
## none applied.
signal greeting_chosen(other: FactionMember, greeting_index: int)

## The member that greets. If empty, the nearest [FactionMember] is used.
@export var member: FactionMember
## Plays the chosen greeting's animation, if set.
@export var animation_player: AnimationPlayer
## Seconds before greeting the same member again.
@export var time_between_greetings := 300.0
## The first greeting whose affinity range and temperaments match is used.
@export var greetings: Array[RangeAnimation] = [
	RangeAnimation.create(&"", -100.0, -25.0),
	RangeAnimation.create(&"", -25.0, 25.0),
	RangeAnimation.create(&"", 25.0, 100.0),
]

var _last_greeting: Dictionary[FactionMember, float] = {}


func _ready() -> void:
	super()
	if not Engine.is_editor_hint() and member == null:
		member = FactionMember.find_nearest(self)


func _on_member_entered(other: FactionMember) -> void:
	try_greeting(other)


## Greets [param other] unless it was greeted too recently.
func try_greeting(other: FactionMember) -> void:
	if should_greet(other):
		greet(other)


func should_greet(other: FactionMember) -> bool:
	if member == null or other == null or other == member:
		return false
	return not _last_greeting.has(other) or RelationshipsTime.now() >= _last_greeting[other] + time_between_greetings


## Greets [param other] right away.
func greet(other: FactionMember) -> void:
	if member == null or other == null or other == member:
		return
	_last_greeting[other] = RelationshipsTime.now()
	member.greeted.emit(other)
	var affinity := member.get_affinity(other)
	var chosen := -1
	for i in greetings.size():
		if greetings[i] != null and greetings[i].applies_to(affinity, member.pad):
			chosen = i
			break
	if chosen >= 0 and animation_player != null and not greetings[chosen].animation.is_empty():
		animation_player.play(greetings[chosen].animation)
	greeting_chosen.emit(other, chosen)
