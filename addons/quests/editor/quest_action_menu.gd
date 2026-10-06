@tool
extends PopupMenu
## A popup menu whose items run callables. Used for the graph context menu and
## the outline menu: rebuild it on every request with `reset()`, then add items.

var _actions: Dictionary = {}


func _init() -> void:
	id_pressed.connect(_on_id_pressed)


## Clears the items, the submenus and the registered actions.
func reset() -> void:
	clear()
	_actions.clear()
	for child in get_children():
		if child is PopupMenu:
			remove_child(child)
			child.queue_free()


## Adds an item to `menu` (this menu when omitted) that calls `action` when picked.
func add_action(text: String, action: Callable, enabled := true, menu: PopupMenu = null) -> void:
	if menu == null:
		menu = self
	var id := _actions.size() + 1
	menu.add_item(text, id)
	menu.set_item_disabled(menu.item_count - 1, not enabled)
	_actions[id] = action


## Adds a submenu entry and returns the new submenu, ready for `add_action`.
func add_submenu(title: String) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name = title.replace(" ", "")
	menu.id_pressed.connect(_on_id_pressed)
	add_child(menu)
	add_submenu_node_item(title, menu)
	return menu


## Shows the menu at the mouse cursor.
func popup_at_mouse() -> void:
	position = Vector2i(DisplayServer.mouse_get_position())
	popup()


func _on_id_pressed(id: int) -> void:
	if _actions.has(id):
		_actions[id].call()
