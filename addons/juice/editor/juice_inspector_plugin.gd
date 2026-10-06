@tool
extends EditorInspectorPlugin
## Adds the transport bar, timeline, feedback picker and preset tools to the
## inspector of a [JuicePlayer].

const Header := preload("juice_player_header.gd")
const FeedbacksPanel := preload("juice_feedbacks_panel.gd")

## Set by the editor plugin. Edits go through it so they can be undone.
var undo_redo: EditorUndoRedoManager


func _can_handle(object: Object) -> bool:
	return object is JuicePlayer


func _parse_begin(object: Object) -> void:
	add_custom_control(Header.new(object as JuicePlayer))


func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint,
		_hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if name == "feedbacks":
		add_custom_control(FeedbacksPanel.new(object as JuicePlayer, undo_redo))
	# Keep the normal array editor below the timeline.
	return false
