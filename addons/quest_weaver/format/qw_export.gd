@tool
class_name QuestWeaverExportPlugin
extends EditorExportPlugin


func _get_name() -> String:
	return "QuestWeaverExport"

func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	if path.ends_with(".quest"):
		pass
