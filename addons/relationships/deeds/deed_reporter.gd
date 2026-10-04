@tool
@icon("../icons/deed.svg")
class_name DeedReporter
extends Node
## Reports deeds by tag, using a [DeedTemplateLibrary].
##
## Add it to the character that commits deeds (usually the player):
## [codeblock]
## $DeedReporter.report_deed("attack", enemy_member)
## $DeedReporter.report_deed("steal", merchant_member, 0.2)  # A small theft.
## $DeedReporter.report_deed("burn_camp", "Bandits")  # A deed against a whole faction.
## [/codeblock]

@export var deed_template_library: DeedTemplateLibrary
## The member that commits the deeds. If empty, the nearest [FactionMember] is used.
@export var member: FactionMember


func _ready() -> void:
	if not Engine.is_editor_hint() and member == null:
		member = FactionMember.find_nearest(self)


## Reports that this reporter's member did the deed [param tag] to
## [param target]: a [FactionMember], or a faction ID or name.
## [param magnitude] scales the template's impact.
func report_deed(tag: String, target: Variant, magnitude := 1.0) -> void:
	report_deed_by_actor(member, tag, target, magnitude)


## Reports that [param actor] did the deed [param tag] to [param target]: a
## [FactionMember], or a faction ID or name. [param magnitude] scales the
## template's impact.
func report_deed_by_actor(actor: FactionMember, tag: String, target: Variant, magnitude := 1.0) -> void:
	if actor == null:
		push_warning("Relationships: report_deed(%s) actor is null." % tag)
		return
	if target == null:
		push_warning("Relationships: report_deed(%s) target is null." % tag)
		return
	var template := find_deed_template(tag)
	if template == null:
		return
	var manager := actor.get_manager()
	if manager == null:
		push_warning("Relationships: report_deed(%s) can't find a FactionManager." % tag)
		return
	var target_id: int
	if target is FactionMember:
		target_id = target.faction_id
	else:
		var database := manager.get_database()
		target_id = database.to_faction_id(target) if database != null else -1
		if database == null or database.get_faction(target_id) == null:
			push_warning("Relationships: report_deed(%s) can't find faction %s." % [tag, target])
			return
	var power_level: float = actor.get_power_level.call()
	var deed := Deed.from_template(template, actor.faction_id, target_id, power_level, magnitude)
	manager.commit_deed(actor, deed, template.requires_sight, template.radius)


## Returns the template for [param tag], or null with a warning.
func find_deed_template(tag: String) -> DeedTemplate:
	if deed_template_library == null:
		push_warning("Relationships: %s has no deed template library." % get_path())
		return null
	var template := deed_template_library.find_template(tag)
	if template == null:
		push_warning("Relationships: %s can't find a deed template for '%s'." % [get_path(), tag])
	return template
