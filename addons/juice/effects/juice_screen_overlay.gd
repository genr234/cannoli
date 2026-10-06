@tool
class_name JuiceScreenOverlay
extends CanvasLayer
## A full-screen color rectangle that flashes and fades draw on.
##
## There is one overlay per viewport and per key. [method get_overlay] finds the
## existing one or creates it, so feedbacks never need a node placed by hand. The
## rectangle ignores the mouse and hides itself while it is clear.

## The name prefix of the nodes this class creates.
const NODE_PREFIX := "JuiceOverlay_"

## The color currently drawn. Alpha 0 hides the overlay.
var color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(value):
		color = value
		_refresh()

var _rect: ColorRect


## Returns the overlay for the viewport of [param context], creating it when needed.
## Different [param key] values give independent overlays, for example flash and fade.
## Returns null when the context is not in a tree.
static func get_overlay(context: Node, key: StringName = &"flash", overlay_layer: int = 100) -> JuiceScreenOverlay:
	if context == null or not context.is_inside_tree():
		return null
	var viewport := context.get_viewport()
	if viewport == null:
		return null
	var node_name := NODE_PREFIX + String(key)
	var existing := viewport.get_node_or_null(node_name)
	if existing is JuiceScreenOverlay:
		return existing
	var overlay := JuiceScreenOverlay.new()
	overlay.name = node_name
	overlay.layer = overlay_layer
	viewport.add_child(overlay)
	return overlay


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "Rect"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = color
	add_child(_rect)
	_refresh()


## Hides the overlay.
func clear() -> void:
	color = Color(color.r, color.g, color.b, 0.0)


func _refresh() -> void:
	if _rect == null:
		return
	_rect.color = color
	visible = color.a > 0.0
