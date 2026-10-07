@tool
class_name BehaviorGraphOps
extends RefCounted
## Changes to a [BehaviorTree] made by the graph editor, without any interface code.
##
## Every task of a tree is either in the root's subtree or in [member BehaviorTree.detached],
## and children are ordered by the vertical position of their nodes. These functions keep
## both rules true. The editor wraps each call in a [method snapshot] and a
## [method restore] pair to make it undoable.

const KEY_ENTRY := "entry_position"
const KEY_COLLAPSED := "collapsed"
const KEY_FRAMES := "frames"

const DEFAULT_SIZE := Vector2(210.0, 90.0)
const COLUMN_GAP := 70.0
const ROW_GAP := 22.0
const TREE_GAP := 70.0
const ENTRY_SIZE := Vector2(110.0, 60.0)

const _SKIPPED_PROPERTIES: PackedStringArray = [
	"script", "resource_path", "resource_scene_unique_id", "resource_local_to_scene",
]

# Variable types whose values can be stored in one another.
const _NUMBER_TYPES: Array[int] = [TYPE_INT, TYPE_FLOAT]
const _TEXT_TYPES: Array[int] = [TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH]


#region Tree structure

## A new tree with the entry placed and nothing else.
static func new_tree() -> BehaviorTree:
	var tree := BehaviorTree.new()
	tree.editor_data[KEY_ENTRY] = Vector2(-ENTRY_SIZE.x - COLUMN_GAP, 0.0)
	return tree


## The tasks drawn in the graph: the root, the detached tasks, and everything under
## them through [member BehaviorParent.children]. Tasks held inline are not included.
static func graph_tasks(tree: BehaviorTree) -> Array[BehaviorTask]:
	var out: Array[BehaviorTask] = []
	var seen := {}
	for top in graph_roots(tree):
		_walk(top, out, seen)
	return out


## The top of every connected group: the root first, then the detached tasks.
static func graph_roots(tree: BehaviorTree) -> Array[BehaviorTask]:
	var roots: Array[BehaviorTask] = []
	if tree.root:
		roots.append(tree.root)
	for task in tree.detached:
		if task and not roots.has(task):
			roots.append(task)
	return roots


## [param task] and every task below it.
static func collect_subtree(task: BehaviorTask) -> Array[BehaviorTask]:
	var out: Array[BehaviorTask] = []
	_walk(task, out, {})
	return out


## Maps every task of the graph to its parent. Tops are not in the map.
static func parent_map(tree: BehaviorTree) -> Dictionary:
	var map := {}
	for task in graph_tasks(tree):
		if task is BehaviorParent:
			for child in (task as BehaviorParent).children:
				if child:
					map[child] = task
	return map


## The parent of [param task], or null.
static func get_parent_of(tree: BehaviorTree, task: BehaviorTask) -> BehaviorParent:
	for candidate in graph_tasks(tree):
		if candidate is BehaviorParent and (candidate as BehaviorParent).children.has(task):
			return candidate
	return null


## True when [param task] is in the subtree of [param ancestor], or is it.
static func is_in_subtree(ancestor: BehaviorTask, task: BehaviorTask) -> bool:
	return collect_subtree(ancestor).has(task)


## True when [param parent] could take [param child] as a child. A decorator that
## already has a child accepts a new one and drops the old one to the detached tasks.
static func can_connect(parent: BehaviorTask, child: BehaviorTask) -> bool:
	if parent == null or child == null or parent == child:
		return false
	if not (parent is BehaviorParent) or (parent as BehaviorParent).max_children() <= 0:
		return false
	return not is_in_subtree(child, parent)


## Makes [param child] the last child of [param parent], then orders the children by
## position. A task has one parent, so it leaves its old one. Returns false when the
## link is not allowed.
static func connect_tasks(tree: BehaviorTree, parent: BehaviorTask, child: BehaviorTask) -> bool:
	if not can_connect(parent, child):
		return false
	var target := parent as BehaviorParent
	if target.children.has(child):
		sort_children(target)
		return true
	var displaced: BehaviorTask = null
	var capacity := target.max_children()
	var count := 0
	for existing in target.children:
		if existing:
			count += 1
	if count >= capacity:
		if capacity != 1:
			return false
		for existing in target.children:
			if existing:
				displaced = existing
				break
	_detach_everywhere(tree, child)
	if displaced:
		target.children.erase(displaced)
		tree.detached.append(displaced)
	target.children.append(child)
	sort_children(target)
	return true


## Cuts [param task] from its parent. A root or a child becomes a detached task.
static func disconnect_task(tree: BehaviorTree, task: BehaviorTask) -> void:
	if task == null:
		return
	if tree.root == task or get_parent_of(tree, task) != null:
		_detach_everywhere(tree, task)
		tree.detached.append(task)


## Makes [param task] the root. The old root is detached. Null clears the root.
static func set_root(tree: BehaviorTree, task: BehaviorTask) -> bool:
	if task == tree.root:
		return true
	var old := tree.root
	if task != null:
		_detach_everywhere(tree, task)
	tree.root = task
	if old:
		tree.detached.append(old)
	return true


## Adds a task at [param position]. With a [param parent] it is connected to it. The
## first task of an empty tree becomes the root.
static func add_task(tree: BehaviorTree, task: BehaviorTask, position: Vector2, parent: BehaviorTask = null) -> void:
	task.graph_position = position
	if tree.root == null and parent == null:
		tree.root = task
	else:
		tree.detached.append(task)
		if parent != null:
			connect_tasks(tree, parent, task)
	tree.ensure_ids()


## Removes tasks. Their children are detached, and links from other tasks to them are
## cleared.
static func delete_tasks(tree: BehaviorTree, tasks: Array) -> void:
	var removed := {}
	for task: BehaviorTask in tasks:
		removed[task] = true
	for task: BehaviorTask in tasks:
		if task is BehaviorParent:
			for child in (task as BehaviorParent).children.duplicate():
				if child and not removed.has(child):
					(task as BehaviorParent).children.erase(child)
					tree.detached.append(child)
	for task: BehaviorTask in tasks:
		_detach_everywhere(tree, task)
	var collapsed := get_collapsed(tree)
	for task: BehaviorTask in tasks:
		collapsed.erase(task.id)
	set_collapsed(tree, collapsed)
	for task in graph_tasks(tree):
		_clear_references(task, removed)


## Orders the children of [param parent] from top to bottom. Children at the same
## height keep their order. Returns true when the order changed.
static func sort_children(parent: BehaviorParent) -> bool:
	var items: Array = []
	var nulls := 0
	for index in parent.children.size():
		var child := parent.children[index]
		if child:
			items.append([child, index])
		else:
			nulls += 1
	items.sort_custom(func(a: Array, b: Array) -> bool:
		var ay: float = a[0].graph_position.y
		var by: float = b[0].graph_position.y
		if ay != by:
			return ay < by
		return a[1] < b[1])
	var changed := false
	for index in items.size():
		if parent.children[index] != items[index][0]:
			changed = true
			break
	if changed:
		parent.children.clear()
		for item in items:
			parent.children.append(item[0])
		for i in nulls:
			parent.children.append(null)
	return changed


## Orders the children of every parent that holds one of [param moved].
static func sort_around(tree: BehaviorTree, moved: Array) -> void:
	var map := parent_map(tree)
	for task: BehaviorTask in moved:
		if map.has(task):
			sort_children(map[task])


## Orders the children of every parent in the tree.
static func sort_all(tree: BehaviorTree) -> void:
	for task in graph_tasks(tree):
		if task is BehaviorParent:
			sort_children(task)


## The tasks of [param tasks] that are not below another one of them.
static func top_level(tree: BehaviorTree, tasks: Array) -> Array[BehaviorTask]:
	var map := parent_map(tree)
	var chosen := {}
	for task: BehaviorTask in tasks:
		chosen[task] = true
	var out: Array[BehaviorTask] = []
	for task: BehaviorTask in tasks:
		var node: BehaviorTask = map.get(task)
		var covered := false
		while node != null:
			if chosen.has(node):
				covered = true
				break
			node = map.get(node)
		if not covered:
			out.append(task)
	return out


## Copies [param tasks] with everything below them. The copies have no ids and are not
## in any tree yet. Use [method place_copies] to add them.
static func copy_tasks(tree: BehaviorTree, tasks: Array) -> Array[BehaviorTask]:
	var copies: Array[BehaviorTask] = []
	for task in top_level(tree, tasks):
		var copy := BehaviorTree.clone_tasks(task)
		for member in all_tasks(copy):
			member.id = 0
		copies.append(copy)
	return copies


## Adds copies made by [method copy_tasks] to the detached tasks. Their top-left
## corner moves to [param origin]. Each call adds new duplicates, so the same copies
## can be placed again.
static func place_copies(tree: BehaviorTree, copies: Array, origin: Vector2) -> Array[BehaviorTask]:
	var added: Array[BehaviorTask] = []
	if copies.is_empty():
		return added
	var corner := Vector2(INF, INF)
	for copy: BehaviorTask in copies:
		corner = Vector2(minf(corner.x, copy.graph_position.x), minf(corner.y, copy.graph_position.y))
	for copy: BehaviorTask in copies:
		var fresh := BehaviorTree.clone_tasks(copy)
		var shift := origin - corner
		for member in all_tasks(fresh):
			member.id = 0
		for member in collect_subtree(fresh):
			member.graph_position += shift
		tree.detached.append(fresh)
		added.append(fresh)
	tree.ensure_ids()
	return added


## Moves [param task] and everything below it into a new tree, and puts a
## [BehaviorSubtree] pointing at the new tree where the task was. Variables the moved
## tasks are bound to are copied. Returns [code]tree[/code] and [code]subtree[/code].
## The caller saves the new tree to a file.
static func extract_subtree(tree: BehaviorTree, task: BehaviorTask) -> Dictionary:
	var new_resource := new_tree()
	var subtree_task := BehaviorSubtree.new()
	subtree_task.graph_position = task.graph_position
	subtree_task.label = task.get_display_name()
	var parent := get_parent_of(tree, task)
	if parent:
		parent.children[parent.children.find(task)] = subtree_task
	elif tree.root == task:
		tree.root = subtree_task
	else:
		var index := tree.detached.find(task)
		if index < 0:
			return {}
		tree.detached[index] = subtree_task
	var origin := task.graph_position
	for member in collect_subtree(task):
		member.graph_position -= origin
	new_resource.root = task
	var names := {}
	for member in all_tasks(task):
		for property in member.bindings:
			var variable_name := member.bindings[property]
			if not variable_name.is_empty() and not variable_name.begins_with("global/"):
				names[variable_name] = true
	for variable_name: String in names:
		var source := tree.get_variable(StringName(variable_name))
		if source:
			var copy := BehaviorVariable.create(source.name, source.type, source.value)
			copy.description = source.description
			copy.persist = source.persist
			new_resource.variables.append(copy)
	subtree_task.tree = new_resource
	new_resource.ensure_ids()
	tree.ensure_ids()
	arrange(new_resource)
	return {"tree": new_resource, "subtree": subtree_task}

#endregion

#region Layout

## Lays the tree out from left to right: children stacked top to bottom to the right
## of their parent, parents centered on their children. [param sizes] maps tasks to
## their drawn size, [param collapsed] maps collapsed tasks to true. The detached
## groups go below the root's. The entry is placed left of the root.
static func arrange(tree: BehaviorTree, sizes: Dictionary = {}, collapsed: Dictionary = {}) -> void:
	var cursor := 0.0
	var entry_y := 0.0
	var first := true
	for top in graph_roots(tree):
		var heights := {}
		var height: float = _measure(top, sizes, collapsed, heights)
		var center: float = _place(top, 0.0, cursor, sizes, collapsed, heights)
		if first and top == tree.root:
			entry_y = center - ENTRY_SIZE.y * 0.5
		first = false
		cursor += height + TREE_GAP
	tree.editor_data[KEY_ENTRY] = Vector2(-ENTRY_SIZE.x - COLUMN_GAP, entry_y)


static func _size_of(task: BehaviorTask, sizes: Dictionary) -> Vector2:
	var size: Vector2 = sizes.get(task, DEFAULT_SIZE)
	return Vector2(maxf(size.x, 60.0), maxf(size.y, 30.0))


static func _visible_children(task: BehaviorTask, collapsed: Dictionary) -> Array[BehaviorTask]:
	var out: Array[BehaviorTask] = []
	if task is BehaviorParent and not collapsed.has(task):
		for child in (task as BehaviorParent).children:
			if child:
				out.append(child)
	return out


static func _measure(task: BehaviorTask, sizes: Dictionary, collapsed: Dictionary, heights: Dictionary) -> float:
	var own := _size_of(task, sizes).y
	var children := _visible_children(task, collapsed)
	var total := 0.0
	for child in children:
		total += _measure(child, sizes, collapsed, heights)
	if children.size() > 1:
		total += ROW_GAP * (children.size() - 1)
	heights[task] = maxf(own, total)
	return heights[task]


# Places the subtree inside the band starting at top. Returns the vertical center of
# the task.
static func _place(task: BehaviorTask, x: float, top: float, sizes: Dictionary, collapsed: Dictionary, heights: Dictionary) -> float:
	var size := _size_of(task, sizes)
	var children := _visible_children(task, collapsed)
	var center: float = top + float(heights[task]) * 0.5
	if not children.is_empty():
		var cursor := top
		var first_center := 0.0
		var last_center := 0.0
		var child_x := x + size.x + COLUMN_GAP
		for index in children.size():
			var child := children[index]
			var child_center: float = _place(child, child_x, cursor, sizes, collapsed, heights)
			if index == 0:
				first_center = child_center
			last_center = child_center
			cursor += heights[child] + ROW_GAP
		center = (first_center + last_center) * 0.5
	task.graph_position = Vector2(x, center - size.y * 0.5)
	return center

#endregion

#region Undo snapshots

## Everything the editor can change in a tree: structure, stored properties of every
## task and variable, and the editor data. Compare two snapshots with [code]==[/code].
static func snapshot(tree: BehaviorTree) -> Dictionary:
	var tasks := {}
	var members: Array[BehaviorTask] = graph_tasks(tree)
	for task in tree.get_tasks(true):
		if not members.has(task):
			members.append(task)
	for task in members:
		tasks[task] = _capture(task)
	var variables := {}
	for variable in tree.variables:
		if variable:
			variables[variable] = _capture(variable)
	return {
		"root": tree.root,
		"detached": tree.detached.duplicate(),
		"variable_list": tree.variables.duplicate(),
		"tasks": tasks,
		"variables": variables,
		"editor_data": tree.editor_data.duplicate(true),
	}


## Puts a tree back in the state of a [method snapshot]. The snapshot stays valid and
## can be restored again.
static func restore(tree: BehaviorTree, state: Dictionary) -> void:
	for task: Object in state["tasks"]:
		_apply(task, state["tasks"][task])
	for variable: Object in state["variables"]:
		_apply(variable, state["variables"][variable])
	tree.root = state["root"]
	tree.detached = state["detached"].duplicate()
	tree.variables = state["variable_list"].duplicate()
	tree.editor_data = state["editor_data"].duplicate(true)


## A snapshot of a list of variables, for variable sets saved on their own.
static func snapshot_variables(variables: Array) -> Dictionary:
	var props := {}
	for variable in variables:
		if variable:
			props[variable] = _capture(variable)
	return {"list": variables.duplicate(), "props": props}


## Restores a [method snapshot_variables] result and returns the list of variables.
static func restore_variables(state: Dictionary) -> Array[BehaviorVariable]:
	for variable: Object in state["props"]:
		_apply(variable, state["props"][variable])
	var out: Array[BehaviorVariable] = []
	for variable in state["list"]:
		out.append(variable)
	return out


static func _capture(object: Object) -> Dictionary:
	var props := {}
	for info in object.get_property_list():
		if not (info.usage & PROPERTY_USAGE_STORAGE) or _SKIPPED_PROPERTIES.has(info.name):
			continue
		props[info.name] = _copy_value(object.get(info.name))
	return props


static func _apply(object: Object, props: Dictionary) -> void:
	# Value goes last: the type of a variable converts it when it changes.
	for property: String in props:
		if property != "value":
			object.set(property, _copy_value(props[property]))
	if props.has("value"):
		object.set("value", _copy_value(props["value"]))


static func _copy_value(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate()
	return value

#endregion

#region Task references

## Every task held in a stored property of [param task], other than its children.
static func referenced_tasks(task: BehaviorTask) -> Array[BehaviorTask]:
	var out: Array[BehaviorTask] = []
	for info in task.get_property_list():
		if not (info.usage & PROPERTY_USAGE_STORAGE) or info.name == "children":
			continue
		var value: Variant = task.get(info.name)
		if value is BehaviorTask:
			out.append(value)
		elif value is Array:
			for item in value:
				if item is BehaviorTask:
					out.append(item)
	return out


## The tasks [param task] points at in properties that are not inline and not
## children, such as the tasks of an interruption.
static func get_linked_tasks(task: BehaviorTask) -> Array[BehaviorTask]:
	var inline := task._get_inline_tasks()
	var out: Array[BehaviorTask] = []
	for linked in referenced_tasks(task):
		if not inline.has(linked) and not out.has(linked):
			out.append(linked)
	return out


## [param task] with every task it holds or reaches, including inline tasks.
static func all_tasks(task: BehaviorTask) -> Array[BehaviorTask]:
	var out: Array[BehaviorTask] = []
	var pending: Array[BehaviorTask] = [task]
	while not pending.is_empty():
		var current: BehaviorTask = pending.pop_back()
		if current == null or out.has(current):
			continue
		out.append(current)
		if current is BehaviorParent:
			pending.append_array((current as BehaviorParent).children)
		pending.append_array(referenced_tasks(current))
	return out


## Sets a task-reference property to [param target]. Arrays get it appended once.
static func link_task(task: BehaviorTask, property: StringName, target: BehaviorTask) -> void:
	var current: Variant = task.get(property)
	if current is Array:
		var items: Array = current.duplicate()
		if not items.has(target):
			items.append(target)
			task.set(property, items)
	else:
		task.set(property, target)


static func _clear_references(task: BehaviorTask, removed: Dictionary) -> void:
	for info in task.get_property_list():
		if not (info.usage & PROPERTY_USAGE_STORAGE) or info.name == "children":
			continue
		var value: Variant = task.get(info.name)
		if value is BehaviorTask and removed.has(value):
			task.set(info.name, null)
		elif value is Array:
			var items: Array = value.duplicate()
			var changed := false
			for item in value:
				if item is BehaviorTask and removed.has(item):
					items.erase(item)
					changed = true
			if changed:
				task.set(info.name, items)

#endregion

#region Editor data

## Ids of the tasks whose subtree is folded.
static func get_collapsed(tree: BehaviorTree) -> Array:
	return (tree.editor_data.get(KEY_COLLAPSED, []) as Array).duplicate()


static func set_collapsed(tree: BehaviorTree, ids: Array) -> void:
	if ids.is_empty():
		tree.editor_data.erase(KEY_COLLAPSED)
	else:
		tree.editor_data[KEY_COLLAPSED] = ids


## The tasks hidden because an ancestor is collapsed, as a dictionary task to true.
static func hidden_tasks(tree: BehaviorTree) -> Dictionary:
	var hidden := {}
	var ids := get_collapsed(tree)
	if ids.is_empty():
		return hidden
	for task in graph_tasks(tree):
		if ids.has(task.id) and task is BehaviorParent:
			for child in (task as BehaviorParent).children:
				for member in collect_subtree(child):
					hidden[member] = true
	return hidden


## The comment frames: dictionaries with id, title, color and rect.
static func get_frames(tree: BehaviorTree) -> Array:
	return (tree.editor_data.get(KEY_FRAMES, []) as Array).duplicate(true)


static func set_frames(tree: BehaviorTree, frames: Array) -> void:
	if frames.is_empty():
		tree.editor_data.erase(KEY_FRAMES)
	else:
		tree.editor_data[KEY_FRAMES] = frames


## A frame id that no frame of the tree uses.
static func next_frame_id(tree: BehaviorTree) -> int:
	var next := 1
	for frame: Dictionary in get_frames(tree):
		next = maxi(next, int(frame.get("id", 0)) + 1)
	return next

#endregion

#region Variables

## Every type a variable can have in the editor.
const VARIABLE_TYPES: Array[int] = [
	TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I,
	TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_COLOR, TYPE_RECT2, TYPE_TRANSFORM2D,
	TYPE_TRANSFORM3D, TYPE_BASIS, TYPE_QUATERNION, TYPE_NODE_PATH, TYPE_OBJECT, TYPE_ARRAY,
	TYPE_DICTIONARY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY,
	TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY,
]


## True when a variable of [param variable_type] can be bound to a property of
## [param property_type].
static func types_compatible(variable_type: int, property_type: int) -> bool:
	if property_type == TYPE_NIL or variable_type == property_type:
		return true
	if _NUMBER_TYPES.has(variable_type) and _NUMBER_TYPES.has(property_type):
		return true
	return _TEXT_TYPES.has(variable_type) and _TEXT_TYPES.has(property_type)


## [param base] when no variable uses it, else [param base] with a number.
static func unique_variable_name(variables: Array, base: String) -> String:
	var taken := {}
	for variable in variables:
		if variable:
			taken[String(variable.name)] = true
	var candidate := base
	var number := 2
	while taken.has(candidate):
		candidate = "%s_%d" % [base, number]
		number += 1
	return candidate


## Adds a variable to the tree and returns it.
static func add_variable(tree: BehaviorTree, variable_name: String, type: int) -> BehaviorVariable:
	var variable := BehaviorVariable.create(StringName(unique_variable_name(tree.variables, variable_name)), type)
	tree.variables.append(variable)
	return variable


## How many task properties are bound to the variable.
static func count_bindings(tree: BehaviorTree, variable_name: String) -> int:
	var count := 0
	for task in tree.get_tasks(true):
		for property in task.bindings:
			if task.bindings[property] == variable_name:
				count += 1
	return count


## Points every binding of [param old_name] at [param new_name]. Returns how many
## bindings changed.
static func rename_bindings(tree: BehaviorTree, old_name: String, new_name: String) -> int:
	var count := 0
	for task in tree.get_tasks(true):
		for property in task.bindings.keys():
			if task.bindings[property] == old_name:
				task.bindings[property] = new_name
				count += 1
	return count

#endregion


static func _walk(task: BehaviorTask, out: Array[BehaviorTask], seen: Dictionary) -> void:
	if task == null or seen.has(task):
		return
	seen[task] = true
	out.append(task)
	if task is BehaviorParent:
		for child in (task as BehaviorParent).children:
			_walk(child, out, seen)


# Removes the task from its parent, the detached list and the root slot.
static func _detach_everywhere(tree: BehaviorTree, task: BehaviorTask) -> void:
	var parent := get_parent_of(tree, task)
	if parent:
		parent.children.erase(task)
	tree.detached.erase(task)
	if tree.root == task:
		tree.root = null
