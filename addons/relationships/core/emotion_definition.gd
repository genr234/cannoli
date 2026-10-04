@tool
class_name EmotionDefinition
extends Resource
## A named emotion, defined as a range of PAD values.

@export var name := "":
	set(value):
		name = value
		resource_name = value
@export_group("Pleasure", "pleasure_")
@export_range(-100, 100) var pleasure_min := -100.0
@export_range(-100, 100) var pleasure_max := 100.0
@export_group("Arousal", "arousal_")
@export_range(-100, 100) var arousal_min := -100.0
@export_range(-100, 100) var arousal_max := 100.0
@export_group("Dominance", "dominance_")
@export_range(-100, 100) var dominance_min := -100.0
@export_range(-100, 100) var dominance_max := 100.0


## Whether the PAD values fall within this emotion's ranges.
func contains(pad: Pad) -> bool:
	return (pleasure_min <= pad.pleasure and pad.pleasure <= pleasure_max
			and arousal_min <= pad.arousal and pad.arousal <= arousal_max
			and dominance_min <= pad.dominance and pad.dominance <= dominance_max)


## The distance from the PAD values to the middle of this emotion's ranges.
func distance_to(pad: Pad) -> float:
	return (absf(pad.pleasure - (pleasure_min + pleasure_max) / 2.0)
			+ absf(pad.arousal - (arousal_min + arousal_max) / 2.0)
			+ absf(pad.dominance - (dominance_min + dominance_max) / 2.0))
