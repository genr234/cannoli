extends SceneTree
## Runs every tests/**/test_*.gd file.
##
## [codeblock]
## godot --headless --script res://addons/quests/tests/run_tests.gd
## godot --headless --script res://addons/quests/tests/run_tests.gd -- file_filter [method_filter]
## [/codeblock]
## A test file extends [QuestsTest] and defines test_* methods. The optional
## arguments after "--" only run files whose path, and tests whose name, contain them.

const TESTS_DIR := "res://addons/quests/tests"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var file_filter := args[0] if args.size() > 0 else ""
	var method_filter := args[1] if args.size() > 1 else ""
	var files: Array[String] = []
	_find_tests(TESTS_DIR, files)
	files.sort()
	var passed := 0
	var failed := 0
	var checks := 0
	for path in files:
		if not file_filter.is_empty() and not path.contains(file_filter):
			continue
		var script := load(path) as GDScript
		if script == null:
			print("FAIL  %s: can't load script" % path)
			failed += 1
			continue
		var suite = script.new()
		if not suite is QuestsTest:
			print("SKIP  %s: doesn't extend QuestsTest" % path)
			continue
		suite.root = root
		var methods: Array[String] = []
		for info in suite.get_method_list():
			if String(info.name).begins_with("test_"):
				methods.append(info.name)
		methods.sort()
		for method in methods:
			var label := "%s::%s" % [path.get_file().get_basename(), method]
			if not method_filter.is_empty() and not method.contains(method_filter):
				continue
			suite.clear_failures()
			suite.current_test = label
			Quests.reset_static_state()
			await suite.before_each()
			await suite.call(method)
			await suite.after_each()
			suite.free_tracked_nodes()
			Quests.reset_static_state()
			checks += suite.get_check_count()
			if suite.get_failures().is_empty():
				passed += 1
				print("ok    %s" % label)
			else:
				failed += 1
				print("FAIL  %s" % label)
				for failure in suite.get_failures():
					print("        %s" % failure)
	print("\n%d passed, %d failed (%d checks)" % [passed, failed, checks])
	quit(1 if failed > 0 else 0)


func _find_tests(dir_path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_find_tests(dir_path.path_join(sub), result)
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			result.append(dir_path.path_join(file))
