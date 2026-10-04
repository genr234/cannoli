@tool
class_name RangeAnimation
extends Resource
## An animation that applies to a range of values (such as affinity) and a
## set of temperaments.

## The animation to play on the [AnimationPlayer], if any.
@export var animation := &""
@export_range(-100, 100) var min := -100.0
@export_range(-100, 100) var max := 100.0
## Only applies when the member's temperament is one of these.
@export_flags("Exuberant", "Bored", "Dependent", "Disdainful", "Relaxed", "Anxious", "Docile", "Hostile", "Neutral")
var temperament := Pad.ALL_TEMPERAMENTS


static func create(animation_name: StringName, range_min: float, range_max: float, temperaments := Pad.ALL_TEMPERAMENTS) -> RangeAnimation:
	var range_animation := RangeAnimation.new()
	range_animation.animation = animation_name
	range_animation.min = range_min
	range_animation.max = range_max
	range_animation.temperament = temperaments
	return range_animation


## Whether [param value] is in range and [param pad]'s temperament matches.
func applies_to(value: float, pad: Pad) -> bool:
	return min <= value and value <= max and pad.matches_temperament(temperament)
