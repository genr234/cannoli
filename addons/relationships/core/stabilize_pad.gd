@tool
@icon("../icons/stabilize.svg")
class_name StabilizePad
extends Node
## Gradually moves a faction member's PAD values toward targets, for example
## to let arousal cool down to 0 over time.
##
## Add it as a child of the character, next to its [FactionMember].

## The member to stabilize. If empty, the nearest [FactionMember] is used.
@export var member: FactionMember

@export_group("Happiness", "happiness_")
@export var happiness_stabilize := false
@export_range(-100, 100) var happiness_target := 0.0
## Change per second.
@export var happiness_rate := 0.1

@export_group("Pleasure", "pleasure_")
@export var pleasure_stabilize := false
@export_range(-100, 100) var pleasure_target := 0.0
## Change per second.
@export var pleasure_rate := 0.1

@export_group("Arousal", "arousal_")
@export var arousal_stabilize := false
@export_range(-100, 100) var arousal_target := 0.0
## Change per second.
@export var arousal_rate := 0.1

@export_group("Dominance", "dominance_")
@export var dominance_stabilize := false
@export_range(-100, 100) var dominance_target := 0.0
## Change per second.
@export var dominance_rate := 0.1


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	if member == null:
		member = FactionMember.find_nearest(self)
	if member == null:
		push_warning("Relationships: %s can't find a FactionMember." % get_path())
		set_process(false)


func _process(_delta: float) -> void:
	var pad := member.pad
	var delta := RelationshipsTime.delta()
	var happiness := _approach(pad.happiness, happiness_stabilize, happiness_target, happiness_rate, delta)
	var pleasure := _approach(pad.pleasure, pleasure_stabilize, pleasure_target, pleasure_rate, delta)
	var arousal := _approach(pad.arousal, arousal_stabilize, arousal_target, arousal_rate, delta)
	var dominance := _approach(pad.dominance, dominance_stabilize, dominance_target, dominance_rate, delta)
	if happiness != pad.happiness or pleasure != pad.pleasure or arousal != pad.arousal or dominance != pad.dominance:
		member.modify_pad(happiness - pad.happiness, pleasure - pad.pleasure, arousal - pad.arousal, dominance - pad.dominance)


static func _approach(current: float, enabled: bool, target: float, rate: float, delta: float) -> float:
	if not enabled:
		return current
	return move_toward(current, target, rate * delta)
