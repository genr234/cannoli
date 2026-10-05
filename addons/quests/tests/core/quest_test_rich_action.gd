class_name QuestTestRichAction
extends QuestAction
## An action for serializer tests that has properties of many types.

@export var text := ""
@export var amount := 3
@export var ratio := 0.25
@export var flag := true
@export var position := Vector2(1.5, -2.0)
@export var tint := Color(0.1, 0.2, 0.3, 1.0)
@export var names: PackedStringArray
@export var number: QuestNumber
@export var value: QuestMessageValue
@export var texture: Texture2D
@export var mapping := {}
@export var nested: Array[QuestAction]
@export var kind := QuestNode.Type.CONDITION
