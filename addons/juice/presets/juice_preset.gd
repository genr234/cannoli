@tool
@icon("res://addons/juice/icons/preset.svg")
class_name JuicePreset
extends Resource
## A saved list of feedbacks that can be loaded into any [JuicePlayer].
##
## Save one from the player's inspector ("Save as preset") and load it back with
## "Load preset". At runtime, [method apply_to] fills a player from a preset.

## What this preset is for. Shown in tooltips only.
@export_multiline var description: String = ""
## The feedbacks of the preset.
@export var feedbacks: Array[JuiceFeedback] = []


## Returns independent copies of the feedbacks, so a player never edits the preset.
func make_copies() -> Array[JuiceFeedback]:
	var copies: Array[JuiceFeedback] = []
	for feedback in feedbacks:
		if feedback != null:
			copies.append(feedback.duplicate(true) as JuiceFeedback)
	return copies


## Copies the feedbacks into [param player]. With [param replace] the old list is dropped,
## otherwise they are added at the end. Call [method JuicePlayer.initialize] afterwards
## if the player was already initialized.
func apply_to(player: JuicePlayer, replace: bool = false) -> void:
	var list: Array[JuiceFeedback] = [] if replace else player.feedbacks.duplicate()
	list.append_array(make_copies())
	player.feedbacks = list
