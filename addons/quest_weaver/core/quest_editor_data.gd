# res://addons/quest_weaver/core/quest_editor_data.gd
@tool
class_name QuestEditorData
extends Resource

## Quest Bookmarks in Side_Panel

@export var open_files: Array[String] = []
@export var last_focused_file: String = ""
