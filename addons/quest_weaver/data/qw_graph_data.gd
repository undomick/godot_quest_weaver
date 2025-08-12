@tool
class_name QWGraphData
extends Node

signal graph_dirty_status_changed(path: String, is_dirty: bool)
signal active_graph_changed(new_graph_resource: QuestGraphResource)
signal graph_was_saved(path: String)

var _clean_instances: Dictionary = {}
var _dirty_instances: Dictionary = {}
var _active_graph_path: String = ""

func set_active_graph(path: String) -> void:
	if _active_graph_path == path and not path.is_empty():
		return

	_active_graph_path = path
	
	if path.is_empty():
		active_graph_changed.emit(null)
	else:
		if not _clean_instances.has(path):
			_load_graph_from_disk(path)
		active_graph_changed.emit(get_graph(path))

func get_active_graph() -> QuestGraphResource:
	return get_graph(_active_graph_path)

func get_active_graph_path() -> String:
	return _active_graph_path

func get_graph(path: String) -> QuestGraphResource:
	if path.is_empty(): return null
	if _dirty_instances.has(path): return _dirty_instances[path]
	return _clean_instances.get(path)

func update_view_state(path: String, scroll: Vector2, zoom: float) -> void:
	if _clean_instances.has(path):
		var clean_instance = _clean_instances[path]
		if is_instance_valid(clean_instance):
			clean_instance.editor_scroll_offset = scroll
			clean_instance.editor_zoom = zoom

	if _dirty_instances.has(path):
		var dirty_instance = _dirty_instances[path]
		if is_instance_valid(dirty_instance):
			dirty_instance.editor_scroll_offset = scroll
			dirty_instance.editor_zoom = zoom

func make_active_graph_editable() -> QuestGraphResource:
	if _active_graph_path.is_empty(): return null
	
	if _dirty_instances.has(_active_graph_path):
		return _dirty_instances[_active_graph_path]
		
	var clean_instance = _clean_instances.get(_active_graph_path)
	if not is_instance_valid(clean_instance): return null
		
	var shadow_copy: QuestGraphResource = clean_instance.duplicate(true)
	_dirty_instances[_active_graph_path] = shadow_copy
	
	graph_dirty_status_changed.emit(_active_graph_path, true)
	
	return shadow_copy

func save_active_graph() -> bool:
	if _active_graph_path.is_empty():
		return false
		
	if not has_unsaved_changes(_active_graph_path):
		if _clean_instances.has(_active_graph_path):
			var clean_graph = _clean_instances[_active_graph_path]
			var data_to_save = clean_graph.to_dictionary()
			var file = FileAccess.open(_active_graph_path, FileAccess.WRITE)
			if file == null:
				push_error("QWGraphData: Could not open '%s' for writing." % _active_graph_path)
				return false
			file.store_var(data_to_save, true)
			file.close()
			
			graph_was_saved.emit(_active_graph_path)
			
			graph_dirty_status_changed.emit(_active_graph_path, false)
			
			return true
		return false

	var dirty_graph = _dirty_instances[_active_graph_path]
	_validate_and_clean_graph_data(dirty_graph)
	
	var data_to_save = dirty_graph.to_dictionary()
	var file = FileAccess.open(_active_graph_path, FileAccess.WRITE)
	if file == null:
		push_error("QWGraphData: Could not open '%s' for writing." % _active_graph_path)
		return false
	
	file.store_var(data_to_save, true)
	file.close()

	_clean_instances[_active_graph_path] = dirty_graph
	_dirty_instances.erase(_active_graph_path)
	graph_dirty_status_changed.emit(_active_graph_path, false)
	
	graph_was_saved.emit(_active_graph_path)
	
	print("[QWGraphData] Graph '%s' successfully saved." % _active_graph_path)
	return true

func save_graph(path: String) -> bool:
	if path.is_empty() or not has_unsaved_changes(path):
		return false

	var dirty_graph = _dirty_instances[path]
	_validate_and_clean_graph_data(dirty_graph)
	
	var data_to_save = dirty_graph.to_dictionary()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("QWGraphData: Could not open '%s' for writing." % path)
		return false
	
	file.store_var(data_to_save, true)
	file.close()

	_clean_instances[path] = dirty_graph
	_dirty_instances.erase(path)
	graph_dirty_status_changed.emit(path, false)
	
	graph_was_saved.emit(path)
	
	print("[QWGraphData] Graph '%s' successfully saved." % path)
	return true

func discard_changes(path: String) -> void:
	if _dirty_instances.has(path):
		_dirty_instances.erase(path)
		if _active_graph_path == path:
			active_graph_changed.emit(get_graph(path))
		graph_dirty_status_changed.emit(path, false)

func close_graph(path: String) -> void:
	if _clean_instances.has(path): _clean_instances.erase(path)
	if _dirty_instances.has(path): _dirty_instances.erase(path)
	if _active_graph_path == path: set_active_graph("")

func has_unsaved_changes(path: String) -> bool:
	return _dirty_instances.has(path)

func get_all_unsaved_paths() -> Array[String]:
	var typed_paths: Array[String] = []
	if _dirty_instances != null:
		for path in _dirty_instances.keys():
			typed_paths.append(path)
	return typed_paths

func _load_graph_from_disk(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path): return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return
	var data = file.get_var(true)
	file.close()
	if not data is Dictionary: return
	var editable_instance = QuestGraphResource.new()
	editable_instance.from_dictionary(data)
	_clean_instances[path] = editable_instance

func _validate_and_clean_graph_data(graph: QuestGraphResource) -> bool:
	if not is_instance_valid(graph): return false
	var original_connections = graph.connections
	var connections_before_clean = original_connections.duplicate(true)
	var cleaned_connections: Array[Dictionary] = []
	var seen_hashes: Dictionary = {}
	var changes_made := false
	for conn in connections_before_clean:
		if not conn or not conn.has_all(["from_node", "from_port", "to_node", "to_port"]):
			changes_made = true; continue
		var from_node_id = conn.from_node
		var from_port_idx = conn.from_port
		var to_node_id = conn.to_node
		var to_port_idx = conn.to_port
		if not graph.nodes.has(from_node_id) or not graph.nodes.has(to_node_id):
			changes_made = true; continue
		var from_node_data: GraphNodeResource = graph.nodes[from_node_id]
		var to_node_data: GraphNodeResource = graph.nodes[to_node_id]
		if from_port_idx >= from_node_data.output_ports.size() or to_port_idx >= to_node_data.input_ports.size():
			changes_made = true; continue
		var conn_hash: String = "%s|%s->%s|%s" % [from_node_id, from_port_idx, to_node_id, to_port_idx]
		if not seen_hashes.has(conn_hash):
			cleaned_connections.append(conn)
			seen_hashes[conn_hash] = true
		else:
			changes_made = true
	if cleaned_connections.size() != original_connections.size() or changes_made:
		graph.connections = cleaned_connections
		if changes_made: print("QuestWeaver: Cleaned graph connections.")
		return true
	return false
