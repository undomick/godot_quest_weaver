# res://addons/quest_weaver/data/node_type_registry.gd
@tool
class_name NodeTypeRegistry
extends Resource

## A central registry that manages all available node types in the editor.

@export var node_types: Array[NodeTypeInfo] = []

var _info_by_name: Dictionary = {}
var _info_by_script: Dictionary = {}

var _is_initialized := false


func _build_lookup_tables() -> void:
	if _is_initialized: return

	_info_by_name.clear()
	_info_by_script.clear()
	
	for type_info in node_types:
		if is_instance_valid(type_info):
			if not type_info.node_name.is_empty():
				_info_by_name[type_info.node_name] = type_info
			if is_instance_valid(type_info.node_script):
				_info_by_script[type_info.node_script] = type_info
	
	_is_initialized = true

## Returns an alphabetically sorted list of all normal display names (excluding Start/End).
func get_all_node_names() -> Array[String]:
	if not _is_initialized: _build_lookup_tables()
	
	var names: Array[String] = []
	for type_info in node_types:
		if is_instance_valid(type_info):
			names.append(type_info.node_name)
	names.sort()
	return names
	
## Finds the complete NodeTypeInfo resource for a given display name.
func get_info_for_name(name: String) -> NodeTypeInfo:
	if not _is_initialized: _build_lookup_tables()
	return _info_by_name.get(name)

## Finds the complete NodeTypeInfo resource for a given script.
func get_info_for_script(script: Script) -> NodeTypeInfo:
	if not _is_initialized: _build_lookup_tables()
	return _info_by_script.get(script)

## Finds the script for a given display name.
func get_script_for_name(name: String) -> Script:
	var info: NodeTypeInfo = get_info_for_name(name)
	return info.node_script if is_instance_valid(info) else null

## Finds the editor scene path for a given script.
func get_editor_path_for_script(script: Script) -> String:
	var info: NodeTypeInfo = get_info_for_script(script)
	return info.editor_scene_path if is_instance_valid(info) else ""

## Finds the display name for a given script.
func get_name_for_script(script: Script) -> String:
	var info: NodeTypeInfo = get_info_for_script(script)
	return info.node_name if is_instance_valid(info) else "Unknown Node"

func validate_registry() -> void:
	var logger: QWLogger = null
	
	if is_instance_valid(QuestWeaverServices) and QuestWeaverServices.has_meta("logger_initialized") and QuestWeaverServices.logger != null:
		logger = QuestWeaverServices.logger

	var can_use_logger = is_instance_valid(logger)

	if node_types.is_empty():
		var msg = "NodeTypeRegistry: The 'node_types' array is empty. No nodes will be available in the editor."
		if can_use_logger: logger.warn("System", msg)
		else: push_warning("[QuestWeaver] " + msg)
		return
		
	var startup_msg = "Validating NodeTypeRegistry..."
	if can_use_logger: logger.log("System", startup_msg)
	else: print("[QuestWeaver] " + startup_msg + " (Logger not available, using print)")
	
	var is_valid = true
	
	for i in range(node_types.size()):
		var type_info: NodeTypeInfo = node_types[i]
		
		if not is_instance_valid(type_info):
			var msg = "NodeTypeRegistry: Entry at index %d is null or invalid." % i
			if can_use_logger: logger.warn("System", msg)
			else: push_warning("[QuestWeaver] " + msg)
			is_valid = false
			continue

		var node_name = type_info.node_name if not type_info.node_name.is_empty() else "Unnamed Node (index %d)" % i

		if not is_instance_valid(type_info.node_script) or not ResourceLoader.exists(type_info.node_script.resource_path):
			var msg = "NodeTypeRegistry: [ERROR] Script for node '%s' is missing or invalid." % node_name
			if can_use_logger: logger.warn("System", msg)
			else: push_warning("[QuestWeaver] " + msg)
			is_valid = false

		if not type_info.editor_scene_path.is_empty() and not ResourceLoader.exists(type_info.editor_scene_path):
			var msg = "NodeTypeRegistry: Editor scene for node '%s' not found at path: %s" % [node_name, type_info.editor_scene_path]
			if can_use_logger: logger.warn("System", msg)
			else: push_warning("[QuestWeaver] " + msg)
			is_valid = false

		if not type_info.executor_script_path.is_empty() and not ResourceLoader.exists(type_info.executor_script_path):
			var msg = "NodeTypeRegistry: Executor script for node '%s' not found at path: %s" % [node_name, type_info.executor_script_path]
			if can_use_logger: logger.warn("System", msg)
			else: push_warning("[QuestWeaver] " + msg)
			is_valid = false
	
	if is_valid:
		var success_msg = "NodeTypeRegistry validation successful. All paths are valid."
		if can_use_logger:
			logger.log("System", success_msg)
		else:
			print("[QuestWeaver] " + success_msg)
