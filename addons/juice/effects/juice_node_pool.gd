class_name JuiceNodePool
extends Object
## A small pool of scene instances, so effects that spawn the same particles again and
## again do not allocate a new tree each time.
##
## Instances are handed out with [method acquire] and go back with [method release],
## which hides them and takes them out of the tree. Pools are per scene.

static var _pools: Dictionary[String, Array] = {}
static var _exit_hooked := false


## Returns an instance of [param scene] that is not in the tree. Reuses a released
## one when possible.
static func acquire(scene: PackedScene) -> Node:
	if scene == null:
		return null
	var pool: Array = _pools.get(scene.resource_path if not scene.resource_path.is_empty() else str(scene.get_instance_id()), [])
	while not pool.is_empty():
		var node: Node = pool.pop_back()
		if is_instance_valid(node):
			return node
	return scene.instantiate()


## Takes [param node] out of the tree and keeps it for [method acquire]. Frees it
## when the pool of that scene already holds [param max_size] nodes.
static func release(scene: PackedScene, node: Node, max_size: int = 16) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_hook_exit()
	var key := scene.resource_path if not scene.resource_path.is_empty() else str(scene.get_instance_id())
	var pool: Array = _pools.get(key, [])
	if pool.size() >= max_size:
		node.queue_free()
		return
	pool.append(node)
	_pools[key] = pool


## Frees every pooled node.
static func clear() -> void:
	for pool: Array in _pools.values():
		for node: Node in pool:
			if is_instance_valid(node):
				node.free()
	_pools.clear()


# Pooled nodes live outside the tree, so free them when the game closes to avoid leak reports.
static func _hook_exit() -> void:
	if _exit_hooked:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_exit_hooked = true
	tree.root.tree_exiting.connect(clear, CONNECT_ONE_SHOT)
