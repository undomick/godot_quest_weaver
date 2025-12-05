# res://addons/quest_weaver/editor/node_type_registry.gd
@tool
class_name NodeTypeRegistry
extends Resource

# We keep this variable for compatibility, but we fill it dynamically.
var node_types: Array[NodeTypeInfo] = []

var _info_by_name: Dictionary = {}
var _info_by_script: Dictionary = {}
var _is_initialized := false

func _build_lookup_tables() -> void:
	if _is_initialized: return

	# CLEAR AND REBUILD
	node_types.clear()
	_info_by_name.clear()
	_info_by_script.clear()
	
	# Call the scanner!
	var scanned_types = QWNodeScanner.scan_project()
	node_types.append_array(scanned_types)
	
	for type_info in node_types:
		if is_instance_valid(type_info):
			if not type_info.node_name.is_empty():
				_info_by_name[type_info.node_name] = type_info
			if is_instance_valid(type_info.node_script):
				_info_by_script[type_info.node_script] = type_info
	
	_is_initialized = true

## Returns an alphabetically sorted list of all normal display names.
func get_all_node_names() -> Array[String]:
	if not _is_initialized: _build_lookup_tables()
	
	var names: Array[String] = []
	for type_info in node_types:
		if is_instance_valid(type_info):
			names.append(type_info.node_name)
	names.sort()
	return names
	
func get_info_for_name(name: String) -> NodeTypeInfo:
	if not _is_initialized: _build_lookup_tables()
	return _info_by_name.get(name)

func get_info_for_script(script: Script) -> NodeTypeInfo:
	if not _is_initialized: _build_lookup_tables()
	return _info_by_script.get(script)

func get_script_for_name(name: String) -> Script:
	var info = get_info_for_name(name)
	return info.node_script if is_instance_valid(info) else null

func get_editor_path_for_script(script: Script) -> String:
	var info = get_info_for_script(script)
	return info.editor_scene_path if is_instance_valid(info) else ""

func get_name_for_script(script: Script) -> String:
	var info = get_info_for_script(script)
	return info.node_name if is_instance_valid(info) else "Unknown Node"

func validate_registry() -> void:
	# Force rebuild to check for errors
	_is_initialized = false
	_build_lookup_tables()
