@tool
extends EditorTranslationParserPlugin
## Adds quest, database and generator resources (.tres) to the project's POT
## generation. The strings come from QuestTextExtractor.


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["tres", "res"])


func _parse_file(path: String) -> Array[PackedStringArray]:
	return QuestTextExtractor.parse_file(path)
