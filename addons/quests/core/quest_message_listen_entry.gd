class_name QuestMessageListenEntry
extends Resource
## A message that a [QuestMessageEvents] node listens for.

## Only messages from this id count. Empty means any sender.
@export var required_sender_id := ""
## Only messages from this node count. Relative to the [QuestMessageEvents] node.
@export var required_sender_path := NodePath()
@export var required_target_id := ""
@export var required_target_path := NodePath()
@export var message := ""
## Only messages with this parameter count. Empty means any parameter.
@export var parameter := ""
