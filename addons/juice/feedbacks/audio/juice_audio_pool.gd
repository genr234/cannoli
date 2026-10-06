@tool
class_name JuiceAudioPool
extends Node
## Owns the audio players that [JuiceSound] plays through.
##
## It is created on demand under the tree root, so nothing needs to be set up. Players
## are reused after a sound ends and spare ones are freed. You normally never touch it.

## Which kind of player a sound needs.
enum Kind { GLOBAL, TWO_D, THREE_D }

# Idle players kept around for reuse, per pool.
const _MAX_IDLE := 12

static var _instance: JuiceAudioPool

var _voices: Array[Voice] = []
var _pending: Array[Array] = []


## Everything a sound needs to start. Fill what you use and leave the rest.
class Request:
	extends RefCounted
	var kind: Kind = Kind.GLOBAL
	var position := Vector3.ZERO
	var bus: StringName = &"Master"
	var volume_db := 0.0
	var pitch := 1.0
	var start_offset := 0.0
	var max_distance := 0.0
	var unit_size := 10.0
	var panning_strength := 1.0
	var follow_time_scale := false
	var follow: Node
	var max_voices := 0
	var steal_oldest := true


## One pooled player and what it is currently doing.
class Voice:
	extends RefCounted
	var player: Node
	var kind: Kind = Kind.GLOBAL
	var source_id := 0
	var busy := false
	var started_msec := 0
	var base_pitch := 1.0
	var follow_time_scale := false
	var follow: Node


## Returns the shared pool, creating it under the tree root when needed.
static func get_pool(tree: SceneTree) -> JuiceAudioPool:
	if is_instance_valid(_instance):
		return _instance
	var existing := tree.root.get_node_or_null(^"JuiceAudioPool")
	if existing is JuiceAudioPool:
		_instance = existing
		return _instance
	_instance = JuiceAudioPool.new()
	_instance.name = &"JuiceAudioPool"
	# The root is busy while the first scene is being set up, so adding is deferred then.
	if tree.get_frame() > 0:
		tree.root.add_child(_instance)
	else:
		tree.root.add_child.call_deferred(_instance)
	return _instance


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for entry in _pending:
		play(entry[0], entry[1], entry[2])
	_pending.clear()


func _process(_delta: float) -> void:
	var scale := maxf(Engine.time_scale, 0.01)
	for voice in _voices:
		if not voice.busy:
			continue
		if voice.follow_time_scale:
			voice.player.pitch_scale = maxf(voice.base_pitch * scale, 0.01)
		if voice.follow != null:
			if is_instance_valid(voice.follow):
				_place(voice.player, voice.kind, Juice.node_position(voice.follow))
			else:
				voice.follow = null


## Plays [param stream] for [param source] and returns the player, or null when refused.
func play(source: Object, stream: AudioStream, request: Request) -> Node:
	if not is_inside_tree():
		_pending.append([source, stream, request])
		return null
	var source_id := source.get_instance_id() if source != null else 0
	if request.max_voices > 0:
		var oldest: Voice
		var count := 0
		for voice in _voices:
			if voice.busy and voice.source_id == source_id:
				count += 1
				if oldest == null or voice.started_msec < oldest.started_msec:
					oldest = voice
		if count >= request.max_voices:
			if not request.steal_oldest:
				return null
			_stop_voice(oldest)
	var voice := _acquire(request.kind)
	var node := voice.player
	node.set("stream", stream)
	node.set("bus", request.bus)
	node.set("volume_db", request.volume_db)
	node.set("pitch_scale", maxf(request.pitch, 0.01))
	match request.kind:
		Kind.TWO_D:
			if request.max_distance > 0.0:
				node.set("max_distance", request.max_distance)
		Kind.THREE_D:
			node.set("max_distance", request.max_distance)
			node.set("unit_size", request.unit_size)
			node.set("panning_strength", request.panning_strength)
	voice.source_id = source_id
	voice.busy = true
	voice.started_msec = Time.get_ticks_msec()
	voice.base_pitch = request.pitch
	voice.follow_time_scale = request.follow_time_scale
	voice.follow = request.follow
	if request.follow_time_scale:
		node.set("pitch_scale", maxf(request.pitch * maxf(Engine.time_scale, 0.01), 0.01))
	_place(node, request.kind, request.position)
	node.call("play", request.start_offset)
	return node


## Stops every sound that was started for [param source].
func stop_source(source: Object) -> void:
	var source_id := source.get_instance_id()
	for voice in _voices.duplicate():
		if voice.busy and voice.source_id == source_id:
			_stop_voice(voice)


## Stops all sounds in the pool.
func stop_all() -> void:
	for voice in _voices.duplicate():
		if voice.busy:
			_stop_voice(voice)


## Returns how many sounds started for [param source] are still playing.
func count_playing(source: Object) -> int:
	var source_id := source.get_instance_id()
	var count := 0
	for voice in _voices:
		if voice.busy and voice.source_id == source_id:
			count += 1
	return count


func _acquire(kind: Kind) -> Voice:
	for voice in _voices:
		if not voice.busy and voice.kind == kind:
			return voice
	var voice := Voice.new()
	voice.kind = kind
	match kind:
		Kind.TWO_D:
			voice.player = AudioStreamPlayer2D.new()
		Kind.THREE_D:
			voice.player = AudioStreamPlayer3D.new()
		_:
			voice.player = AudioStreamPlayer.new()
	voice.player.finished.connect(_on_finished.bind(voice))
	add_child(voice.player)
	_voices.append(voice)
	return voice


func _place(player: Node, kind: Kind, position: Vector3) -> void:
	if kind == Kind.TWO_D:
		(player as Node2D).global_position = Vector2(position.x, position.y)
	elif kind == Kind.THREE_D:
		(player as Node3D).global_position = position


func _stop_voice(voice: Voice) -> void:
	if voice == null:
		return
	voice.player.call("stop")
	_release(voice)


func _on_finished(voice: Voice) -> void:
	_release(voice)


func _release(voice: Voice) -> void:
	voice.busy = false
	voice.follow = null
	var idle := 0
	for other in _voices:
		if not other.busy:
			idle += 1
	if idle > _MAX_IDLE:
		_voices.erase(voice)
		voice.player.queue_free()
