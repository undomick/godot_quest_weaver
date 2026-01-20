# res://addons/quest_weaver/editor/qw_action_handler.gd
@tool
class_name QWActionHandler
extends Node

signal node_data_changed(node_id: String, action: String)

# --- Command Preloads ---
const ChangePropertyCommand = preload("commands/change_property_command.gd")
const DeleteNodesCommand = preload("commands/delete_nodes_command.gd")
const CreateNodeCommand = preload("commands/create_node_command.gd")
const MoveNodesCommand = preload("commands/move_nodes_command.gd")
const ConnectionCommand = preload("commands/connection_command.gd")
const PasteNodesCommand = preload("commands/paste_nodes_command.gd")
const ChangeDictionaryValueCommand = preload("commands/change_dictionary_value_command.gd")
const AddObjectiveCommand = preload("commands/add_objective_command.gd")
const RemoveObjectiveCommand = preload("commands/remove_objective_command.gd")
const AddConditionCommand = preload("commands/add_condition_command.gd")
const RemoveConditionCommand = preload("commands/remove_condition_command.gd")
const AddParallelPortCommand = preload("commands/add_parallel_port_command.gd")
const RemoveParallelPortCommand = preload("commands/remove_parallel_port_command.gd")
const AddRandomPortCommand = preload("commands/add_random_port_command.gd")
const RemoveRandomPortCommand = preload("commands/remove_random_port_command.gd")
const AddSyncInputPortCommand = preload("commands/add_sync_input_port_command.gd")
const RemoveSyncInputPortCommand = preload("commands/remove_sync_input_port_command.gd")
const AddSyncOutputPortCommand = preload("commands/add_sync_output_port_command.gd")
const RemoveSyncOutputPortCommand = preload("commands/remove_sync_output_port_command.gd")
const CreateBackdropCommand = preload("commands/create_backdrop_command.gd")
const AddPayloadCommand = preload("commands/add_payload_command.gd")
const RemovePayloadCommand = preload("commands/remove_payload_command.gd")


# --- Dependencies ---
var _history: QWEditorHistory
var _data_manager: QWGraphData
var _properties_panel: PanelContainer
var _graph_controller: QuestWeaverGraphController
var _clipboard: QWClipboard
var _editor: QuestWeaverEditor

# --- State ---
var _drag_start_positions: Dictionary = {}


func initialize(p_editor: QuestWeaverEditor, p_history: QWEditorHistory, p_data_manager: QWGraphData, p_properties_panel: PanelContainer, p_graph_controller: QuestWeaverGraphController, p_clipboard: QWClipboard) -> void:
	self._editor = p_editor
	self._history = p_history
	self._data_manager = p_data_manager
	self._properties_panel = p_properties_panel
	self._graph_controller = p_graph_controller
	self._clipboard = p_clipboard


func on_node_property_update_requested(node_id: String, property_name: String, new_value: Variant, sub_resource: Resource = null) -> void:
	var editable_graph = _data_manager.make_active_graph_editable()
	if not is_instance_valid(editable_graph): return
		
	var target_resource = sub_resource if is_instance_valid(sub_resource) else editable_graph.nodes.get(node_id)
	if not is_instance_valid(target_resource): return

	if property_name == "is_terminal" and new_value == true and sub_resource == null:
		_handle_terminal_toggle(editable_graph, node_id, target_resource)
		return

	var command = ChangePropertyCommand.new(target_resource, property_name, new_value)
	_history.execute_command(command)
	
	node_data_changed.emit(node_id, property_name)
	_graph_controller.call_deferred("grab_focus")


func on_complex_action_requested(node_id: String, action: String, payload: Dictionary) -> void:
	var editable_graph = _data_manager.make_active_graph_editable()
	if not is_instance_valid(editable_graph): return
	
	var node_data = editable_graph.nodes.get(node_id)
	if not is_instance_valid(node_data): return

	var command: EditorCommand
	
	match action:
		"add_objective":
			if node_data is TaskNodeResource: command = AddObjectiveCommand.new(node_data)
		"remove_objective":
			if node_data is TaskNodeResource: command = RemoveObjectiveCommand.new(node_data, payload.get("objective"))
		"add_condition":
			if node_data is BranchNodeResource: command = AddConditionCommand.new(node_data)
		"remove_condition":
			if node_data is BranchNodeResource: command = RemoveConditionCommand.new(node_data, payload.get("condition"))
		"update_objective_trigger_param":
			var objective: ObjectiveResource = payload.get("objective")
			if is_instance_valid(objective): command = ChangeDictionaryValueCommand.new(objective.trigger_params, payload.get("param_name"), payload.get("param_value"))
		"add_parallel_output":
			if node_data is ParallelNodeResource: command = AddParallelPortCommand.new(node_data)
		"remove_parallel_output":
			if node_data is ParallelNodeResource: command = RemoveParallelPortCommand.new(editable_graph, node_data, payload.get("index", -1))
		"update_parallel_port_name":
			if node_data is ParallelNodeResource: command = ChangePropertyCommand.new(node_data.outputs[payload.get("index")], "port_name", payload.get("new_name"))
		"add_random_output":
			if node_data is RandomNodeResource: command = AddRandomPortCommand.new(node_data)
		"remove_random_output":
			if node_data is RandomNodeResource: command = RemoveRandomPortCommand.new(editable_graph, node_data, payload.get("index", -1))
		"update_random_output_name":
			if node_data is RandomNodeResource: command = ChangePropertyCommand.new(node_data.outputs[payload.get("index")], "port_name", payload.get("new_name"))
		"add_sync_input":
			if node_data is SynchronizeNodeResource: command = AddSyncInputPortCommand.new(node_data)
		"remove_sync_input":
			if node_data is SynchronizeNodeResource: command = RemoveSyncInputPortCommand.new(editable_graph, node_data, payload.get("index", -1))
		"update_sync_input_name":
			if node_data is SynchronizeNodeResource: command = ChangePropertyCommand.new(node_data.inputs[payload.get("index")], "port_name", payload.get("new_name"))
		"add_sync_output":
			if node_data is SynchronizeNodeResource: command = AddSyncOutputPortCommand.new(node_data)
		"remove_sync_output":
			if node_data is SynchronizeNodeResource: command = RemoveSyncOutputPortCommand.new(editable_graph, node_data, payload.get("index", -1))
		"update_sync_output_name":
			if node_data is SynchronizeNodeResource: command = ChangePropertyCommand.new(node_data.outputs[payload.get("index")], "port_name", payload.get("new_name"))
		"add_payload_entry":
			if node_data is EventNodeResource: command = AddPayloadCommand.new(node_data)
		"remove_payload_entry":
			if node_data is EventNodeResource: command = RemovePayloadCommand.new(node_data, payload.get("entry"))
		_:
			push_warning("QWActionHandler: Received unknown complex action '%s'" % action)

	if is_instance_valid(command):
		_history.execute_command(command)
	
	node_data_changed.emit(node_id, action)


func on_begin_node_move() -> void:
	var current_graph = _data_manager.get_active_graph()
	if not is_instance_valid(current_graph): return
	
	_drag_start_positions.clear()
	for node in _graph_controller.get_children():
		if (node is GraphNode or node is GraphFrame) and node.selected:
			var node_data = current_graph.nodes.get(node.name)
			if is_instance_valid(node_data):
				_drag_start_positions[node.name] = node_data.graph_position


func on_end_node_move() -> void:
	var current_graph_instance = _data_manager.get_active_graph()
	if not is_instance_valid(current_graph_instance) or _drag_start_positions.is_empty():
		return
	
	var end_positions = {}
	for node_id_sname in _drag_start_positions:
		var visual_node = _graph_controller.get_node_or_null(NodePath(node_id_sname))
		if is_instance_valid(visual_node):
			end_positions[node_id_sname] = visual_node.position_offset

	var command = MoveNodesCommand.new(current_graph_instance, _graph_controller, _drag_start_positions, end_positions)
	_history.execute_command(command)
	_drag_start_positions.clear()


func on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if from_node == to_node: return
	var editable_graph = _data_manager.make_active_graph_editable()
	if not is_instance_valid(editable_graph): return
	
	var command = ConnectionCommand.new(_editor, editable_graph, from_node, from_port, to_node, to_port, true)
	_history.execute_command(command)


func on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var editable_graph = _data_manager.make_active_graph_editable()
	if not is_instance_valid(editable_graph): return
	
	var command = ConnectionCommand.new(_editor, editable_graph, from_node, from_port, to_node, to_port, false)
	_history.execute_command(command)


func on_nodes_deleted(node_ids: Array[StringName]) -> void:
	var editable_graph = _data_manager.make_active_graph_editable()
	if not is_instance_valid(editable_graph): return
	
	# --- SECURITY CHECK ---
	var filtered_ids: Array[StringName] = []
	
	for id_name in node_ids:
		var id_str = String(id_name)
		var node_data = editable_graph.nodes.get(id_str)
		
		# Check if the node is protected (StartNode)
		if node_data is StartNodeResource:
			push_warning("QuestWeaver: Cannot delete the Start Node.")
			continue
			
		filtered_ids.append(id_name)
	
	if filtered_ids.is_empty():
		return
	# ----------------------
		
	var command = DeleteNodesCommand.new(_editor, editable_graph, filtered_ids)
	_history.execute_command(command)

	if _properties_panel.has_method("clear_inspection"):
		_properties_panel.clear_inspection()


func copy_selection_to_clipboard() -> void:
	var current_graph = _data_manager.get_active_graph()
	if not is_instance_valid(current_graph):
		return

	var selected_nodes_data: Array[GraphNodeResource] = []
	for node in _graph_controller.get_children():
		if node is GraphElement and node.selected:
			var node_data = current_graph.nodes.get(node.name)
			if is_instance_valid(node_data):
				selected_nodes_data.append(node_data)

	_clipboard.copy_selection_to_clipboard(selected_nodes_data, current_graph.connections)


func paste_from_clipboard() -> void:
	var editable_graph = _data_manager.make_active_graph_editable()
	if not is_instance_valid(editable_graph) or _clipboard.is_empty():
		return
	
	var graph_zoom = _graph_controller.zoom if _graph_controller.zoom > 0 else 1.0
	var paste_center_position = _graph_controller.scroll_offset + (_graph_controller.get_local_mouse_position() / graph_zoom)
	
	var paste_data = _clipboard.get_paste_data(paste_center_position)
	if paste_data.is_empty():
		return
	
	var command = PasteNodesCommand.new(_editor, editable_graph, _graph_controller, paste_data)
	_history.execute_command(command)


func save_all_modified_graphs() -> void:
	var unsaved_paths = _data_manager.get_all_unsaved_paths()
	if unsaved_paths.is_empty():
		return
		
	for path in unsaved_paths:
		_editor.save_single_file(path)


func _handle_terminal_toggle(graph: QuestGraphResource, node_id: String, node_resource: GraphNodeResource) -> void:
	var composite = CompositeCommand.new()
	var connections_to_remove: Array[Dictionary] = []
	for conn in graph.connections:
		if conn.from_node == node_id:
			connections_to_remove.append(conn)
	
	for conn in connections_to_remove:
		# is_connect_action = false (Disconnect)
		var disconnect_cmd = ConnectionCommand.new(
			_editor, graph, 
			conn.from_node, conn.from_port, 
			conn.to_node, conn.to_port, 
			false
		)
		composite.add_command(disconnect_cmd)

	var prop_cmd = ChangePropertyCommand.new(node_resource, "is_terminal", true)
	composite.add_command(prop_cmd)

	_history.execute_command(composite)

	node_data_changed.emit(node_id, "is_terminal")
	_graph_controller.call_deferred("grab_focus")
