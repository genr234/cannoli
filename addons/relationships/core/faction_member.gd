@tool
@icon("../icons/faction_member.svg")
class_name FactionMember
extends Node
## Makes a character a member of a faction, with its own emotional state
## ([Pad]) and memories of deeds.
##
## Add it as a child of the character's body (a [Node2D] or [Node3D]). The
## body's position is used for witness range and line-of-sight checks.
## [br][br]
## Most of the member's behavior can be replaced by assigning your own
## [Callable] to [member can_see], [member share_rumor], [member evaluate_rumor],
## [member get_trust_in_source], [member get_trait_alignment],
## [member get_power_level], [member get_self_perceived_power_level] or
## [member compute_dominance].

## Emitted after the PAD values change.
signal pad_modified(happiness_change: float, pleasure_change: float, arousal_change: float, dominance_change: float)
## Emitted after evaluating a witnessed deed. The rumor is the member's
## subjective take on it, which may or may not be memorable.
signal deed_witnessed(rumor: Rumor)
## Emitted when a rumor is added to memory.
signal deed_remembered(rumor: Rumor)
## Emitted when a rumor leaves long-term memory.
signal deed_forgotten(rumor: Rumor)
## Emitted after this member shares its rumors with [param other].
signal rumors_shared(other: FactionMember)
## Emitted by [GossipTrigger] after gossiping with [param other].
signal gossiped(other: FactionMember)
## Emitted by [GreetingTrigger] after greeting [param other].
signal greeted(other: FactionMember)
## Emitted when an [AuraTrigger] affects this member.
signal entered_aura(aura: AuraTrigger)

## The manager to use. If empty, the active [member FactionManager.instance] is used.
@export var faction_manager: FactionManager
## Used only in the editor, to list factions for [member faction_id]. If
## empty, the scene's [FactionManager] database is used.
@export var faction_database: FactionDatabase
## The faction this member belongs to.
@export var faction_id := 0:
	set(value):
		faction_id = value
		if is_node_ready() and not Engine.is_editor_hint():
			_register()
## The member's emotional state.
@export var pad := Pad.new()
## Gives this member its own faction at runtime, a child of [member faction_id].
## It inherits the group's traits and relationships, but what it experiences
## (and what others feel about it personally) stays its own. The faction is
## found again by [member save_key], so give unique members stable save keys.
@export var unique := false
## The unique faction's display name. If empty, the body's name is used.
@export var unique_name := ""

@export_group("Evaluation")
## How easily the member's personality changes to match deeds committed by
## factions it likes. 0 means it never changes.
@export_range(0, 100) var impressionability := 0.0
## How much trait alignment affects rumor evaluation. At 100, a deed whose
## traits match the member's perfectly has double the impact.
@export_range(0, 100) var trait_alignment_importance := 50.0
## How much arousal affects rumor evaluation. At 100, maximum arousal doubles
## the impact.
@export_range(0, 100) var arousal_importance := 50.0
## Rumors whose effect is below this aren't remembered.
@export_range(0, 100) var deed_impact_threshold := 5.0
## How the impact of a repeated deed drops off with the repeat count (x axis).
@export var acclimatization_curve: Curve = _default_acclimatization_curve()
## How the difference in power levels (own minus actor's, on the x axis)
## increases the dominance felt from aggressive deeds.
@export var power_difference_curve: Curve = _default_power_difference_curve()

@export_group("Memory")
## The maximum number of memories. The oldest is dropped when it's full.
@export var max_memories := 50
## Seconds per point of impact that a rumor stays in short-term memory, which
## affects PAD.
@export var short_term_memory_duration := 300.0
## Seconds per point of impact that a rumor stays in long-term memory, which is
## what gets shared as gossip.
@export var long_term_memory_duration := 3600.0
## How often, in seconds, expired memories are removed. Higher levels of
## detail (see [method set_lod]) clean up less often. 0 disables cleanup.
@export var memory_cleanup_frequency := 2.0
## Keep memories sorted by the arousal they caused, lowest first.
@export var sort_memories := false

@export_group("Perception")
## The character's body. If empty, the parent node is used.
@export var body: Node
## Where line-of-sight rays start. If empty, [member body] is used.
@export var eyes: Node
## Physics layers that line-of-sight rays collide with.
@export_flags_3d_physics var sight_collision_mask := 1

@export_group("Gossip", "gossip_")
## How much confidence this member loses in a rumor for each time it was
## passed on, in percent. Witnessing a deed yourself is always 100%.
@export_range(0, 100) var gossip_confidence_loss := 25.0
## Rumors that were already passed on this many times aren't shared further.
## 0 means no limit.
@export_range(0, 10, 1, "or_greater") var gossip_max_hops := 3
## How much this member's feelings about a deed's actor color the rumors it
## tells, in percent. Disliked actors' good deeds sound smaller and their bad
## deeds worse, and the other way around for liked actors.
@export_range(0, 100) var gossip_exaggeration := 0.0

@export_group("")
## When sharing rumors, also share this member's affinity to the player.
@export var share_player_affinity_with_rumors := true
## Identifies the member in [method FactionManager.record_data]. If empty,
## the node path is used.
@export var save_key := ""
## Prints how each rumor is evaluated.
@export var debug_evaluation := false

## Rumors that still affect PAD.
var short_term_memory: Array[Rumor] = []
## Rumors that are remembered and shared as gossip.
var long_term_memory: Array[Rumor] = []

## [code]func(actor: FactionMember) -> bool[/code]: whether this member can see the actor.
var can_see: Callable = default_can_see
## [code]func(rumor: Rumor, other: FactionMember) -> void[/code]: shares one rumor with another member.
var share_rumor: Callable = default_share_rumor
## [code]func(rumor: Rumor, source: FactionMember) -> Rumor[/code]: evaluates a rumor and updates the member's state.
var evaluate_rumor: Callable = default_evaluate_rumor
## [code]func(source: FactionMember) -> float[/code]: trust in a rumor's source, in [-100, 100].
var get_trust_in_source: Callable = default_get_trust_in_source
## [code]func(traits: PackedFloat32Array) -> float[/code]: how well traits match the member's faction, in [0, 1].
var get_trait_alignment: Callable = default_get_trait_alignment
## [code]func() -> float[/code]: the member's power level.
var get_power_level: Callable = default_get_power_level
## [code]func() -> float[/code]: the power level the member believes it has.
var get_self_perceived_power_level: Callable = default_get_power_level
## [code]func(rumor: Rumor, affinity_to_target: float, change_in_affinity_to_actor: float, power_modifier: float) -> float[/code]
var compute_dominance: Callable = default_compute_dominance

## The group faction of a [member unique] member: its unique faction's
## parent. Otherwise the same as [member faction_id].
var base_faction_id := -1

var _unique_resolved := false
var _registered_manager: FactionManager
var _registered_faction_id := -1
var _cleanup_interval := 2.0
var _cleanup_timer := 0.0
var _no_repeat_end_time: Dictionary[String, float] = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# A scene's embedded Pad is shared by all its instances. Give each member its own.
	pad = pad.duplicate() if pad != null else Pad.new()
	_cleanup_interval = memory_cleanup_frequency
	_cleanup_timer = -randf() # Stagger cleanups across members.
	if get_manager() == null:
		push_error("Relationships: %s can't find a FactionManager." % get_path())
		set_process(false)
		return
	_register()


func _enter_tree() -> void:
	if is_node_ready() and not Engine.is_editor_hint():
		_register()


func _exit_tree() -> void:
	_unregister()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or is_zero_approx(memory_cleanup_frequency) or RelationshipsTime.is_paused():
		return
	_cleanup_timer += delta
	if _cleanup_timer >= _cleanup_interval:
		_cleanup_timer = 0.0
		clean_memory()


#region Lookup

## Finds the member for a node: the node itself, one of its descendants, or a
## direct child of one of its ancestors. Returns null if there's none.
static func find_member(node: Node) -> FactionMember:
	if node == null:
		return null
	if node is FactionMember:
		return node
	var found := _find_in_descendants(node)
	if found != null:
		return found
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is FactionMember:
			return ancestor
		for child in ancestor.get_children():
			if child is FactionMember:
				return child
		ancestor = ancestor.get_parent()
	return null


## Same as [method find_member]. Reads better when looking for the member a
## helper node (such as a trigger) belongs to.
static func find_nearest(node: Node) -> FactionMember:
	return find_member(node)


static func _find_in_descendants(node: Node) -> FactionMember:
	for child in node.get_children():
		if child is FactionMember:
			return child
	for child in node.get_children():
		var found := _find_in_descendants(child)
		if found != null:
			return found
	return null


## The manager this member uses.
func get_manager() -> FactionManager:
	if faction_manager != null:
		return faction_manager
	return FactionManager.find_for(self)


## The database this member's faction lives in. At runtime that's the
## manager's working copy.
func get_database() -> FactionDatabase:
	if Engine.is_editor_hint() and faction_database != null:
		return faction_database
	var manager := get_manager()
	if manager != null:
		return manager.get_database()
	return faction_database


## The member's faction, or null.
func get_faction() -> Faction:
	var database := get_database()
	return database.get_faction(faction_id) if database != null else null


func get_faction_name() -> String:
	var faction := get_faction()
	return faction.name if faction != null else ""


## The character's body: [member body] or the parent node.
func get_body() -> Node:
	return body if body != null else get_parent()


## Where line-of-sight rays start: [member eyes] or the body.
func get_eyes() -> Node:
	return eyes if eyes != null else get_body()


## Whether the body is a 2D node.
func is_2d() -> bool:
	return get_body() is Node2D


## The body's global position. 2D positions have z = 0.
func get_global_position_3d() -> Vector3:
	return _position_of(get_body())


static func _position_of(node: Node) -> Vector3:
	if node is Node3D:
		return node.global_position
	if node is Node2D:
		return Vector3(node.global_position.x, node.global_position.y, 0.0)
	return Vector3.ZERO


## Moves the member to another faction. Often, adding or removing a parent
## faction is a better fit than changing the member's own faction.
## For a [member unique] member, this moves its unique faction under the new group.
func switch_faction(new_faction_id: int) -> void:
	var database := get_database()
	var own := get_faction()
	if unique and _unique_resolved and own != null and own.owner_key == get_save_key() and database != null:
		own.parents = PackedInt32Array([new_faction_id])
		base_faction_id = new_faction_id
		database.invalidate_cache()
		return
	faction_id = new_faction_id


## The member's group faction ID. Differs from [member faction_id] only for
## [member unique] members.
func get_base_faction_id() -> int:
	return base_faction_id if base_faction_id >= 0 else faction_id


func _resolve_unique_faction(database: FactionDatabase) -> void:
	_unique_resolved = true
	if database == null:
		return
	var key := get_save_key()
	for faction in database.factions:
		if faction != null and faction.owner_key == key:
			base_faction_id = faction.parents[0] if not faction.parents.is_empty() else faction_id
			faction_id = faction.id
			return
	var base := database.get_faction(faction_id)
	if base == null:
		return
	var label := unique_name if not unique_name.is_empty() else str(get_body().name if get_body() != null else name)
	var faction_name := "%s: %s" % [base.name, label]
	if database.get_faction(faction_name) != null:
		faction_name += " #%d" % database.next_id
	var own := database.get_faction(database.create_faction(faction_name))
	own.owner_key = key
	own.display_name = label
	own.color = base.color
	own.traits = base.traits.duplicate()
	own.parents = PackedInt32Array([base.id])
	database.invalidate_cache()
	base_faction_id = base.id
	faction_id = own.id


## Clears PAD and memories.
func reset_all() -> void:
	pad.reset()
	for rumor in long_term_memory:
		rumor.long_term_expiration = 0.0
	short_term_memory.clear()
	_clean_long_term_memory()
	_register()


func _register() -> void:
	var manager := get_manager()
	if manager == null or not is_inside_tree():
		return
	if unique and not _unique_resolved:
		_resolve_unique_faction(manager.get_database())
	if _registered_manager == manager and _registered_faction_id == faction_id:
		return
	_unregister()
	_registered_manager = manager
	_registered_faction_id = faction_id
	manager.register_faction_member(self)


func _unregister() -> void:
	if is_instance_valid(_registered_manager):
		_registered_manager.unregister_faction_member(self, _registered_faction_id)
	_registered_manager = null
	_registered_faction_id = -1


func get_save_key() -> String:
	return save_key if not save_key.is_empty() else str(get_path())

#endregion

#region Memory

## Sets the level of detail. Memory cleanup runs (level + 1) times less often.
func set_lod(level: int) -> void:
	_cleanup_interval = (level + 1) * memory_cleanup_frequency


## Removes expired memories. Rumors leaving short-term memory undo their PAD effect.
func clean_memory() -> void:
	_clean_short_term_memory()
	_clean_long_term_memory()


func _clean_short_term_memory() -> void:
	for i in range(short_term_memory.size() - 1, -1, -1):
		var rumor := short_term_memory[i]
		if rumor.is_expired_from_short_term():
			short_term_memory.remove_at(i)
			modify_pad(0.0, -rumor.pleasure, -rumor.arousal, -rumor.dominance)


func _clean_long_term_memory() -> void:
	for i in range(long_term_memory.size() - 1, -1, -1):
		var rumor := long_term_memory[i]
		if rumor.is_expired_from_long_term():
			long_term_memory.remove_at(i)
			deed_forgotten.emit(rumor)


func _forget(rumor: Rumor) -> void:
	if rumor == null or not long_term_memory.has(rumor):
		return
	if short_term_memory.has(rumor):
		short_term_memory.erase(rumor)
		modify_pad(0.0, -rumor.pleasure, -rumor.arousal, -rumor.dominance)
	long_term_memory.erase(rumor)
	deed_forgotten.emit(rumor)


## Returns the remembered rumor about a deed, or null.
func find_rumor_by_deed_id(deed_id: String) -> Rumor:
	for rumor in long_term_memory:
		if rumor.deed_id == deed_id:
			return rumor
	return null


## Returns the remembered rumor about a deed with this actor, target and tag, or null.
func find_rumor(actor_faction_id: int, target_faction_id: int, deed_tag: String) -> Rumor:
	for rumor in long_term_memory:
		if rumor.actor_faction_id == actor_faction_id and rumor.target_faction_id == target_faction_id and rumor.tag == deed_tag:
			return rumor
	return null


## Forgets a deed by its ID.
func forget_deed_by_id(deed_id: String) -> void:
	_forget(find_rumor_by_deed_id(deed_id))


## Forgets a deed by its actor, target and tag.
func forget_deed(actor_faction_id: int, target_faction_id: int, deed_tag: String) -> void:
	_forget(find_rumor(actor_faction_id, target_faction_id, deed_tag))


func knows_about_deed_id(deed_id: String) -> bool:
	return find_rumor_by_deed_id(deed_id) != null


func knows_about_deed(actor_faction_id: int, target_faction_id: int, deed_tag: String) -> bool:
	return find_rumor(actor_faction_id, target_faction_id, deed_tag) != null


## Returns an earlier rumor with the same tag, actor and target, or null.
func find_old_rumor(new_rumor: Rumor) -> Rumor:
	return find_rumor(new_rumor.actor_faction_id, new_rumor.target_faction_id, new_rumor.tag)


## Adds a rumor to short-term and long-term memory. Public so custom
## [member evaluate_rumor] functions can use it.
func add_rumor_to_memory(rumor: Rumor) -> void:
	_add_to(short_term_memory, rumor)
	_add_to(long_term_memory, rumor)
	deed_remembered.emit(rumor)


func _add_to(memory: Array[Rumor], rumor: Rumor) -> void:
	if max_memories <= 0:
		return
	if memory.size() >= max_memories:
		memory.remove_at(0)
	if sort_memories:
		var index := memory.bsearch_custom(rumor, func(a: Rumor, b: Rumor) -> bool: return a.arousal < b.arousal)
		memory.insert(index, rumor)
	else:
		memory.append(rumor)


## Changes the PAD values and emits [signal pad_modified].
func modify_pad(happiness_change: float, pleasure_change: float, arousal_change: float, dominance_change: float) -> void:
	pad.modify(happiness_change, pleasure_change, arousal_change, dominance_change)
	pad_modified.emit(happiness_change, pleasure_change, arousal_change, dominance_change)

#endregion

#region Relationships

func _subject_id(subject: Variant) -> Variant:
	return subject.faction_id if subject is FactionMember else subject


## This member's faction's affinity to a subject (a faction ID, faction name
## or [FactionMember]), including inherited values.
func get_affinity(subject: Variant) -> float:
	var database := get_database()
	return database.get_affinity(faction_id, _subject_id(subject)) if database != null else 0.0


## Like [method get_affinity], but returns null if no affinity is defined.
func find_affinity(subject: Variant) -> Variant:
	var database := get_database()
	return database.find_affinity(faction_id, _subject_id(subject)) if database != null else null


## This member's faction's own affinity to a subject, ignoring parents, or null.
func find_personal_affinity(subject: Variant) -> Variant:
	var database := get_database()
	return database.find_personal_affinity(faction_id, _subject_id(subject)) if database != null else null


func set_personal_affinity(subject: Variant, affinity: float) -> void:
	var database := get_database()
	if database != null:
		database.set_personal_affinity(faction_id, _subject_id(subject), affinity)


func modify_personal_affinity(subject: Variant, change: float) -> void:
	var database := get_database()
	if database != null:
		database.modify_personal_affinity(faction_id, _subject_id(subject), change)

#endregion

#region Witnessing

## Witnesses a deed. [FactionManager] calls this for queued witnesses; you
## can also call it directly. If [param requires_sight] is true, the member
## must be able to see the actor.
func witness_deed(deed: Deed, actor: FactionMember, requires_sight := false) -> void:
	if deed == null or get_database() == null or _is_in_no_repeat_duration(deed):
		return
	if requires_sight and not can_see.call(actor):
		return
	if _is_debugging():
		print("Relationships: %s witnessed %s by %s to %s, impact %s" % [
				get_path(), deed.tag, describe_faction(deed.actor_faction_id), describe_faction(deed.target_faction_id), deed.impact])
	var witnessed := Rumor.from_deed(deed)
	witnessed.confidence = 100.0
	var rumor: Rumor = evaluate_rumor.call(witnessed, self)
	if rumor != null:
		deed_witnessed.emit(rumor)
	if deed.no_repeat_duration > 0.0:
		_no_repeat_end_time[deed.id] = RelationshipsTime.now() + deed.no_repeat_duration


func _is_in_no_repeat_duration(deed: Deed) -> bool:
	if deed.no_repeat_duration == 0.0 or not _no_repeat_end_time.has(deed.id):
		return false
	return RelationshipsTime.now() < _no_repeat_end_time[deed.id]


## The default [member can_see]: casts a ray from [member eyes] to the
## actor's body and checks that the first thing hit belongs to the actor.
func default_can_see(actor: FactionMember) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return false
	var hit := raycast(get_eyes(), _position_of(actor.get_body()), sight_collision_mask)
	return hit != null and find_member(hit) == actor


## Casts a ray from [param from]'s position to [param to] and returns the
## collider hit, or null. Ignores this member's own body. Uses 2D physics if
## [param from] is a [Node2D].
func raycast(from: Node, to: Vector3, collision_mask: int) -> Node:
	var own_body := get_body()
	if from is Node2D:
		var query_2d := PhysicsRayQueryParameters2D.create(from.global_position, Vector2(to.x, to.y), collision_mask)
		if own_body is CollisionObject2D:
			query_2d.exclude = [own_body.get_rid()]
		var hit_2d := (from as Node2D).get_world_2d().direct_space_state.intersect_ray(query_2d)
		return hit_2d.get("collider") as Node
	if from is Node3D:
		var query_3d := PhysicsRayQueryParameters3D.create(from.global_position, to, collision_mask)
		if own_body is CollisionObject3D:
			query_3d.exclude = [own_body.get_rid()]
		var hit_3d := (from as Node3D).get_world_3d().direct_space_state.intersect_ray(query_3d)
		return hit_3d.get("collider") as Node
	return null

#endregion

#region Rumors

## Shares this member's long-term memories with [param other]. If
## [member share_player_affinity_with_rumors] is true, also shares this
## member's affinity to the player.
func share_rumors(other: FactionMember) -> void:
	if other == null or get_database() == null:
		return
	if _is_debugging():
		print("Relationships: %s shares rumors with %s" % [get_path(), other.get_path()])
	if share_player_affinity_with_rumors:
		get_database().share_affinity(faction_id, other.faction_id, FactionDatabase.PLAYER_FACTION_ID)
	for rumor in long_term_memory.duplicate():
		if gossip_max_hops <= 0 or rumor.hops < gossip_max_hops:
			share_rumor.call(rumor, other)
	rumors_shared.emit(other)


## The default [member share_rumor]: asks [param other] to evaluate the
## rumor, colored by [member gossip_exaggeration].
func default_share_rumor(rumor: Rumor, other: FactionMember) -> void:
	if other == null or rumor == null:
		return
	other.evaluate_rumor.call(exaggerate(rumor), self)


## Returns the rumor as this member tells it: with [member gossip_exaggeration],
## a copy whose impact leans toward this member's feelings about the actor.
func exaggerate(rumor: Rumor) -> Rumor:
	if is_zero_approx(gossip_exaggeration):
		return rumor
	var told := rumor.copy()
	var dislike := -get_affinity(rumor.actor_faction_id) / 100.0
	told.impact = clampf(rumor.impact - absf(rumor.impact) * dislike * gossip_exaggeration / 100.0, -100.0, 100.0)
	return told


## The default [member get_trust_in_source]: the affinity to the source, or
## 100 if the source is this member.
func default_get_trust_in_source(source: FactionMember) -> float:
	return 100.0 if source == self else get_affinity(source.faction_id)


## The default [member get_trait_alignment]: [method Traits.alignment] with
## the member's faction traits.
func default_get_trait_alignment(traits: PackedFloat32Array) -> float:
	var faction := get_faction()
	return Traits.alignment(faction.traits, traits) if faction != null else 0.0


## The default [member get_power_level], which is always 1.
func default_get_power_level() -> float:
	return 1.0


## The default [member compute_dominance].
func default_compute_dominance(rumor: Rumor, affinity_to_target: float, change_in_affinity_to_actor: float, power_modifier: float) -> float:
	var dominance := signf(affinity_to_target) * signf(rumor.impact) * absf(rumor.aggression) * absf(change_in_affinity_to_actor) / 100.0
	return dominance + power_modifier * absf(dominance)


## The default [member evaluate_rumor]. Updates the member's affinity to the
## deed's actor and its PAD, and remembers the rumor if it's memorable.
## Returns the new rumor, the earlier rumor if the deed is a repeat, or null
## if the rumor was ignored.
func default_evaluate_rumor(rumor: Rumor, source: FactionMember) -> Rumor:
	if rumor == null or source == null or knows_about_deed_id(rumor.deed_id) or get_database() == null:
		return null
	match rumor.permitted_evaluators:
		Deed.PermittedEvaluators.EVERYONE_EXCEPT_TARGET:
			if rumor.target_faction_id == faction_id:
				return null
		Deed.PermittedEvaluators.ONLY_TARGET:
			if rumor.target_faction_id != faction_id:
				return null

	# Confidence [0, 1]: how much we trust the rumor, based on how we feel about its source.
	var trust_in_source: float = get_trust_in_source.call(source)
	var confidence := rumor.confidence * clampf(trust_in_source / 100.0, 0.0, 1.0)
	var hops := rumor.hops
	if source != self:
		hops += 1
		confidence *= 1.0 - gossip_confidence_loss / 100.0
	var confidence_norm := confidence / 100.0

	# How much we like the deed's target [-1, 1]:
	var affinity_to_target := get_affinity(rumor.target_faction_id)
	var affinity_to_target_norm := affinity_to_target / 100.0

	# The base change in how we feel about the actor [-1, 1], from the deed's
	# impact, our confidence in the source and our feelings for the target:
	var impact_norm := rumor.impact / 100.0
	var change_norm := confidence_norm * impact_norm * affinity_to_target_norm

	# Stronger if the deed's traits match our own:
	var trait_alignment: float = get_trait_alignment.call(rumor.traits)
	var trait_impact_norm := 0.0
	if not is_zero_approx(trait_alignment_importance):
		trait_impact_norm = trait_alignment * absf(change_norm) * trait_alignment_importance / 100.0

	# Stronger when we're aroused:
	var arousal_impact_norm := 0.0
	if not is_zero_approx(arousal_importance):
		arousal_impact_norm = change_norm * (pad.arousal / 100.0) * (arousal_importance / 100.0)

	var change_in_affinity_to_actor := 100.0 * clampf(change_norm + trait_impact_norm + arousal_impact_norm, -1.0, 1.0)

	# Repeats have less impact:
	var old_rumor := find_old_rumor(rumor)
	if old_rumor != null:
		old_rumor.count += 1
		change_in_affinity_to_actor *= _sample(acclimatization_curve, old_rumor.count)

	# PAD changes:
	var change_magnitude := absf(change_in_affinity_to_actor)
	var my_power_level: float = get_self_perceived_power_level.call()
	var power_modifier := clampf(_sample(power_difference_curve, my_power_level - rumor.actor_power_level), -1.0, 1.0)
	var pleasure := change_in_affinity_to_actor
	pleasure += pleasure * trait_alignment
	var arousal := change_magnitude * arousal_importance / 100.0
	var dominance: float = compute_dominance.call(rumor, affinity_to_target, change_in_affinity_to_actor, power_modifier)
	var happiness := pleasure

	# Impressionable members take on the traits of deeds by factions they like:
	var impression_factor := 0.0
	if not is_zero_approx(impressionability):
		var trust_in_actor_norm := get_affinity(rumor.actor_faction_id) / 100.0
		if trust_in_actor_norm > 0.0:
			impression_factor = impressionability / 100.0 * trust_in_actor_norm
			modify_personality(rumor.traits, impression_factor)

	# Keep the new affinity within the deed's limits:
	var old_affinity_to_actor := get_affinity(rumor.actor_faction_id)
	var new_affinity_to_actor := clampf(old_affinity_to_actor + change_in_affinity_to_actor, -100.0, 100.0)
	if old_affinity_to_actor >= rumor.min_affinity_effect and new_affinity_to_actor < rumor.min_affinity_effect:
		new_affinity_to_actor = rumor.min_affinity_effect
		change_in_affinity_to_actor = new_affinity_to_actor - old_affinity_to_actor
	elif old_affinity_to_actor <= rumor.max_affinity_effect and new_affinity_to_actor > rumor.max_affinity_effect:
		new_affinity_to_actor = rumor.max_affinity_effect
		change_in_affinity_to_actor = new_affinity_to_actor - old_affinity_to_actor

	if debug_evaluation:
		var lines := PackedStringArray([
			"Relationships: %s evaluates %s by %s to %s (impact %s, aggression %s) from %s" % [
				get_path(), rumor.tag, describe_faction(rumor.actor_faction_id), describe_faction(rumor.target_faction_id),
				rumor.impact, rumor.aggression, source.get_path()],
			"   confidence in source: %s%%" % confidence,
			"   affinity to target: %s" % affinity_to_target,
			"   change in affinity to actor from impact, target and confidence: %s" % (change_norm * 100.0),
			"   + trait alignment modifier: %s (%s%% alignment)" % [trait_impact_norm * 100.0, trait_alignment * 100.0],
			"   + arousal modifier: %s (arousal %s)" % [arousal_impact_norm * 100.0, pad.arousal],
			"   = change in affinity to actor: %s" % change_in_affinity_to_actor,
			"   power difference: %s (me) - %s (actor), dominance change scaled up by %s%%" % [
				my_power_level, rumor.actor_power_level, power_modifier * 100.0],
			"   PAD change: %s, %s, %s" % [pleasure, arousal, dominance],
		])
		if impression_factor > 0.0:
			lines.append("   personality moves toward the deed's traits by %s%%" % (impression_factor * 100.0))
		print("\n".join(lines))

	modify_pad(happiness, pleasure, arousal, dominance)
	set_personal_affinity(rumor.actor_faction_id, new_affinity_to_actor)

	var result: Rumor
	if old_rumor != null:
		old_rumor.confidence = maxf(old_rumor.confidence, confidence)
		old_rumor.hops = mini(old_rumor.hops, hops)
		result = old_rumor
	else:
		result = rumor.copy()
		result.confidence = confidence
		result.pleasure = pleasure
		result.arousal = arousal
		result.dominance = dominance
		result.hops = hops
		result.memorable = change_magnitude > deed_impact_threshold
		if result.memorable:
			add_rumor_to_memory(result)
		else:
			modify_pad(0.0, -pleasure, -arousal, -dominance)
	if _is_debugging():
		var outcome := "updates its memory of" if old_rumor != null else ("remembers" if result.memorable else "isn't affected enough to remember")
		print("Relationships: %s %s %s by %s to %s (pleasure %.2f)" % [
				get_path(), outcome, rumor.tag, describe_faction(rumor.actor_faction_id), describe_faction(rumor.target_faction_id), pleasure])
	result.short_term_expiration = RelationshipsTime.now() + change_magnitude * short_term_memory_duration
	result.long_term_expiration = RelationshipsTime.now() + change_magnitude * long_term_memory_duration
	return result


## Moves the faction's personality traits toward [param traits], scaled by
## [param multiplier]. Note that this changes the whole faction, not just this member.
func modify_personality(traits: PackedFloat32Array, multiplier: float) -> void:
	var faction := get_faction()
	if faction == null:
		return
	for i in mini(faction.traits.size(), traits.size()):
		faction.traits[i] += traits[i] * multiplier


func _sample(curve: Curve, x: float) -> float:
	return curve.sample(x) if curve != null else 1.0


func _is_debugging() -> bool:
	var manager := get_manager()
	return debug_evaluation or (manager != null and manager.debug)


func describe_faction(id: int) -> String:
	var database := get_database()
	var faction := database.get_faction(id) if database != null else null
	return faction.name if faction != null else str(id)


static func _default_acclimatization_curve() -> Curve:
	var curve := Curve.new()
	curve.max_domain = 20.0
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(20.0, 0.0))
	return curve


static func _default_power_difference_curve() -> Curve:
	var curve := Curve.new()
	curve.min_domain = -10.0
	curve.max_domain = 10.0
	curve.add_point(Vector2(-10.0, 0.0))
	curve.add_point(Vector2(1.0, 0.1))
	curve.add_point(Vector2(10.0, 1.0))
	return curve

#endregion

#region Saving

## Records the member's faction, PAD and memories in a JSON-compatible dictionary.
func record_data() -> Dictionary:
	var memories := []
	for rumor in long_term_memory:
		var short_term_left := rumor.short_term_expiration - RelationshipsTime.now() if short_term_memory.has(rumor) else 0.0
		memories.append(rumor.record_data(short_term_left, _personality_definitions()))
	var data := {
		"faction_id": faction_id,
		"pad": [pad.happiness, pad.pleasure, pad.arousal, pad.dominance],
		"memories": memories,
	}
	if unique:
		data["base_faction_id"] = get_base_faction_id()
	return data


func _personality_definitions() -> Array[TraitDefinition]:
	var database := get_database()
	return database.personality_trait_definitions if database != null else ([] as Array[TraitDefinition])


## Restores data from [method record_data], replacing the current state.
func apply_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.has("base_faction_id"):
		base_faction_id = int(data.base_faction_id)
		_unique_resolved = true
	var new_faction_id := int(data.get("faction_id", faction_id))
	if new_faction_id != faction_id:
		faction_id = new_faction_id
	var pad_values: Array = data.get("pad", [0.0, 0.0, 0.0, 0.0])
	pad.happiness = float(pad_values[0])
	pad.pleasure = float(pad_values[1])
	pad.arousal = float(pad_values[2])
	pad.dominance = float(pad_values[3])
	short_term_memory.clear()
	long_term_memory.clear()
	for entry: Dictionary in data.get("memories", []):
		var rumor := Rumor.from_data(entry, _personality_definitions())
		long_term_memory.append(rumor)
		if rumor.short_term_expiration > 0.0:
			short_term_memory.append(rumor)

#endregion
