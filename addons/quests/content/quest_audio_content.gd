class_name QuestAudioContent
extends QuestContent
## Plays an audio stream when shown.

## Audio stream to play.
@export var audio: AudioStream
## Where to play it.
@export var use_audio_source_on: QuestAudioSourceIdentifier = QuestAudioSourceIdentifier.new()
## Optional text shown with the audio.
@export var text := ""


func get_original_text() -> String:
	return text


func get_editor_name() -> String:
	if audio == null:
		return "Audio Clip"
	return "Audio Clip: " + audio.resource_path.get_file().get_basename()


## Plays the audio on its audio source.
func play() -> void:
	if audio != null and use_audio_source_on != null:
		use_audio_source_on.play_one_shot(audio)


func get_audio() -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	if audio != null:
		streams.append(audio)
	return streams
