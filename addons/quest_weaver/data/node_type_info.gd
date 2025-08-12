# res://addons/quest_weaver/data/node_type_info.gd
@tool
class_name NodeTypeInfo
extends Resource

enum Role { START, NORMAL, END }

@export var node_name: String
@export var node_script: Script
@export_file("*.tscn") var editor_scene_path: String
@export_file("*.gd") var executor_script_path: String
@export var role: Role = Role.NORMAL 
@export var default_size: QWNodeSizes.Size = QWNodeSizes.Size.MEDIUM
