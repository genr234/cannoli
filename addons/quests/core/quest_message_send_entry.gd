class_name QuestMessageSendEntry
extends Resource
## A message that a [QuestMessageEvents] node can send.

## The id of the target entity. If empty, [member target_path] is used.
@export var target_id := ""
## The target node, relative to the [QuestMessageEvents] node.
@export var target_path := NodePath()
@export var message := ""
@export var parameter := ""
