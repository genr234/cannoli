@icon("res://addons/behaviors/icons/blackboard.svg")
class_name BehaviorBlackboard
extends RefCounted
## The live variables of an agent, a subtree, or the global scope.
##
## Each agent has one blackboard filled from its tree's [BehaviorVariable]s. Writing a
## name nobody declared creates it on the spot (a dynamic variable). Names starting
## with [code]global/[/code] go to [method Behaviors.get_globals].
## [br][br]
## Subtrees get a child blackboard: their own variables live there, and everything
## else falls through to the parent, so a subtree reads and writes the tree's
## variables of the same name.

## Emitted when a value changes, with the name it was set under.
signal value_changed(variable: StringName, value: Variant)

## The prefix for global variables.
const GLOBAL_PREFIX := "global/"

## The blackboard names fall through to.
var parent: BehaviorBlackboard

var _values: Dictionary[StringName, Variant] = {}
var _declarations: Dictionary[StringName, BehaviorVariable] = {}
var _mapping_root: WeakRef


## Creates a blackboard with the given variables. [param mapping_root] is the node
## mapped variables are relative to.
func _init(variables: Array[BehaviorVariable] = [], mapping_root: Node = null, parent_board: BehaviorBlackboard = null) -> void:
	parent = parent_board
	set_mapping_root(mapping_root)
	for variable in variables:
		declare(variable)


## Sets the node mapped variables are relative to.
func set_mapping_root(node: Node) -> void:
	_mapping_root = weakref(node) if node else null


## Adds a variable with its starting value. Replaces a variable of the same name.
func declare(variable: BehaviorVariable, initial_value: Variant = null, use_initial_value: bool = false) -> void:
	if variable == null or String(variable.name).is_empty():
		return
	_declarations[variable.name] = variable
	if not variable.is_mapped():
		_values[variable.name] = initial_value if use_initial_value else variable.get_default_value()


## Holds a value here, hiding a parent variable of the same name. Subtrees use it for
## their overrides.
func set_local(variable: StringName, value: Variant) -> void:
	_values[variable] = value
	value_changed.emit(variable, value)


## True when the name resolves here, in a parent, or in the globals.
func has_value(variable: StringName, local_only: bool = false) -> bool:
	if _is_global(variable):
		return Behaviors.get_globals().has_value(_strip_global(variable))
	if _values.has(variable) or _declarations.has(variable):
		return true
	return not local_only and parent != null and parent.has_value(variable)


## Reads a value, or [param default] when nothing has that name.
func get_value(variable: StringName, default: Variant = null) -> Variant:
	if _is_global(variable):
		return Behaviors.get_globals().get_value(_strip_global(variable), default)
	var declaration: BehaviorVariable = _declarations.get(variable)
	if declaration and declaration.is_mapped():
		var node := _get_mapped_node(declaration)
		return node.get_indexed(NodePath(String(declaration.mapped_property))) if node else default
	if _values.has(variable):
		return _values[variable]
	if parent:
		return parent.get_value(variable, default)
	return default


## Writes a value where the name lives. Unknown names become dynamic variables on the
## top blackboard.
func set_value(variable: StringName, value: Variant) -> void:
	if _is_global(variable):
		Behaviors.get_globals().set_value(_strip_global(variable), value)
		return
	var declaration: BehaviorVariable = _declarations.get(variable)
	if declaration:
		if declaration.is_mapped():
			var node := _get_mapped_node(declaration)
			if node:
				node.set_indexed(NodePath(String(declaration.mapped_property)), value)
				value_changed.emit(variable, value)
			return
		if declaration.type != TYPE_NIL and typeof(value) != declaration.type:
			value = BehaviorVariable._convert(value, declaration.type)
	elif not _values.has(variable) and parent:
		parent.set_value(variable, value)
		return
	var before: Variant = _values.get(variable)
	_values[variable] = value
	if typeof(before) != typeof(value) or before != value:
		value_changed.emit(variable, value)


## Removes a dynamic variable. Declared variables go back to their starting value.
func erase_value(variable: StringName) -> void:
	var declaration: BehaviorVariable = _declarations.get(variable)
	if declaration:
		if not declaration.is_mapped():
			set_value(variable, declaration.get_default_value())
	elif _values.erase(variable):
		value_changed.emit(variable, null)
	elif parent:
		parent.erase_value(variable)


## Every name held here (not in parents).
func get_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for variable in _declarations:
		names.append(variable)
	for variable in _values:
		if not _declarations.has(variable):
			names.append(variable)
	return names


## The declaration of a variable, or null for dynamic and unknown names.
func get_declaration(variable: StringName) -> BehaviorVariable:
	if _declarations.has(variable):
		return _declarations[variable]
	return parent.get_declaration(variable) if parent else null


## Puts every declared variable back to its starting value and drops dynamic ones.
func reset() -> void:
	for variable in _values.keys():
		if not _declarations.has(variable):
			_values.erase(variable)
	for variable in _declarations:
		if not _declarations[variable].is_mapped():
			set_value(variable, _declarations[variable].get_default_value())


## The values held here as a dictionary. With [param persistent_only], skips variables
## whose [member BehaviorVariable.persist] is off, and mapped variables.
func to_dictionary(persistent_only: bool = false) -> Dictionary:
	var data := {}
	for variable in _values:
		var declaration: BehaviorVariable = _declarations.get(variable)
		if persistent_only and declaration and not declaration.persist:
			continue
		data[String(variable)] = _values[variable]
	return data


## Sets values from a dictionary made by [method to_dictionary].
func from_dictionary(data: Dictionary) -> void:
	for key in data:
		set_value(StringName(key), data[key])


func _get_mapped_node(declaration: BehaviorVariable) -> Node:
	var root: Node = _mapping_root.get_ref() if _mapping_root else null
	if root == null:
		return parent._get_mapped_node(declaration) if parent else null
	return root.get_node_or_null(declaration.mapped_node)


static func _is_global(variable: StringName) -> bool:
	return String(variable).begins_with(GLOBAL_PREFIX)


static func _strip_global(variable: StringName) -> StringName:
	return StringName(String(variable).substr(GLOBAL_PREFIX.length()))
