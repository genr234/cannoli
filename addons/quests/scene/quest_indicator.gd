class_name QuestIndicator
extends Node
## Shows one child node per [enum Quest.IndicatorState], such as an exclamation
## mark over a quest giver. Works with 2D, 3D and Control children.
##
## Assign the indicator nodes below, or name children after the states ("Offer",
## "OfferDisabled", "Talk", "Custom0"...). Names ignore case, spaces and underscores.
## A [QuestIndicatorManager] shows the highest-priority one.

@export var offer_disabled: Node
@export var offer: Node
@export var talk_disabled: Node
@export var talk: Node
@export var interact_disabled: Node
@export var interact: Node
## Indicators for the custom states CUSTOM_0 to CUSTOM_9.
@export var custom: Array[Node] = []


## Shows or hides the indicator for the state with the given index
## (see [enum Quest.IndicatorState]).
func set_indicator(index: int, value: bool) -> void:
	_set_active(get_indicator_node(index), value)


## Returns the node for the given indicator state, or null.
func get_indicator_node(index: int) -> Node:
	var node: Node = null
	match index:
		Quest.IndicatorState.OFFER_DISABLED:
			node = offer_disabled
		Quest.IndicatorState.OFFER:
			node = offer
		Quest.IndicatorState.TALK_DISABLED:
			node = talk_disabled
		Quest.IndicatorState.TALK:
			node = talk
		Quest.IndicatorState.INTERACT_DISABLED:
			node = interact_disabled
		Quest.IndicatorState.INTERACT:
			node = interact
		_:
			var custom_index := index - Quest.IndicatorState.CUSTOM_0
			if custom_index >= 0 and custom_index < custom.size():
				node = custom[custom_index]
	if node == null and index > Quest.IndicatorState.NONE and index < Quest.IndicatorState.keys().size():
		node = _find_child_for_state(index)
	return node


## Hides every indicator.
func hide_all_indicators() -> void:
	for index in range(Quest.IndicatorState.OFFER_DISABLED, Quest.IndicatorState.keys().size()):
		set_indicator(index, false)


func _find_child_for_state(index: int) -> Node:
	var wanted := _normalize(String(Quest.IndicatorState.keys()[index]))
	for child in get_children():
		if _normalize(String(child.name)) == wanted:
			return child
	return null


func _normalize(text: String) -> String:
	return text.to_lower().replace("_", "").replace(" ", "")


func _set_active(node: Node, value: bool) -> void:
	if node == null:
		return
	if node is CanvasItem or node is Node3D:
		node.set("visible", value)
	node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
