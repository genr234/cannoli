@tool
class_name JuiceAudioBus
extends RefCounted
## Small helpers to find buses and effects by name, shared by the audio feedbacks.


## Returns the bus names as a comma separated string, for property hints.
static func get_bus_hint() -> String:
	var names := PackedStringArray()
	for i in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	return ",".join(names)


## Turns a bus name property into a dropdown that still accepts typed names.
static func apply_bus_hint(property: Dictionary) -> void:
	property.hint = PROPERTY_HINT_ENUM_SUGGESTION
	property.hint_string = get_bus_hint()


## Returns the index of the first effect of [param effect_class] on [param bus_index], or -1.
## A non negative [param index] is returned as is when that slot exists.
static func find_effect(bus_index: int, effect_class: String, index: int = -1) -> int:
	if bus_index < 0:
		return -1
	var count := AudioServer.get_bus_effect_count(bus_index)
	if index >= 0:
		return index if index < count else -1
	for i in count:
		if AudioServer.get_bus_effect(bus_index, i).is_class(effect_class):
			return i
	return -1


## Removes [param effect] from [param bus_index] if it is there.
static func remove_effect(bus_index: int, effect: AudioEffect) -> void:
	if bus_index < 0 or bus_index >= AudioServer.bus_count:
		return
	for i in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, i) == effect:
			AudioServer.remove_bus_effect(bus_index, i)
			return
