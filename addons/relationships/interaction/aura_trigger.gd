@tool
@icon("../icons/aura.svg")
class_name AuraTrigger
extends TriggerInteractor
## Changes the PAD of faction members who enter an area, based on how well
## their faction's personality matches the aura's [Traits]. For example, a
## temple's peaceful aura calms peaceful characters.

## Emitted on the aura when it affects a member. The member also emits
## [signal FactionMember.entered_aura].
signal aura_applied(member: FactionMember)

## The aura's personality. If empty, the nearest [Traits] node is used.
@export var traits: Traits
## Seconds before the aura can affect the same member again.
@export var time_between_effects := 300.0
## How strongly the aura affects members.
@export_range(-100, 100) var impact := 0.0
## How submissive (-100) or aggressive (100) the aura is.
@export_range(-100, 100) var aggression := 0.0
## Print when the aura affects a member.
@export var debug := false

var _last_time: Dictionary[FactionMember, float] = {}


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	if traits == null:
		traits = _find_traits()
	if traits == null:
		push_warning("Relationships: %s can't find a Traits node." % get_path())


func _find_traits() -> Traits:
	var node: Node = self
	while node != null:
		for child in node.get_children():
			if child is Traits:
				return child
		node = node.get_parent()
	return null


func _on_member_entered(other: FactionMember) -> void:
	try_affect(other)


## Affects [param other] unless it was affected too recently.
func try_affect(other: FactionMember) -> void:
	if should_affect(other):
		affect(other)


func should_affect(other: FactionMember) -> bool:
	if traits == null or other == null:
		return false
	return not _last_time.has(other) or RelationshipsTime.now() >= _last_time[other] + time_between_effects


## Applies the aura to [param other] right away.
func affect(other: FactionMember) -> void:
	var faction := other.get_faction() if other != null else null
	if traits == null or faction == null:
		return
	_last_time[other] = RelationshipsTime.now()
	if debug:
		print("Relationships: aura %s affects %s" % [get_path(), other.get_path()])
	var alignment := Traits.alignment(traits.traits, faction.traits)
	var pleasure_change := alignment * impact
	var arousal_change := maxf(-alignment * impact, -other.pad.arousal)
	var dominance_change := alignment * (aggression / 100.0) * impact
	other.modify_pad(pleasure_change, pleasure_change, arousal_change, dominance_change)
	aura_applied.emit(other)
	other.entered_aura.emit(self)
