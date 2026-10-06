@tool
@icon("res://addons/juice/icons/camera.svg")
@abstract
class_name JuiceCameraFeedback
extends JuiceFeedback
## The shared part of the camera feedbacks.
##
## By default a camera feedback broadcasts an event, and a shaker on the camera reacts to it
## (see [JuiceCameraShaker] and [JuiceZoomShaker]). That works across scenes, and several
## cameras can react at once.
##
## With [member direct] on, the feedback needs no shaker in the scene. It looks for the camera
## (the target, or else the current camera of the viewport) and animates it itself, through a
## hidden shaker it adds to that camera the first time it plays. The shaker listens to a private
## event, so no other shaker reacts. Channel and range do not apply then.

@export_group("Camera")
## Animates a camera directly instead of broadcasting to the shakers in the scene.
@export var direct: bool = false:
	set(value):
		direct = value
		notify_property_list_changed()

var _direct_shaker: JuiceShaker
var _direct_suffix: String = ""


# --- Subclass hooks --------------------------------------------------------

## The bus event this feedback sends.
func _get_event() -> StringName:
	return &""


## Creates the shaker used by [member direct]. It must listen to [method _get_event].
func _create_direct_shaker() -> JuiceShaker:
	return null


## The values the shaker needs, called when the feedback plays.
func _build_payload(_feedback_intensity: float) -> Dictionary:
	return {}


# --- JuiceFeedback ---------------------------------------------------------

func _get_category() -> StringName:
	return Juice.CATEGORY_SHAKE


func _has_channel() -> bool:
	return not direct


func _has_range() -> bool:
	return not direct


func _has_target() -> bool:
	return direct


func _on_play(feedback_intensity: float) -> void:
	_send(_build_payload(feedback_intensity))


func _on_stop() -> void:
	if direct:
		if is_instance_valid(_direct_shaker):
			_direct_shaker.stop()
	else:
		broadcast(_get_event(), {"stop": true})


func _on_restore() -> void:
	if direct:
		if is_instance_valid(_direct_shaker):
			_direct_shaker.restore()
	else:
		broadcast(_get_event(), {"restore": true})


## Sends [param extra] to the shakers, or to the direct shaker.
func _send(extra: Dictionary) -> void:
	if direct:
		if not _ensure_direct_shaker():
			return
		extra["use_range"] = false
		broadcast(StringName(String(_get_event()) + _direct_suffix), extra)
		return
	broadcast(_get_event(), extra)


# The camera is the target, or the viewport's camera when the target is something else.
func _find_camera() -> Node:
	var node := get_target()
	if node is Camera2D or node is Camera3D:
		return node
	var viewport: Viewport = null
	if player != null and player.is_inside_tree():
		viewport = player.get_viewport()
	if viewport == null:
		return null
	if viewport.get_camera_3d() != null:
		return viewport.get_camera_3d()
	return viewport.get_camera_2d()


func _ensure_direct_shaker() -> bool:
	var camera := _find_camera()
	if camera == null:
		return false
	if is_instance_valid(_direct_shaker) and _direct_shaker.get_parent() == camera:
		return true
	if is_instance_valid(_direct_shaker):
		_direct_shaker.queue_free()
	_direct_shaker = _create_direct_shaker()
	if _direct_shaker == null:
		return false
	_direct_shaker.name = "JuiceDirectShaker"
	_direct_suffix = "_direct_%d" % get_instance_id()
	_direct_shaker.event_suffix = _direct_suffix
	_direct_shaker.listen_to_all_channels = true
	camera.add_child(_direct_shaker, false, Node.INTERNAL_MODE_FRONT)
	return true
