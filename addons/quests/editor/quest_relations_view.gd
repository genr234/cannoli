@tool
extends RefCounted
## Draws how the quests of a list refer to each other: one graph node per quest,
## one connection per "requires" or sub-asset reference.


## Fills `graph` with the quests in `quests`, selecting `current`. Returns the
## number of quests shown (x) and links drawn (y).
static func build(graph: GraphEdit, quests: Array[Quest], current: Quest) -> Vector2i:
	var positions := {}
	var index := 0
	for quest in quests:
		if quest == null:
			continue
		var graph_node := GraphNode.new()
		graph_node.name = "q%d" % index
		graph_node.title = quest.title if not quest.title.is_empty() else quest.id
		graph_node.position_offset = Vector2(40 + (index % 4) * 280, 40 + (index / 4) * 150)
		graph_node.resizable = false
		var label := Label.new()
		label.text = quest.id
		graph_node.add_child(label)
		graph_node.set_slot(0, true, 0, Color("f2c14e"), true, 0, Color("f2c14e"))
		graph_node.selected = quest == current
		graph.add_child(graph_node)
		positions[quest.id] = graph_node.name
		index += 1
	var edges := {}
	for quest in quests:
		if quest == null:
			continue
		for required in quest.requires_quests:
			_add_edge(graph, edges, positions, required, quest.id)
		for entry in QuestValidator.collect_subassets(quest):
			var asset: Resource = entry.asset
			if QuestValidator.refers_to_other_quest(asset, quest):
				_add_edge(graph, edges, positions, quest.id, asset.get(QuestValidator._quest_property(asset)))
	return Vector2i(index, edges.size())


static func _add_edge(graph: GraphEdit, edges: Dictionary, positions: Dictionary, from_id: String, to_id: String) -> void:
	var key := "%s>%s" % [from_id, to_id]
	if from_id != to_id and positions.has(from_id) and positions.has(to_id) and not edges.has(key):
		edges[key] = true
		graph.connect_node(positions[from_id], 0, positions[to_id], 0)
