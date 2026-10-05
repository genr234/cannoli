class_name QuestSceneLookup
extends RefCounted
## Finds scene nodes for quest actions by group name, [QuestIdentity] id or node name.


## Returns the active [SceneTree], or null.
static func get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Returns every node matching [param key]: members of the group, the characters
## owning a [QuestIdentity] with that id, or (as a last resort) a node with that name.
static func find_nodes(key: String) -> Array[Node]:
	var result: Array[Node] = []
	if key.is_empty():
		return result
	var tree := get_tree()
	if tree == null:
		return result
	for node in tree.get_nodes_in_group(key):
		result.append(node)
	if not result.is_empty():
		return result
	var root := tree.root
	var identity := QuestIdentity.find_by_id(key)
	if identity != null and identity.get_parent() != null:
		result.append(identity.get_parent())
		return result
	var by_name := root.find_child(key, true, false)
	if by_name != null:
		result.append(by_name)
	return result


## Returns the first node matching [param key], or null.
static func find_node(key: String) -> Node:
	var nodes := find_nodes(key)
	return nodes[0] if not nodes.is_empty() else null


## Returns the first node under [param node] (itself included) that is one of [param classes].
static func find_first_of(node: Node, classes: PackedStringArray) -> Node:
	if node == null:
		return null
	for c in classes:
		if node.is_class(c):
			return node
	for c in classes:
		var found := node.find_children("*", c, true, false)
		if not found.is_empty():
			return found[0]
	return null


## Returns the id string for a message participant specifier. [param specifier] is a
## [enum QuestMessages.Participant]; the result may still contain tags such as {QUESTERID}.
static func get_id_by_specifier(specifier: int, id: String) -> String:
	match specifier:
		QuestMessages.Participant.ANY:
			return ""
		QuestMessages.Participant.QUESTER:
			return QuestTags.QUESTERID
		QuestMessages.Participant.QUEST_GIVER:
			return QuestTags.QUESTGIVERID
	return id


## Returns the readable name of a [enum Quest.State] value.
static func quest_state_name(state: int) -> String:
	return String(Quest.State.keys()[clampi(state, 0, Quest.State.size() - 1)]).capitalize()


## Returns the readable name of a [enum QuestNode.State] value.
static func node_state_name(state: int) -> String:
	return String(QuestNode.State.keys()[clampi(state, 0, QuestNode.State.size() - 1)]).capitalize()
