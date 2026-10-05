extends QuestsTest
## NPC questers and multiple journals: each quester gets its own quest instance.


func _race_quest() -> Quest:
	var quest := QuestTestHelpers.simple_quest("race")
	var cond := QuestMessageCondition.new()
	cond.message = "Crossed"
	cond.parameter = "Line"
	cond.sender_specifier = QuestMessages.Participant.QUESTER
	quest.get_node("task").condition_set.condition_list.clear()
	quest.get_node("task").condition_set.condition_list.append(cond)
	return quest


func test_two_questers_have_independent_instances() -> void:
	make_manager()
	var player := QuestTestHelpers.make_journal(self, "player")
	var npc := QuestTestHelpers.make_journal(self, "npc")
	var asset := _race_quest()
	var a := player.add_quest(asset)
	var b := npc.add_quest(asset)
	a.assign_quester(QuestParticipant.new("player", "Hero"))
	b.assign_quester(QuestParticipant.new("npc", "Bob"))
	a.set_state(Quest.State.ACTIVE)
	b.set_state(Quest.State.ACTIVE)
	await frames(2)
	assert_ne(Quests.get_quest_instance("race", "player"), Quests.get_quest_instance("race", "npc"))
	assert_eq(Quests.get_quest_instance("race", "npc"), b)
	Quests.set_quest_state("race", Quest.State.FAILED, "npc")
	assert_eq(a.get_state(), Quest.State.ACTIVE, "other quester unaffected")
	assert_eq(b.get_state(), Quest.State.FAILED)
	# Only the player's message advances the player's quest.
	Quests.send_message("Crossed", "Line", null, "player")
	assert_eq(a.get_node("task").get_state(), QuestNode.State.TRUE)
	assert_eq(a.get_state(), Quest.State.SUCCESSFUL)


func test_quester_tags_use_each_questers_name() -> void:
	make_manager()
	var asset := QuestTestHelpers.simple_quest("greet")
	var a := asset.clone()
	a.assign_quester(QuestParticipant.new("p1", "Hero"))
	var b := asset.clone()
	b.assign_quester(QuestParticipant.new("p2", "Bob"))
	assert_eq(QuestTags.replace_tags("Hi {QUESTER} {QUESTERID}", a), "Hi Hero p1")
	assert_eq(QuestTags.replace_tags("Hi {QUESTER} {QUESTERID}", b), "Hi Bob p2")
