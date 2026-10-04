@tool
@icon("../icons/faction_manager.svg")
class_name FactionManager
extends Node
## Runs the relationship simulation for a scene. A scene with faction members
## needs one faction manager.
##
## The manager works on a copy of [member faction_database], so changes made
## during play don't modify the resource. When a deed is committed, potential
## witnesses are queued and processed a few per physics frame.

## Emitted when a faction's own relationship trait changes at runtime. See
## [signal FactionDatabase.relationship_changed].
signal relationship_changed(judge_id: int, subject_id: int, trait_id: int, old_value: float, new_value: float)
## Emitted when an affinity change moves a judge into another tier. See
## [signal FactionDatabase.tier_changed].
signal tier_changed(judge_id: int, subject_id: int, old_tier: AffinityTier, new_tier: AffinityTier)

## The faction database. At runtime the manager uses a copy; see [method get_database].
@export var faction_database: FactionDatabase:
	set(value):
		faction_database = value
		update_configuration_warnings()
## How many queued witnesses evaluate deeds each physics frame.
@export_range(1, 1000, 1, "or_greater") var witnesses_per_frame := 60
## Whether members can witness their own deeds.
@export var can_witness_self := false
## If another faction manager already exists when this one enters the tree,
## this one frees itself. Useful for managers in scenes that get reloaded.
@export var allow_only_one_faction_manager := false
## Prints activity to the output. Ignored in release builds.
@export var debug := false
## Seconds between relationship drift updates. Drift rates are set per
## relationship trait; see [member TraitDefinition.drift_fall_per_minute].
@export var drift_interval := 1.0

## The active faction manager.
static var instance: FactionManager

## Registered members, keyed by faction ID.
var members: Dictionary[int, Array] = {}

var _database: FactionDatabase
var _witness_queue: Array[Dictionary] = []
var _queue_head := 0
# Saved member data waiting for members that haven't registered yet, by save key.
var _pending_member_data: Dictionary[String, Dictionary] = {}
# Set by the editor's Relationships debugger tab while it's visible.
static var _debugger_watching := false
var _drift_timer := 0.0
var _debugger_timer := 0.0


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	if allow_only_one_faction_manager and is_instance_valid(instance) and instance != self:
		if debug:
			print("Relationships: A FactionManager already exists. Freeing %s." % get_path())
		queue_free()
		return
	instance = self
	add_to_group(&"faction_managers")
	if EngineDebugger.is_active() and not EngineDebugger.has_capture("relationships"):
		EngineDebugger.register_message_capture("relationships", _on_debugger_message)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _database == null:
		_initialize()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if not Engine.is_editor_hint() and faction_database == null:
		push_warning("Relationships: Assign a faction database to %s." % get_path())


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Assign a faction database."]) if faction_database == null else PackedStringArray()


func _initialize() -> void:
	_database = faction_database.clone() if faction_database != null else null
	if _database != null:
		_database.sync_trait_arrays()
		_database.relationship_changed.connect(relationship_changed.emit)
		_database.tier_changed.connect(tier_changed.emit)
	members.clear()
	_witness_queue.clear()
	_queue_head = 0
	if not OS.is_debug_build():
		debug = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or instance != self:
		return
	RelationshipsTime.advance(delta, get_tree().paused)
	if _database != null and drift_interval > 0.0 and not RelationshipsTime.is_paused():
		_drift_timer += RelationshipsTime.delta()
		if _drift_timer >= drift_interval:
			_database.drift_relationships(_drift_timer, faction_database)
			_drift_timer = 0.0
	if _debugger_watching and EngineDebugger.is_active():
		_debugger_timer += delta
		if _debugger_timer >= 0.5:
			_debugger_timer = 0.0
			_send_debugger_state()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or get_tree().paused:
		return
	_process_witness_queue()


## Returns the active manager, looking in [param node]'s tree if no manager
## has registered itself yet.
static func find_for(node: Node) -> FactionManager:
	if is_instance_valid(instance):
		return instance
	if node == null or not node.is_inside_tree():
		return null
	if Engine.is_editor_hint():
		var root := node.get_tree().edited_scene_root
		if root != null:
			for manager in root.find_children("*", "FactionManager", true, false):
				return manager
		return null
	return node.get_tree().get_first_node_in_group(&"faction_managers") as FactionManager


## The database the simulation runs on: a copy of [member faction_database]
## at runtime, or the resource itself in the editor.
func get_database() -> FactionDatabase:
	if Engine.is_editor_hint() or _database == null:
		return faction_database
	return _database


## Resets the database and every registered member's PAD and memories.
func reset_all() -> void:
	var registered := get_all_members()
	_initialize()
	for member in registered:
		member.reset_all()


#region Factions

## Returns a faction by ID or name. Warns if it doesn't exist, unless [param silent].
func get_faction(faction: Variant, silent := false) -> Faction:
	var database := get_database()
	var result := database.get_faction(faction) if database != null else null
	if result == null and not silent:
		push_warning("Relationships: Can't find faction %s." % str(faction))
	return result


## Returns a faction's ID from its name, or -1.
func get_faction_id(faction_name: String) -> int:
	var database := get_database()
	var id := database.get_faction_id(faction_name) if database != null else -1
	if id == -1:
		push_warning("Relationships: Can't find faction named %s." % faction_name)
	return id


## Members call this when they're ready. You don't need to call it.
func register_faction_member(member: FactionMember) -> void:
	if member == null or get_faction(member.faction_id, true) == null:
		if member != null:
			push_error("Relationships: %s has faction ID %d, which isn't in the database." % [member.get_path(), member.faction_id])
		return
	var list: Array = members.get_or_add(member.faction_id, [])
	if not list.has(member):
		list.append(member)
	var key := member.get_save_key()
	if _pending_member_data.has(key):
		var data: Dictionary = _pending_member_data[key]
		_pending_member_data.erase(key)
		member.apply_data(data)


## Members call this when they leave the tree. You don't need to call it.
func unregister_faction_member(member: FactionMember, faction_id := -1) -> void:
	var id := member.faction_id if faction_id < 0 else faction_id
	if members.has(id):
		members[id].erase(member)


## Every registered member.
func get_all_members() -> Array[FactionMember]:
	var result: Array[FactionMember] = []
	for list: Array in members.values():
		for member: FactionMember in list:
			if is_instance_valid(member):
				result.append(member)
	return result


## Registered members of a faction (by ID or name).
func get_members(faction: Variant) -> Array[FactionMember]:
	var result: Array[FactionMember] = []
	var database := get_database()
	var id := database.to_faction_id(faction) if database != null else -1
	for member: FactionMember in members.get(id, []):
		if is_instance_valid(member):
			result.append(member)
	return result

#endregion

#region Parents and relationships

func faction_has_ancestor(faction: Variant, ancestor: Variant) -> bool:
	return get_database() != null and get_database().faction_has_ancestor(faction, ancestor)


func faction_has_direct_parent(faction: Variant, parent: Variant) -> bool:
	return get_database() != null and get_database().faction_has_direct_parent(faction, parent)


func add_faction_parent(faction: Variant, parent: Variant) -> void:
	if get_database() != null:
		get_database().add_faction_parent(faction, parent)


func remove_faction_parent(faction: Variant, parent: Variant, inherit_relationships: bool) -> void:
	if get_database() != null:
		get_database().remove_faction_parent(faction, parent, inherit_relationships)


## See [method FactionDatabase.find_personal_affinity].
func find_personal_affinity(judge: Variant, subject: Variant) -> Variant:
	return get_database().find_personal_affinity(judge, subject) if get_database() != null else null


## See [method FactionDatabase.find_affinity].
func find_affinity(judge: Variant, subject: Variant) -> Variant:
	return get_database().find_affinity(judge, subject) if get_database() != null else null


func get_affinity(judge: Variant, subject: Variant) -> float:
	return get_database().get_affinity(judge, subject) if get_database() != null else 0.0


func set_personal_affinity(judge: Variant, subject: Variant, affinity: float) -> void:
	if get_database() != null:
		get_database().set_personal_affinity(judge, subject, affinity)


func modify_personal_affinity(judge: Variant, subject: Variant, change: float) -> void:
	if get_database() != null:
		get_database().modify_personal_affinity(judge, subject, change)


## See [method FactionDatabase.share_affinity].
func share_affinity(judge: Variant, other: Variant, subject: Variant) -> void:
	if get_database() != null:
		get_database().share_affinity(judge, other, subject)

#endregion

#region Deeds

## Tells potential witnesses that [param actor] committed [param deed].
## [br][br]
## If [param requires_sight] is true, witnesses must be able to see the actor.
## If [param radius] is above zero, only members within that distance of the
## actor can witness the deed.
func commit_deed(actor: FactionMember, deed: Deed, requires_sight := false, radius := 0.0) -> void:
	if actor == null:
		push_error("Relationships: commit_deed actor is null.")
		return
	if deed == null:
		push_error("Relationships: commit_deed deed is null.")
		return
	if debug:
		var target := get_faction(deed.target_faction_id, true)
		print("Relationships: commit_deed(%s) actor:%s target:%s impact:%s" % [
				deed.tag, actor.get_path(), target.name if target != null else str(deed.target_faction_id), deed.impact])
	var origin := actor.get_global_position_3d()
	var radius_squared := radius * radius
	# Only the target's own members may evaluate these, so skip everyone else.
	var candidates := get_members(deed.target_faction_id) if deed.permitted_evaluators == Deed.PermittedEvaluators.ONLY_TARGET else get_all_members()
	for witness in candidates:
		if not (can_witness_self or witness != actor) or not witness.can_process():
			continue
		if radius > 0.0 and witness.get_global_position_3d().distance_squared_to(origin) > radius_squared:
			continue
		_witness_queue.append({"deed": deed, "witness": witness, "actor": actor, "requires_sight": requires_sight})


## Evaluates every queued witness right away instead of over the next frames.
func flush_witness_queue() -> void:
	while _queue_head < _witness_queue.size():
		_process_witness_queue()


func _process_witness_queue() -> void:
	var end := mini(_queue_head + witnesses_per_frame, _witness_queue.size())
	while _queue_head < end:
		var item: Dictionary = _witness_queue[_queue_head]
		_queue_head += 1
		var witness: FactionMember = item.witness
		if is_instance_valid(witness) and witness.is_inside_tree():
			var actor: FactionMember = item.actor if is_instance_valid(item.actor) else null
			witness.witness_deed(item.deed, actor, item.requires_sight)
	if _queue_head >= _witness_queue.size():
		_witness_queue.clear()
		_queue_head = 0

#endregion

#region Tiers

## The judge's tier toward the subject, or null.
func get_tier(judge: Variant, subject: Variant) -> AffinityTier:
	return get_database().get_tier(judge, subject) if get_database() != null else null


## The name of the judge's tier toward the subject, or an empty string.
func get_tier_name(judge: Variant, subject: Variant) -> String:
	return get_database().get_tier_name(judge, subject) if get_database() != null else ""

#endregion

#region Debugger

static func _on_debugger_message(message: String, data: Array) -> bool:
	if message == "watch":
		_debugger_watching = bool(data[0]) if not data.is_empty() else false
		return true
	return false


func _send_debugger_state() -> void:
	var database := get_database()
	if database == null:
		return
	var state := []
	for member in get_all_members():
		var memories := []
		for rumor in member.long_term_memory:
			memories.append([member.describe_faction(rumor.actor_faction_id), rumor.tag,
					member.describe_faction(rumor.target_faction_id), rumor.pleasure, rumor.count, rumor.hops])
		var affinities := []
		for faction in database.factions:
			if faction != null and faction.id != member.faction_id:
				var affinity := database.get_affinity(member.faction_id, faction.id)
				var tier := database.tier_for_affinity(affinity)
				affinities.append([faction.name, affinity, tier.name if tier != null else "",
						database.find_personal_affinity(member.faction_id, faction.id) != null])
		var pad := member.pad
		state.append({
			"path": str(member.get_path()),
			"faction": member.get_faction_name(),
			"pad": [pad.happiness, pad.pleasure, pad.arousal, pad.dominance],
			"temperament": Pad.Temperament.find_key(pad.get_temperament()),
			"memories": memories,
			"affinities": affinities,
		})
	EngineDebugger.send_message("relationships:state", [state])

#endregion

#region Saving

## Records the faction database and, if [param include_members] is true,
## every registered member, in a JSON-compatible dictionary.
func record_data(include_members := true) -> Dictionary:
	var data := {"database": get_database().record_data() if get_database() != null else {}}
	if include_members:
		var member_data := _pending_member_data.duplicate()
		for member in get_all_members():
			member_data[member.get_save_key()] = member.record_data()
		data["members"] = member_data
	return data


## Restores data from [method record_data]. Members that aren't registered yet
## get their data when they register.
func apply_data(data: Dictionary) -> void:
	if get_database() != null and data.has("database"):
		get_database().apply_data(data.database)
	if not data.has("members"):
		return
	_pending_member_data.clear()
	var by_key: Dictionary[String, FactionMember] = {}
	for member in get_all_members():
		by_key[member.get_save_key()] = member
	for key: String in data.members:
		if by_key.has(key):
			by_key[key].apply_data(data.members[key])
		else:
			_pending_member_data[key] = data.members[key]

#endregion
