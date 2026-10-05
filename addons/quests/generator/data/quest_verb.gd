@icon("../../icons/quest_verb.svg")
class_name QuestVerb
extends Resource
## Something a quester can do to or with an entity, such as Kill or Fetch. Each
## verb in a generated plan becomes a quest node.

## For your own reference.
@export_multiline var description := ""
## Why a quest giver would want this verb done. The giver picks the motive that
## best matches its drive values.
@export var motives: Array[QuestMotive] = []
## The display name. If empty, the asset name is used.
@export var display_name := ""
## Text for each quest node state and UI category.
@export var text: QuestVerbText = QuestVerbText.new()
## World model conditions that must be true to start this verb.
@export var requirements: Array[QuestVerbRequirement] = []
## Changes to the world model when this verb is done.
@export var effects: Array[QuestVerbEffect] = []
## How the verb is completed.
@export var completion: QuestVerbCompletion = QuestVerbCompletion.new()
## Message to send when this verb's node becomes active. Use ':' to separate
## the parameter from the message ("parameter:message").
@export var send_message_on_active := ""
## Message to send when this verb's node is completed. Use ':' to separate
## the parameter from the message ("parameter:message").
@export var send_message_on_completion := ""


func get_asset_name() -> String:
	return QuestGeneratorData.asset_name_of(self)


## The display name, falling back to the asset name.
func get_display_name() -> String:
	return display_name if not display_name.is_empty() else get_asset_name()
