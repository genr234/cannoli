class_name QuestAudioAction
extends QuestAction
## Plays an audio stream.

## Audio stream to play.
@export var audio: AudioStream
## Where to play it.
@export var use_audio_source_on: QuestAudioSourceIdentifier = QuestAudioSourceIdentifier.new()
## If something is currently playing on the audio source, interrupt it. Otherwise play in addition.
@export var interrupt_previous_clip := false


func get_editor_name() -> String:
	if audio == null:
		return "Audio"
	return "Audio: " + audio.resource_path.get_file().get_basename()


func execute() -> void:
	if audio == null or use_audio_source_on == null:
		return
	if interrupt_previous_clip:
		use_audio_source_on.play(audio)
	else:
		use_audio_source_on.play_one_shot(audio)


func get_audio() -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	if audio != null:
		streams.append(audio)
	return streams
