# res://addons/quest_weaver/editor/commands/remove_sync_input_port_command.gd
@tool
class_name RemoveSyncInputPortCommand
extends EditorCommand

var _graph: QuestGraphResource
var _node_data: SynchronizeNodeResource
var _port_to_remove: SynchronizeInputPort
var _original_index: int = -1

# Stores the connection data for the undo operation.
var _removed_connections_data: Array[Dictionary] = []

func _init(p_graph: QuestGraphResource, p_node_data: SynchronizeNodeResource, p_index: int):
	self._graph = p_graph
	self._node_data = p_node_data
	
	if p_index >= 0 and p_index < p_node_data.inputs.size():
		self._port_to_remove = p_node_data.inputs[p_index]
		self._original_index = p_index

func execute() -> void:
	if not is_instance_valid(_port_to_remove): return

	# Step 1: Find, store, and remove connection DATA (checking 'to_node').
	_removed_connections_data = _graph.connections.filter(
		func(c): return c.to_node == _node_data.id and c.to_port == _original_index
	)
	if not _removed_connections_data.is_empty():
		_graph.connections = _graph.connections.filter(
			func(c): return not (c.to_node == _node_data.id and c.to_port == _original_index)
		)

	# Step 2: Shift the port indices of any subsequent connections.
	for conn in _graph.connections:
		if conn.to_node == _node_data.id and conn.to_port > _original_index:
			conn.to_port -= 1
			
	# Step 3: Remove the port DATA from the node's 'inputs' array.
	_node_data.inputs.erase(_port_to_remove)
	_node_data._update_ports_from_data()

func undo() -> void:
	if not is_instance_valid(_port_to_remove) or _original_index == -1: return
		
	# Step 1: Re-insert the port DATA into the node's 'inputs' array.
	_node_data.inputs.insert(_original_index, _port_to_remove)

	# Step 2: Shift back the port indices of subsequent connections.
	for conn in _graph.connections:
		if conn.to_node == _node_data.id and conn.to_port >= _original_index:
			conn.to_port += 1
	
	# Step 3: Restore the connection DATA to the main graph.
	_graph.connections.append_array(_removed_connections_data)
	_node_data._update_ports_from_data()
