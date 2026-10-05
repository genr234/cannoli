@tool
extends GraphNode
## One quest node on the canvas: colored by type, with a body that lists its
## conditions and actions. While a game is running it also shows the node's live state.

const TYPE_COLORS: Array[Color] = [
	Color("3f8f5a"),  # START
	Color("9aa63a"),  # SUCCESS
	Color("b84a4a"),  # FAILURE
	Color("6b7388"),  # PASSTHROUGH
	Color("3f72b8"),  # CONDITION
]
const STATE_COLORS: Array[Color] = [
	Color(0, 0, 0, 0),
	Color("f2c14e"),
	Color("8fcf6b"),
]

var quest_node: QuestNode
var _body := Label.new()
var _badge := Label.new()


func setup(node: QuestNode, issue_text := "") -> void:
	quest_node = node
	title = node.internal_name if not node.internal_name.is_empty() else QuestNode.Type.keys()[node.node_type].capitalize()
	if node.is_optional:
		title += " (optional)"
	resizable = false
	custom_minimum_size.x = QuestGraphOps.NODE_SIZE.x
	var summary := QuestGraphOps.node_summary(node)
	_body.text = summary if not summary.is_empty() else node.id
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = QuestGraphOps.NODE_SIZE.x - 20.0
	_body.add_theme_font_size_override("font_size", 12)
	add_child(_body)
	_badge.add_theme_font_size_override("font_size", 11)
	_badge.visible = false
	add_child(_badge)
	var is_start := node.node_type == QuestNode.Type.START
	var is_end := node.node_type == QuestNode.Type.SUCCESS or node.node_type == QuestNode.Type.FAILURE
	set_slot(0, not is_start, 0, TYPE_COLORS[node.node_type], not is_end, 0, TYPE_COLORS[node.node_type])
	var tip := "%s  [%s]" % [QuestNode.Type.keys()[node.node_type].capitalize(), node.id]
	if node.join_mode != QuestNode.JoinMode.ANY:
		tip += "\nJoin: %s" % QuestNode.JoinMode.keys()[node.join_mode].capitalize()
	if not summary.is_empty():
		tip += "\n" + summary
	if not issue_text.is_empty():
		tip += "\n\nProblems:\n" + issue_text
		title += "  !"
	tooltip_text = tip
	_apply_colors(false)
	set_runtime_state(-1)


## `state` is a QuestNode.State value, or -1 when no game is running.
func set_runtime_state(state: int) -> void:
	if state < 0:
		_badge.visible = false
		self_modulate = Color.WHITE
		_apply_colors(false)
		return
	_badge.visible = true
	_badge.text = QuestNode.State.keys()[state].capitalize()
	_badge.add_theme_color_override("font_color", STATE_COLORS[state] if state > 0 else Color(0.6, 0.62, 0.68))
	self_modulate = Color(1, 1, 1, 0.55) if state == QuestNode.State.INACTIVE else Color.WHITE
	_apply_colors(state == QuestNode.State.ACTIVE, STATE_COLORS[state] if state > 0 else Color(0, 0, 0, 0))


func _apply_colors(highlight: bool, highlight_color := Color.WHITE) -> void:
	var color := TYPE_COLORS[quest_node.node_type] if quest_node != null else TYPE_COLORS[3]
	for entry in [["titlebar", color], ["titlebar_selected", color.lightened(0.25)]]:
		var style := StyleBoxFlat.new()
		style.bg_color = entry[1]
		style.set_corner_radius_all(3)
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		add_theme_stylebox_override(entry[0], style)
	for entry in [["panel", false], ["panel_selected", true]]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.13, 0.14, 0.17, 0.96)
		panel.set_corner_radius_all(3)
		panel.corner_radius_top_left = 0
		panel.corner_radius_top_right = 0
		panel.set_border_width_all(2 if (highlight or entry[1]) else 1)
		panel.border_color = highlight_color if highlight else (color.lightened(0.4) if entry[1] else color.darkened(0.2))
		panel.content_margin_left = 10
		panel.content_margin_right = 10
		panel.content_margin_top = 6
		panel.content_margin_bottom = 6
		add_theme_stylebox_override(entry[0], panel)
