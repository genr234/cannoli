@tool
class_name DeedOverride
extends Resource
## How one faction member sees a kind of deed, overriding the deed's own
## values. Used by [DeedEvaluationOverrides].

## The deed tag to override, such as "attack".
@export var tag := "":
	set(value):
		tag = value
		resource_name = value
## Applies to deeds done to this faction or any of its descendants.
@export var target_faction_id := 0
@export_range(-100, 100) var impact := 0.0
@export_range(-100, 100) var aggression := 0.0
@export var traits := PackedFloat32Array()
