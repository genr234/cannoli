@tool
@icon("../icons/emotion.svg")
class_name EmotionalState
extends Node
## Names a faction member's emotion based on its PAD values, with emotions you
## define. This is a finer-grained alternative to [enum Pad.Temperament].
##
## Add it as a child of the character, next to its [FactionMember].

## Emitted when the current emotion changes.
signal emotion_changed(emotion_name: String)

enum MatchMode {
	## The emotion whose range contains the PAD values and whose middle is closest.
	BEST_FIT,
	## The first emotion in the list whose range contains the PAD values.
	SEQUENTIAL,
}

const _NO_MATCH_DISTANCE := 600.0

## The member whose PAD values are used. If empty, the nearest [FactionMember] is used.
@export var member: FactionMember
## Emotions to use when [member emotion_definitions] is empty.
@export var emotion_model: EmotionModel
## Emotions for this member. Overrides [member emotion_model].
@export var emotion_definitions: Array[EmotionDefinition] = []
@export var match_mode := MatchMode.BEST_FIT

## Index of the current emotion, or -1.
var current_emotion := -1
## Name of the current emotion, or an empty string.
var current_emotion_name := ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if member == null:
		member = FactionMember.find_nearest(self)
	if member == null:
		push_warning("Relationships: %s can't find a FactionMember." % get_path())
		return
	member.pad_modified.connect(func(_h: float, _p: float, _a: float, _d: float) -> void: update_emotional_state())
	update_emotional_state()


func get_definitions() -> Array[EmotionDefinition]:
	if emotion_definitions.is_empty() and emotion_model != null:
		return emotion_model.emotion_definitions
	return emotion_definitions


## Recomputes the current emotion from the member's PAD values.
func update_emotional_state() -> String:
	var previous := current_emotion_name
	current_emotion = get_current_emotion()
	var definitions := get_definitions()
	current_emotion_name = definitions[current_emotion].name if current_emotion >= 0 else ""
	if current_emotion_name != previous:
		emotion_changed.emit(current_emotion_name)
	return current_emotion_name


## Returns the index of the emotion matching the member's PAD values, or -1.
func get_current_emotion() -> int:
	if member == null:
		return -1
	var definitions := get_definitions()
	var closest := -1
	var closest_distance := _NO_MATCH_DISTANCE
	for i in definitions.size():
		var definition := definitions[i]
		if definition == null or not definition.contains(member.pad):
			continue
		if match_mode == MatchMode.SEQUENTIAL:
			return i
		var distance := definition.distance_to(member.pad)
		if distance < closest_distance:
			closest_distance = distance
			closest = i
	return closest
