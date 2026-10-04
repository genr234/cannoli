class_name Relationships
extends RefCounted
## Static shortcuts to the active [FactionManager].
##
## [codeblock]
## Relationships.modify_personal_affinity("Villagers", "Player", -10)
## print(Relationships.get_affinity("Villagers", "Player"))
## [/codeblock]


## The active faction manager, or null.
static func get_manager() -> FactionManager:
	return FactionManager.instance if is_instance_valid(FactionManager.instance) else null


## The active manager's working database, or null.
static func get_database() -> FactionDatabase:
	var manager := get_manager()
	return manager.get_database() if manager != null else null


static func get_faction(faction: Variant, silent := false) -> Faction:
	var manager := get_manager()
	return manager.get_faction(faction, silent) if manager != null else null


static func get_faction_id(faction_name: String) -> int:
	var manager := get_manager()
	return manager.get_faction_id(faction_name) if manager != null else -1


static func faction_has_ancestor(faction: Variant, ancestor: Variant) -> bool:
	var manager := get_manager()
	return manager != null and manager.faction_has_ancestor(faction, ancestor)


static func faction_has_direct_parent(faction: Variant, parent: Variant) -> bool:
	var manager := get_manager()
	return manager != null and manager.faction_has_direct_parent(faction, parent)


static func add_faction_parent(faction: Variant, parent: Variant) -> void:
	var manager := get_manager()
	if manager != null:
		manager.add_faction_parent(faction, parent)


static func remove_faction_parent(faction: Variant, parent: Variant, inherit_relationships: bool) -> void:
	var manager := get_manager()
	if manager != null:
		manager.remove_faction_parent(faction, parent, inherit_relationships)


## The judge's own affinity to the subject, ignoring parents, or null.
static func find_personal_affinity(judge: Variant, subject: Variant) -> Variant:
	var manager := get_manager()
	return manager.find_personal_affinity(judge, subject) if manager != null else null


## The judge's affinity to the subject, including inherited values, or null.
static func find_affinity(judge: Variant, subject: Variant) -> Variant:
	var manager := get_manager()
	return manager.find_affinity(judge, subject) if manager != null else null


static func get_affinity(judge: Variant, subject: Variant) -> float:
	var manager := get_manager()
	return manager.get_affinity(judge, subject) if manager != null else 0.0


static func set_personal_affinity(judge: Variant, subject: Variant, affinity: float) -> void:
	var manager := get_manager()
	if manager != null:
		manager.set_personal_affinity(judge, subject, affinity)


static func modify_personal_affinity(judge: Variant, subject: Variant, change: float) -> void:
	var manager := get_manager()
	if manager != null:
		manager.modify_personal_affinity(judge, subject, change)


static func share_affinity(judge: Variant, other: Variant, subject: Variant) -> void:
	var manager := get_manager()
	if manager != null:
		manager.share_affinity(judge, other, subject)


## See [method FactionManager.commit_deed].
static func commit_deed(actor: FactionMember, deed: Deed, requires_sight := false, radius := 0.0) -> void:
	var manager := get_manager()
	if manager != null:
		manager.commit_deed(actor, deed, requires_sight, radius)


## The judge's tier toward the subject, or null.
static func get_tier(judge: Variant, subject: Variant) -> AffinityTier:
	var manager := get_manager()
	return manager.get_tier(judge, subject) if manager != null else null


## The name of the judge's tier toward the subject, or an empty string.
static func get_tier_name(judge: Variant, subject: Variant) -> String:
	var manager := get_manager()
	return manager.get_tier_name(judge, subject) if manager != null else ""


## Whether the judge is in the named tier toward the subject.
static func is_tier(judge: Variant, subject: Variant, tier_name: String) -> bool:
	return get_tier_name(judge, subject) == tier_name


## Whether the judge's affinity to the subject reaches the named tier or a higher one.
static func is_at_least_tier(judge: Variant, subject: Variant, tier_name: String) -> bool:
	var database := get_database()
	return database != null and database.is_at_least_tier(judge, subject, tier_name)


## Compares the judge's affinity to the subject with [param value]. Handy in
## dialogue conditions:
## [codeblock]
## if Relationships.check("Villagers", "Player", ">=", 50):
## [/codeblock]
## [param comparison] is one of [code]<[/code], [code]<=[/code],
## [code]==[/code], [code]!=[/code], [code]>=[/code] or [code]>[/code].
static func check(judge: Variant, subject: Variant, comparison: String, value: float) -> bool:
	var affinity := get_affinity(judge, subject)
	match comparison:
		"<":
			return affinity < value
		"<=":
			return affinity <= value
		"==":
			return is_equal_approx(affinity, value)
		"!=":
			return not is_equal_approx(affinity, value)
		">=":
			return affinity >= value
		">":
			return affinity > value
	push_error("Relationships: unknown comparison '%s'." % comparison)
	return false
