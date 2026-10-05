@icon("../icons/quest_identity.svg")
class_name QuestIdentity
extends Node
## Gives a character or object an id, name and picture for the quest system.
## Put it under the node it identifies.
##
## The id is how quests refer to the entity: as a quest giver, as the sender
## or target of a message, as the speaker of a node, and so on. If the id is
## blank, the parent node's name is used.

@export var id := ""
@export var display_name := ""
@export var image: Texture2D
## The quest list that belongs to this entity, if it has more than one or it
## isn't a child of the same node.
@export var quest_list: QuestList

static var _by_id := {}


func _enter_tree() -> void:
	if id.is_empty():
		id = fallback_name(self)
	_by_id[id] = self


func _exit_tree() -> void:
	if _by_id.get(id) == self:
		_by_id.erase(id)


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return id if not id.is_empty() else fallback_name(self)


func get_participant() -> QuestParticipant:
	return QuestParticipant.new(id if not id.is_empty() else fallback_name(self), get_display_name(), image)


## The identity of [param node]: the node itself, its children, its ancestors,
## and the children of its ancestors. Null if there isn't one.
static func find_for(node: Node) -> QuestIdentity:
	if node == null:
		return null
	if node is QuestIdentity:
		return node
	var found := _find_in_children(node)
	if found != null:
		return found
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is QuestIdentity:
			return ancestor
		for child in ancestor.get_children():
			if child is QuestIdentity:
				return child
		ancestor = ancestor.get_parent()
	return null


static func _find_in_children(node: Node) -> QuestIdentity:
	for child in node.get_children():
		if child is QuestIdentity:
			return child
	for child in node.get_children():
		var found := _find_in_children(child)
		if found != null:
			return found
	return null


## The identity with the given id, or null.
static func find_by_id(p_id: String) -> QuestIdentity:
	var identity: Variant = _by_id.get(p_id)
	return identity if is_instance_valid(identity) else null


## The name used when no id is set: the parent's name, or the node's own name
## if it has no parent or its parent is the root of the tree.
static func fallback_name(node: Node) -> String:
	var parent := node.get_parent()
	if parent == null or (node.is_inside_tree() and parent == node.get_tree().root):
		return String(node.name)
	return String(parent.name)
