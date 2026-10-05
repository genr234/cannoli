class_name QuestsTest
extends RefCounted
## Base class for the quests tests. Each test file extends this class and
## defines [code]func test_*() -> void[/code] methods. A test method may use
## [code]await frames(n)[/code].

## The node tests add their nodes to. Set by the runner.
var root: Node
## Set by the runner while a test is running.
var current_test := ""

var _failures: Array[String] = []
var _checks := 0
var _tracked: Array[Node] = []
var _tracked_quests: Array[Quest] = []


## Called before each test method. May be a coroutine.
func before_each() -> void:
	pass


## Called after each test method. May be a coroutine.
func after_each() -> void:
	pass


func get_failures() -> Array[String]:
	return _failures


func get_check_count() -> int:
	return _checks


func clear_failures() -> void:
	_failures.clear()
	_checks = 0


## Waits for [param count] process frames.
func frames(count := 1) -> void:
	for i in count:
		await root.get_tree().process_frame


## Adds a new [QuestManager] to the root. It is freed after the test.
func make_manager() -> QuestManager:
	var manager := QuestManager.new()
	manager.use_save_addon = false
	manager.name = "QuestManager"
	return add_node(manager) as QuestManager


## Adds [param node] to the root and frees it after the test. Returns the node.
func add_node(node: Node, parent: Node = null) -> Node:
	(parent if parent != null else root).add_child(node)
	if parent == null:
		_tracked.append(node)
	return node


## Clones [param asset] into a quest instance that is disposed of after the test.
func make_quest_instance(asset: Quest) -> Quest:
	return track_quest(asset.clone())


## Makes sure [param quest] is disposed of after the test. Returns the quest.
func track_quest(quest: Quest) -> Quest:
	if quest != null:
		_tracked_quests.append(quest)
	return quest


## Frees the nodes added with [method add_node] and [method make_manager], and
## disposes of the quests made with [method make_quest_instance].
func free_tracked_nodes() -> void:
	for quest in _tracked_quests:
		quest.dispose(true)
	_tracked_quests.clear()
	for i in range(_tracked.size() - 1, -1, -1):
		var node := _tracked[i]
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	_tracked.clear()


func assert_true(condition: bool, message := "") -> void:
	_checks += 1
	if not condition:
		_fail("Expected true. %s" % message)


func assert_false(condition: bool, message := "") -> void:
	_checks += 1
	if condition:
		_fail("Expected false. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	_checks += 1
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		_fail("Expected %s (%s) but got %s (%s). %s" % [str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual)), message])
	elif actual != expected:
		_fail("Expected %s but got %s. %s" % [str(expected), str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message := "") -> void:
	_checks += 1
	if actual == unexpected:
		_fail("Expected anything but %s. %s" % [str(unexpected), message])


func assert_null(value: Variant, message := "") -> void:
	_checks += 1
	if value != null:
		_fail("Expected null but got %s. %s" % [str(value), message])


func assert_not_null(value: Variant, message := "") -> void:
	_checks += 1
	if value == null:
		_fail("Expected a value but got null. %s" % message)


func assert_almost_eq(actual: float, expected: float, message := "") -> void:
	_checks += 1
	if not is_equal_approx(actual, expected):
		_fail("Expected %s but got %s. %s" % [expected, actual, message])


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _fail(message: String) -> void:
	var text := "%s: %s" % [current_test, message]
	_failures.append(text)
	push_error("Quests test failed: " + text)
