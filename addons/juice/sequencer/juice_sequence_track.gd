@tool
@icon("res://addons/juice/icons/sequencer.svg")
class_name JuiceSequenceTrack
extends Resource
## One lane of a [JuiceSequence], for example the kick drum or the "hit" cue.

## The number that raw recorded notes use to say which track they belong to.
@export var id: int = 0
## A name shown in editors.
@export var label: String = ""
## The color of this track in editors.
@export var color: Color = Color(0.94, 0.97, 1.0)
## The input action that records a note on this track while recording.
@export var action: StringName = &""
## Inactive tracks are muted: they trigger nothing.
@export var active: bool = true


func _validate_property(property: Dictionary) -> void:
	if property.name != "action":
		return
	# Offers the project's input actions as suggestions, without forbidding other names.
	var names: PackedStringArray = []
	for setting in ProjectSettings.get_property_list():
		var setting_name: String = setting.name
		if setting_name.begins_with("input/"):
			names.append(setting_name.trim_prefix("input/"))
	property.hint = PROPERTY_HINT_ENUM_SUGGESTION
	property.hint_string = ",".join(names)
