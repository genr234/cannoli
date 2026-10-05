class_name QuestGraphOps
extends RefCounted
## Pure editing operations on a quest's node graph and counters. Used by the
## quest editor canvas, the wizards and the templates. Nothing here depends on
## editor-only APIs, so it is safe to call from tests and tools.

const NODE_SIZE := Vector2(220, 110)
const NODE_PADDING := 55.0
const NODE_STATE_COUNT := 3
const QUEST_STATE_COUNT := 6


## Creates a quest that contains only a Start node, ready to edit.
static func new_quest(id: String, title: String) -> Quest:
	var quest := Quest.new()
	quest.id = id
	quest.title = title
	ensure_state_infos(quest)
	var start := QuestNode.create_start_node(id)
	start.editor_position = Vector2(40, 40)
	ensure_node_state_infos(start)
	quest.node_list.append(start)
	return quest


## Appends a node of `type` and links it from `parent_id` when given.
static func create_node(quest: Quest, type: QuestNode.Type, position: Vector2, parent_id: String = "") -> QuestNode:
	var node := QuestNode.new()
	node.node_type = type
	node.id = unique_node_id(quest, QuestNode.Type.keys()[type].to_lower())
	node.internal_name = QuestNode.Type.keys()[type].capitalize()
	node.editor_position = position
	ensure_node_state_infos(node)
	if type == QuestNode.Type.CONDITION and node.condition_set == null:
		node.condition_set = QuestConditionSet.new()
	quest.node_list.append(node)
	if not parent_id.is_empty():
		connect_nodes(quest, parent_id, node.id)
	return node


## Fills the state info arrays so the inspector always has something to edit.
static func ensure_state_infos(quest: Quest) -> void:
	while quest.state_info_list.size() < QUEST_STATE_COUNT:
		quest.state_info_list.append(QuestStateInfo.new())
	for node in quest.node_list:
		if node != null:
			ensure_node_state_infos(node)


static func ensure_node_state_infos(node: QuestNode) -> void:
	while node.state_info_list.size() < NODE_STATE_COUNT:
		node.state_info_list.append(QuestStateInfo.new())


static func unique_node_id(quest: Quest, prefix: String) -> String:
	var taken := {}
	for node in quest.node_list:
		if node != null:
			taken[node.id] = true
	var index := 1
	while taken.has("%s_%d" % [prefix, index]):
		index += 1
	return "%s_%d" % [prefix, index]


static func find_node(quest: Quest, node_id: String) -> QuestNode:
	for node in quest.node_list:
		if node != null and node.id == node_id:
			return node
	return null


static func node_index(quest: Quest, node_id: String) -> int:
	for index in quest.node_list.size():
		if quest.node_list[index] != null and quest.node_list[index].id == node_id:
			return index
	return -1


## Links `from_id` to `to_id`. Returns false when the link is invalid or exists.
static func connect_nodes(quest: Quest, from_id: String, to_id: String) -> bool:
	var from := find_node(quest, from_id)
	var to := find_node(quest, to_id)
	if from == null or to == null or from == to or from.children.has(to_id):
		return false
	if from.node_type == QuestNode.Type.SUCCESS or from.node_type == QuestNode.Type.FAILURE:
		return false
	if to.node_type == QuestNode.Type.START:
		return false
	from.children.append(to_id)
	return true


static func disconnect_nodes(quest: Quest, from_id: String, to_id: String) -> bool:
	var from := find_node(quest, from_id)
	if from == null:
		return false
	var index := from.children.find(to_id)
	if index < 0:
		return false
	from.children.remove_at(index)
	return true


## Removes every link into and out of the node.
static func clear_connections(quest: Quest, node_id: String) -> void:
	var node := find_node(quest, node_id)
	if node == null:
		return
	node.children = PackedStringArray()
	for other in quest.node_list:
		if other != null:
			var index := other.children.find(node_id)
			if index >= 0:
				other.children.remove_at(index)


## Deletes nodes. The Start node cannot be deleted. Returns how many were removed.
static func delete_nodes(quest: Quest, node_ids: Array) -> int:
	var removed := 0
	var ids := {}
	for index in range(1, quest.node_list.size()):
		var node := quest.node_list[index]
		if node != null and node_ids.has(node.id):
			ids[node.id] = true
	if ids.is_empty():
		return 0
	var kept: Array[QuestNode] = []
	for node in quest.node_list:
		if node != null and ids.has(node.id) and node != quest.node_list[0]:
			removed += 1
			continue
		kept.append(node)
	quest.node_list.assign(kept)
	for node in quest.node_list:
		if node == null:
			continue
		var children := PackedStringArray()
		for child in node.children:
			if not ids.has(child):
				children.append(child)
		node.children = children
	return removed


static func change_type(quest: Quest, node_id: String, type: QuestNode.Type) -> bool:
	var node := find_node(quest, node_id)
	if node == null or node == quest.node_list[0] or type == QuestNode.Type.START:
		return false
	node.node_type = type
	if type == QuestNode.Type.CONDITION and node.condition_set == null:
		node.condition_set = QuestConditionSet.new()
	if type == QuestNode.Type.SUCCESS or type == QuestNode.Type.FAILURE:
		node.children = PackedStringArray()
	return true


## Copies nodes (deeply) for a later paste. Links to nodes outside the set are dropped.
static func copy_nodes(quest: Quest, node_ids: Array) -> Array[QuestNode]:
	var copies: Array[QuestNode] = []
	var source: Array[QuestNode] = []
	for index in range(1, quest.node_list.size()):
		var node := quest.node_list[index]
		if node != null and node_ids.has(node.id):
			source.append(node)
	var ids := {}
	for node in source:
		ids[node.id] = true
	for node in source:
		var copy: QuestNode = node.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		var children := PackedStringArray()
		for child in copy.children:
			if ids.has(child):
				children.append(child)
		copy.children = children
		copies.append(copy)
	return copies


## Adds copies of `clipboard` to the quest with fresh ids, moved by `offset`.
## Returns the new nodes.
static func paste_nodes(quest: Quest, clipboard: Array, offset: Vector2) -> Array[QuestNode]:
	var pasted: Array[QuestNode] = []
	var id_map := {}
	for item: QuestNode in clipboard:
		var copy: QuestNode = item.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		var base: String = QuestNode.Type.keys()[copy.node_type].to_lower()
		var new_id := unique_node_id(quest, base)
		id_map[item.id] = new_id
		copy.id = new_id
		copy.editor_position = item.editor_position + offset
		quest.node_list.append(copy)
		pasted.append(copy)
	for copy in pasted:
		var children := PackedStringArray()
		for child in copy.children:
			if id_map.has(child):
				children.append(id_map[child])
		copy.children = children
	return pasted


static func duplicate_nodes(quest: Quest, node_ids: Array) -> Array[QuestNode]:
	return paste_nodes(quest, copy_nodes(quest, node_ids), Vector2(40, 40))


## Lays out the nodes in levels below the Start node. With fewer than two ids,
## every node is arranged.
static func arrange(quest: Quest, node_ids: Array = []) -> void:
	var all_nodes := node_ids.size() <= 1
	var indices: Array[int] = []
	var offset := Vector2.ZERO
	if all_nodes:
		for index in range(1, quest.node_list.size()):
			indices.append(index)
	else:
		offset = Vector2(INF, INF)
		for id: String in node_ids:
			var index := node_index(quest, id)
			if index >= 0:
				indices.append(index)
				offset = offset.min(quest.node_list[index].editor_position)
		if indices.is_empty():
			return
	var root := 0
	if not all_nodes:
		var children := {}
		for index in indices:
			for child_id in quest.node_list[index].children:
				children[node_index(quest, child_id)] = true
		for index in indices:
			if not children.has(index):
				root = index
				break
	var tree: Array = [[root]]
	var unassigned: Array[int] = indices.duplicate()
	unassigned.erase(root)
	var widest := 1
	var level: Array = tree[0]
	while not level.is_empty():
		var next: Array = []
		for parent_index: int in level:
			for child_id in quest.node_list[parent_index].children:
				var child := node_index(quest, child_id)
				if unassigned.has(child):
					unassigned.erase(child)
					next.append(child)
		if next.is_empty():
			break
		widest = maxi(widest, next.size())
		tree.append(next)
		level = next
	var step_x := NODE_SIZE.x + NODE_PADDING
	var tree_width := widest * step_x
	for row in tree.size():
		var members: Array = tree[row]
		var left := (tree_width - members.size() * step_x) / 2.0
		for column in members.size():
			var node := quest.node_list[members[column]]
			node.editor_position = Vector2(left + column * step_x, 40.0 + row * NODE_SIZE.y * 1.5) + offset
	if not unassigned.is_empty():
		var right := 0.0
		for index in quest.node_list.size():
			if not unassigned.has(index):
				right = maxf(right, quest.node_list[index].editor_position.x)
		for row in unassigned.size():
			quest.node_list[unassigned[row]].editor_position = Vector2(right + step_x, 40.0 + row * NODE_SIZE.y * 1.5)


## Captures the graph and counter structure for undo.
static func snapshot(quest: Quest) -> Dictionary:
	var nodes: Array = []
	for node in quest.node_list:
		nodes.append({
			"node": node,
			"id": node.id if node != null else "",
			"internal_name": node.internal_name if node != null else "",
			"type": node.node_type if node != null else 0,
			"children": node.children.duplicate() if node != null else PackedStringArray(),
			"position": node.editor_position if node != null else Vector2.ZERO,
			"condition_set": node.condition_set if node != null else null,
		})
	return {"nodes": nodes, "counters": quest.counter_list.duplicate()}


static func restore(quest: Quest, snap: Dictionary) -> void:
	var nodes: Array[QuestNode] = []
	for entry: Dictionary in snap.nodes:
		var node: QuestNode = entry.node
		if node != null:
			node.id = entry.id
			node.internal_name = entry.internal_name
			node.node_type = entry.type
			node.children = entry.children.duplicate()
			node.editor_position = entry.position
			node.condition_set = entry.condition_set
		nodes.append(node)
	quest.node_list.assign(nodes)
	quest.counter_list.assign(snap.counters)


static func add_counter(quest: Quest, counter_name: String, min_value := 0, max_value := 99) -> QuestCounter:
	var counter: QuestCounter = null
	for existing in quest.counter_list:
		if existing != null and existing.name == counter_name:
			counter = existing
	if counter == null:
		counter = QuestCounter.new()
		counter.name = counter_name
		quest.counter_list.append(counter)
	counter.min_value = min_value
	counter.max_value = max_value
	counter.initial_value = maxi(0, min_value)
	return counter


static func remove_counter(quest: Quest, counter_name: String) -> void:
	for index in quest.counter_list.size():
		if quest.counter_list[index] != null and quest.counter_list[index].name == counter_name:
			quest.counter_list.remove_at(index)
			return


## Renames a counter and every reference to it inside the quest.
static func rename_counter(quest: Quest, old_name: String, new_name: String) -> void:
	for counter in quest.counter_list:
		if counter != null and counter.name == old_name:
			counter.name = new_name
	for entry in QuestValidator.collect_subassets(quest):
		var asset: Resource = entry.asset
		if "counter_name" in asset and asset.get("counter_name") == old_name and not QuestValidator.refers_to_other_quest(asset, quest):
			asset.set("counter_name", new_name)
		for property in asset.get_property_list():
			if property.type == TYPE_OBJECT and (property.usage & PROPERTY_USAGE_STORAGE):
				var value: Variant = asset.get(property.name)
				if value is QuestNumber and value.counter_name == old_name:
					value.counter_name = new_name
	for counter in quest.counter_list:
		if counter != null and counter.objective_goal != null and counter.objective_goal.counter_name == old_name:
			counter.objective_goal.counter_name = new_name


## One-line summary shown in a graph node's body.
static func node_summary(node: QuestNode) -> String:
	var lines := PackedStringArray()
	if node.condition_set != null:
		for condition in node.condition_set.condition_list:
			if condition != null:
				lines.append(condition.get_editor_name())
	for state in node.state_info_list.size():
		var info := node.state_info_list[state]
		if info == null:
			continue
		for action in info.action_list:
			if action != null:
				lines.append("%s: %s" % [QuestNode.State.keys()[state].capitalize(), action.get_editor_name()])
	return "\n".join(lines)


## Sorts databases' quests in place by "id" or "title".
static func sort_quests(quests: Array, by: String) -> void:
	quests.sort_custom(func(a: Quest, b: Quest) -> bool:
		if a == null or b == null:
			return a != null
		return a.get(by).naturalnocasecmp_to(b.get(by)) < 0)
