# res://addons/quest_weaver/core/qw_node_scanner.gd
@tool
class_name QWNodeScanner
extends RefCounted

# We only scan this main directory and everything below it recursively.
const ROOT_NODES_PATH = "res://addons/quest_weaver/nodes/"

# Scans the directories recursively and returns an Array of NodeTypeInfo objects.
static func scan_project() -> Array[NodeTypeInfo]:
	var found_types: Array[NodeTypeInfo] = []
	_scan_recursive(ROOT_NODES_PATH, found_types)
	return found_types

static func _scan_recursive(path: String, result_array: Array[NodeTypeInfo]) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		# If the folder doesn't exist yet (e.g. during refactoring), just return without error.
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Ignore navigation entries (. and ..)
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
			
		var full_path = path.path_join(file_name)
		
		if dir.current_is_dir():
			# RECURSION: If it's a directory, dive deeper!
			_scan_recursive(full_path, result_array)
		
		elif file_name.ends_with("_resource.gd"):
			# We found a resource script!
			
			# Explicitly ignore the base class if it is located here.
			if file_name == "graph_node_resource.gd":
				file_name = dir.get_next()
				continue
				
			var node_type_info = _create_info_from_script(full_path, file_name)
			if node_type_info:
				result_array.append(node_type_info)
		
		file_name = dir.get_next()

static func _create_info_from_script(script_path: String, file_name: String) -> NodeTypeInfo:
	var script = load(script_path)
	if not script: return null
	
	# Create a temporary instance to access properties like category, display name, etc.
	var temp_instance = script.new()
	if not temp_instance is GraphNodeResource:
		return null 
		
	var info = NodeTypeInfo.new()
	info.category = temp_instance.category
	info.node_script = script
	info.node_name = temp_instance.get_display_name()
	info.description = temp_instance.get_description()
	info.icon = temp_instance.get_icon()
	info.default_size = temp_instance.determine_default_size()
	info.role = _determine_role(temp_instance)
	
	# --- INTELLIGENT SEARCH IN THE SAME FOLDER ---
	# We assume that Editor and Executor are located in the same folder 
	# and follow the naming convention (sharing the same prefix).
	
	var base_dir = script_path.get_base_dir()
	
	# We remove "_resource.gd" to get the base name.
	# Example: "give_take_item_node_resource.gd" -> "give_take_item_node"
	var base_name = file_name.replace("_resource.gd", "")
	
	# 1. Look for Editor (.tscn preferred, then .gd)
	# Example expectation: "give_take_item_node_editor.tscn"
	var potential_editor_tscn = base_dir.path_join(base_name + "_editor.tscn")
	var potential_editor_gd = base_dir.path_join(base_name + "_editor.gd")
	
	if FileAccess.file_exists(potential_editor_tscn):
		info.editor_scene_path = potential_editor_tscn
	elif FileAccess.file_exists(potential_editor_gd):
		info.editor_scene_path = potential_editor_gd
	
	# 2. Look for Executor (.gd)
	# Example expectation: "give_take_item_node_executor.gd"
	var potential_executor = base_dir.path_join(base_name + "_executor.gd")
	if FileAccess.file_exists(potential_executor):
		info.executor_script_path = potential_executor
	
	return info

static func _determine_role(instance: GraphNodeResource) -> int: # Return type int = enum
	if instance is StartNodeResource: return NodeTypeInfo.Role.START
	if instance is EndNodeResource: return NodeTypeInfo.Role.END
	return NodeTypeInfo.Role.NORMAL
