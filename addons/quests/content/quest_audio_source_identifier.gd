class_name QuestAudioSourceIdentifier
extends Resource
## Identifies where audio should play: a node with an audio player.
##
## Players are [AudioStreamPlayer], [AudioStreamPlayer2D] or [AudioStreamPlayer3D]
## nodes. If the identified node has none, an [AudioStreamPlayer] is added to it.

enum Type {
	## The current camera (2D or 3D).
	MAIN_CAMERA,
	## The [QuestManager].
	QUESTS,
	## The first node in the group named by [member id].
	NODE_WITH_GROUP,
	## The first node with the name [member id].
	NODE_WITH_NAME,
	## The character with a [QuestIdentity] whose id is [member id].
	NODE_WITH_IDENTITY,
}

const PLAYER_CLASSES: PackedStringArray = ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]

## How to identify the audio source.
@export var type := Type.MAIN_CAMERA
## Group, node name or identity id, depending on [member type].
@export var id := ""


## Plays [param stream] on the source without interrupting what it's already playing.
func play_one_shot(stream: AudioStream) -> void:
	var host := find_host()
	if host == null or stream == null:
		return
	var player := _new_player_like(host)
	player.set("stream", stream)
	player.connect("finished", player.queue_free)
	host.add_child(player)
	player.call("play")


## Interrupts the source's player and plays [param stream].
func play(stream: AudioStream) -> void:
	var player := find_audio_player()
	if player == null or stream == null:
		return
	player.set("stream", stream)
	player.call("play")


## Returns the audio player to use, adding one to the host if needed.
func find_audio_player() -> Node:
	var host := find_host()
	if host == null:
		return null
	var player := QuestSceneLookup.find_first_of(host, PLAYER_CLASSES)
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "QuestAudioPlayer"
		host.add_child(player)
	return player


## Returns the node the source identifies, or null.
func find_host() -> Node:
	var tree := QuestSceneLookup.get_tree()
	if tree == null:
		return null
	match type:
		Type.MAIN_CAMERA:
			var viewport := tree.root
			var camera_3d := viewport.get_camera_3d()
			if camera_3d != null:
				return camera_3d
			return viewport.get_camera_2d()
		Type.QUESTS:
			return Quests.get_manager()
		Type.NODE_WITH_GROUP:
			var members := tree.get_nodes_in_group(id)
			return members[0] if not members.is_empty() else null
		Type.NODE_WITH_NAME:
			return tree.root.find_child(id, true, false)
		Type.NODE_WITH_IDENTITY:
			return QuestSceneLookup.find_node(id)
	return null


func _new_player_like(host: Node) -> Node:
	var existing := QuestSceneLookup.find_first_of(host, PLAYER_CLASSES)
	if existing == null:
		return AudioStreamPlayer.new()
	var player := ClassDB.instantiate(existing.get_class()) as Node
	player.set("bus", existing.get("bus"))
	player.set("volume_db", existing.get("volume_db"))
	player.set("pitch_scale", existing.get("pitch_scale"))
	return player
