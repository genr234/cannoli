@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceSpriteFrame
extends JuiceFeedback
## Plays a short sprite animation: a run of frames, a list of textures, or a named animation.
##
## Works on [Sprite2D] and [Sprite3D] (frames and textures), [TextureRect] (textures) and
## [AnimatedSprite2D] and [AnimatedSprite3D] (frames, or play an animation by name). The
## sprite goes back to what it showed when the feedback is restored.

## What to play.
enum Method {
	## Steps from [member from_frame] to [member to_frame] of a sprite sheet.
	FRAMES,
	## Swaps through [member textures] in order.
	TEXTURES,
	## Starts a named animation on an animated sprite.
	ANIMATION,
}

@export_group("Sprite")
## What to play.
@export var method: Method = Method.FRAMES:
	set(value):
		method = value
		notify_property_list_changed()
## Seconds one play takes. For ANIMATION this is how long the animation runs before it stops
## (0 lets it play on by itself).
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The easing of the step. Null is a straight line.
@export var tween: JuiceTween
## Takes the duration from the number of frames and [member frames_per_second] instead.
@export var use_frame_rate: bool = false
## Frames shown per second when [member use_frame_rate] is on.
@export_range(1.0, 120.0, 0.1, "or_greater", "suffix:fps") var frames_per_second: float = 12.0
@export_group("Frames")
## The first frame of the run.
@export_range(0, 1000, 1, "or_greater") var from_frame: int = 0
## The last frame of the run.
@export_range(0, 1000, 1, "or_greater") var to_frame: int = 3
@export_group("Textures")
## The textures to swap through.
@export var textures: Array[Texture2D] = []
@export_group("Animation")
## The animation to start on an animated sprite.
@export var animation: StringName = &""
## Plays the animation backwards when the feedback runs reversed.
@export var play_backwards_when_reversed: bool = true
## Stops the animation when the play ends (only when duration is above 0).
@export var stop_when_finished: bool = true

var _initial_frame := 0
var _initial_texture: Texture2D
var _initial_animation: StringName = &""
var _initial_playing := false
var _captured := false
var _last_index := -1


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	var hidden := false
	match prop_name:
		"Frames", "from_frame", "to_frame":
			hidden = method != Method.FRAMES
		"Textures", "textures":
			hidden = method != Method.TEXTURES
		"Animation", "animation", "play_backwards_when_reversed", "stop_when_finished":
			hidden = method != Method.ANIMATION
		"tween":
			hidden = method == Method.ANIMATION
		"use_frame_rate", "frames_per_second":
			hidden = method == Method.ANIMATION
	if hidden:
		if property.usage & PROPERTY_USAGE_GROUP:
			property.usage = PROPERTY_USAGE_NONE
		else:
			property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	if use_frame_rate and method != Method.ANIMATION:
		var count := absi(to_frame - from_frame) + 1 if method == Method.FRAMES else textures.size()
		return float(count) / maxf(frames_per_second, 0.001)
	return duration


func _on_initialize() -> void:
	_capture()


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if node == null:
		return
	if not _captured:
		_capture()
	_last_index = -1
	match method:
		Method.ANIMATION:
			_play_animation(node)
		_:
			if _get_duration() <= 0.0:
				_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	if method != Method.ANIMATION:
		_apply(progress)


func _on_finished() -> void:
	var node := get_target()
	if method == Method.ANIMATION and stop_when_finished and _get_duration() > 0.0 and node != null and node.has_method("stop"):
		node.stop()


func _on_restore() -> void:
	var node := get_target()
	if node == null or not _captured:
		return
	if "frame" in node:
		node.set("frame", _initial_frame)
	if "texture" in node and method == Method.TEXTURES:
		node.set("texture", _initial_texture)
	if node is AnimatedSprite2D or node is AnimatedSprite3D:
		if _initial_animation != &"":
			node.set("animation", _initial_animation)
		if _initial_playing:
			node.call("play")
		else:
			node.call("stop")
		node.set("frame", _initial_frame)
	_captured = false


func _capture() -> void:
	var node := get_target()
	if node == null:
		return
	_captured = true
	if "frame" in node:
		_initial_frame = node.get("frame")
	if "texture" in node:
		_initial_texture = node.get("texture")
	if node is AnimatedSprite2D or node is AnimatedSprite3D:
		_initial_animation = node.get("animation")
		_initial_playing = node.call("is_playing")


func _apply(progress: float) -> void:
	var node := get_target()
	if node == null:
		return
	var shaped := clampf(JuiceTween.sample(tween, progress), 0.0, 1.0)
	if method == Method.FRAMES:
		if not "frame" in node:
			return
		var index := roundi(lerpf(from_frame, to_frame, shaped))
		if index == _last_index:
			return
		_last_index = index
		node.set("frame", _clamp_frame(node, index))
	elif method == Method.TEXTURES:
		if textures.is_empty() or not "texture" in node:
			return
		var index := mini(floori(shaped * textures.size()), textures.size() - 1)
		if index == _last_index:
			return
		_last_index = index
		node.set("texture", textures[index])


func _clamp_frame(node: Node, index: int) -> int:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		return clampi(index, 0, maxi(sprite.hframes * sprite.vframes - 1, 0))
	if node is Sprite3D:
		var sprite_3d := node as Sprite3D
		return clampi(index, 0, maxi(sprite_3d.hframes * sprite_3d.vframes - 1, 0))
	return maxi(index, 0)


func _play_animation(node: Node) -> void:
	if not (node is AnimatedSprite2D or node is AnimatedSprite3D) or animation == &"":
		return
	var backwards := play_backwards_when_reversed and is_reversed()
	if backwards:
		node.call("play_backwards", animation)
	else:
		node.call("play", animation)
