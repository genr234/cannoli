extends QuestsTest

var _journal: QuestJournal


func before_each() -> void:
	QuestsRelationships.reset_cache()
	make_manager()
	_journal = PartsTestUtil.make_journal(self)


func after_each() -> void:
	QuestsRelationships.reset_cache()


func _has_addon() -> bool:
	return PartsTestUtil.find_class_script("Relationships") != null


func test_availability_matches_installation() -> void:
	assert_eq(QuestsRelationships.is_available(), _has_addon())


func test_unavailable_is_safe() -> void:
	# Simulate the addon being absent.
	QuestsRelationships._scripts["Relationships"] = null
	assert_false(QuestsRelationships.is_available())
	assert_false(QuestsRelationships.has_manager())
	assert_null(QuestsRelationships.get_manager())
	assert_almost_eq(QuestsRelationships.get_affinity("A", "B"), 0.0)
	assert_eq(QuestsRelationships.get_tier_name("A", "B"), "")
	assert_false(QuestsRelationships.check("A", "B", ">=", 0.0))
	assert_false(QuestsRelationships.is_at_least_tier("A", "B", "Friendly"))
	assert_false(QuestsRelationships.has_faction("A"))
	assert_false(QuestsRelationships.modify_affinity("A", "B", 5.0))
	assert_false(QuestsRelationships.set_affinity("A", "B", 5.0))
	assert_false(QuestsRelationships.report_deed(null, "attack", "B"))
	# Conditions and actions don't fire or crash.
	var condition := QuestRelationshipCondition.new()
	condition.judge_faction = "A"
	condition.subject_faction = "B"
	condition.check_interval = 0.0
	condition.set_runtime_references(PartsTestUtil.make_quest("q"), null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 0)
	var modify := QuestModifyAffinityAction.new()
	modify.judge_faction = "A"
	modify.subject_faction = "B"
	modify.amount = 10.0
	modify.execute()
	var deed := QuestReportDeedAction.new()
	deed.deed_tag = "attack"
	deed.execute()
	assert_true(true, "no crash")


func test_affinity_roundtrip() -> void:
	if not _has_addon():
		return
	assert_true(QuestsRelationships.is_available())
	assert_false(QuestsRelationships.has_manager(), "no faction manager yet")
	PartsTestUtil.make_faction_manager(self, ["Villagers", "Bandits"])
	assert_true(QuestsRelationships.has_manager())
	assert_true(QuestsRelationships.has_faction("Villagers"))
	assert_false(QuestsRelationships.has_faction("Nobody"))
	assert_true(QuestsRelationships.set_affinity("Villagers", "Player", 20.0))
	assert_almost_eq(QuestsRelationships.get_affinity("Villagers", "Player"), 20.0)
	assert_true(QuestsRelationships.modify_affinity("Villagers", "Player", -30.0))
	assert_almost_eq(QuestsRelationships.get_affinity("Villagers", "Player"), -10.0)
	assert_true(QuestsRelationships.check("Villagers", "Player", "<", 0.0))
	assert_false(QuestsRelationships.check("Villagers", "Player", ">=", 0.0))
	assert_eq(QuestsRelationships.get_tier_name("Villagers", "Player"), "Neutral")
	assert_true(QuestsRelationships.is_at_least_tier("Villagers", "Player", "Unfriendly"))
	assert_false(QuestsRelationships.is_at_least_tier("Villagers", "Player", "Friendly"))


func test_report_deed_with_members() -> void:
	if not _has_addon():
		return
	var manager := PartsTestUtil.make_faction_manager(self, ["Villagers"])
	var member_script := PartsTestUtil.find_class_script("FactionMember")
	var villagers: int = manager.call("get_faction_id", "Villagers")
	var actor_body := Node3D.new()
	add_node(actor_body)
	var actor: Node = member_script.new()
	actor.set("faction_id", 0)
	actor_body.add_child(actor)
	var witness_body := Node3D.new()
	add_node(witness_body)
	var witness: Node = member_script.new()
	witness.set("faction_id", villagers)
	witness_body.add_child(witness)
	await frames(2)
	assert_true(QuestsRelationships.report_deed(actor_body, "attack", "Villagers", 1.0, -60.0, 50.0))
	manager.call("flush_witness_queue")
	assert_true(QuestsRelationships.get_affinity("Villagers", "Player") < 0.0, "witnesses dislike the attacker")
	assert_false(QuestsRelationships.report_deed(actor_body, "attack", "Nowhere", 1.0, -60.0, 50.0), "unknown target faction")
	assert_false(QuestsRelationships.report_deed(Node.new(), "attack", "Villagers"), "no faction member on actor")


func test_relationship_condition_affinity() -> void:
	if not _has_addon():
		return
	PartsTestUtil.make_faction_manager(self, ["Villagers"])
	var condition := QuestRelationshipCondition.new()
	condition.judge_faction = "Villagers"
	condition.subject_faction = "Player"
	condition.comparison = QuestRelationshipCondition.Comparison.GREATER_OR_EQUAL
	condition.affinity_value = 30.0
	condition.check_interval = 0.0
	condition.set_runtime_references(PartsTestUtil.make_quest("q"), null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	assert_eq(hits.count, 0)
	QuestsRelationships.set_affinity("Villagers", "Player", 40.0)
	assert_eq(hits.count, 1, "reacts to manager's relationship_changed")
	assert_eq(condition.get_editor_name(), "Relationship: Villagers -> Player >= 30.0")


func test_relationship_condition_tier_and_poll() -> void:
	if not _has_addon():
		return
	var manager := PartsTestUtil.make_faction_manager(self, ["Villagers"])
	var condition := QuestRelationshipCondition.new()
	condition.judge_faction = "Villagers"
	condition.subject_faction = "Player"
	condition.check_mode = QuestRelationshipCondition.CheckMode.TIER_AT_LEAST
	condition.tier_name = "Friendly"
	condition.check_interval = 0.05
	condition.set_runtime_references(PartsTestUtil.make_quest("q"), null)
	var hits := PartsTestUtil.Counter.new()
	condition.start_checking(hits.hit)
	manager.call("set_personal_affinity", "Villagers", "Player", 60.0)
	await root.get_tree().create_timer(0.2).timeout
	assert_eq(hits.count, 1)
	assert_eq(condition.get_editor_name(), "Relationship: Villagers -> Player at least Friendly")


func test_relationship_actions() -> void:
	if not _has_addon():
		return
	PartsTestUtil.make_faction_manager(self, ["Villagers"])
	var modify := QuestModifyAffinityAction.new()
	modify.judge_faction = "Villagers"
	modify.subject_faction = "Player"
	modify.amount = 25.0
	modify.execute()
	assert_almost_eq(QuestsRelationships.get_affinity("Villagers", "Player"), 25.0)
	modify.operation = QuestModifyAffinityAction.Operation.SET_TO
	modify.amount = -5.0
	modify.execute()
	assert_almost_eq(QuestsRelationships.get_affinity("Villagers", "Player"), -5.0)
	assert_eq(modify.get_editor_name(), "Modify Affinity: Villagers -> Player = -5.0")
