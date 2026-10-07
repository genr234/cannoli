@tool
extends PopupMenu
## A popup menu whose items run callables. Rebuild it on every request with
## [method reset], then add items and submenus.

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


## Adds an item to [param menu] (this menu when null) that calls [param action].
func add_action(text: String, action: Callable, enabled := true, menu: PopupMenu = null) -> void:
	if menu == null:
		menu = self
	var id := _actions.size() + 1
	menu.add_item(text, id)
	menu.set_item_disabled(menu.item_count - 1, not enabled)
	_actions[id] = action


## Adds a submenu of [param parent] (this menu when null) and returns it.
func add_submenu(title: String, parent: PopupMenu = null) -> PopupMenu:
	if parent == null:
		parent = self
	var menu := PopupMenu.new()
	menu.name = "Sub%d" % parent.get_child_count()
	menu.id_pressed.connect(_on_id_pressed)
	parent.add_child(menu)
	parent.add_submenu_node_item(title, menu)
	return menu


## Shows the menu at the mouse cursor.
func popup_at_mouse() -> void:
	position = Vector2i(DisplayServer.mouse_get_position())
	popup()


func _on_id_pressed(id: int) -> void:
	if _actions.has(id):
		_actions[id].call()
