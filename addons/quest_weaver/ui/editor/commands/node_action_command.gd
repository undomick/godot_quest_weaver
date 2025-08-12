@tool
class_name NodeActionCommand
extends EditorCommand

var _node_data: GraphNodeResource
var _action: String
var _payload: Dictionary
var _undo_data: Dictionary # To store state for undoing

func _init(p_node_data: GraphNodeResource, p_action: String, p_payload: Dictionary):
	self._node_data = p_node_data
	self._action = p_action
	self._payload = p_payload

func execute() -> void:
	# Store the state BEFORE the action for undo purposes.
	# This needs to be specific for each action.
	match _action:
		"add_objective":
			# Nothing to store for undo, we just remove it.
			pass
		"remove_objective":
			# Store the objective and its original index.
			var objective = _payload.get("objective")
			var index = _node_data.objectives.find(objective)
			_undo_data = {"objective": objective, "index": index}
		
		"add_parallel_output", "add_random_output", "add_sync_input", "add_sync_output":
			# Similar to add_objective, undo is just removal.
			pass

		"remove_parallel_output":
			var index = _payload.get("index")
			_undo_data = {"port_data": _node_data.outputs[index].duplicate(true), "index": index}

		"remove_random_output":
			var index = _payload.get("index")
			_undo_data = {"port_data": _node_data.outputs[index].duplicate(true), "index": index}

		"remove_sync_input":
			var index = _payload.get("index")
			_undo_data = {"port_data": _node_data.inputs[index].duplicate(true), "index": index}
			
		"remove_sync_output":
			var index = _payload.get("index")
			_undo_data = {"port_data": _node_data.outputs[index].duplicate(true), "index": index}

	# Execute the action on the node's data resource.
	if _node_data.has_method(_action):
		_node_data.call(_action, _payload)

func undo() -> void:
	match _action:
		"add_objective":
			_node_data.objectives.pop_back() # Remove the last added one
		"remove_objective":
			var objective = _undo_data.get("objective")
			var index = _undo_data.get("index")
			if index > -1:
				_node_data.objectives.insert(index, objective)
		
		"add_parallel_output", "add_random_output":
			_node_data.outputs.pop_back()
			
		"add_sync_input":
			_node_data.inputs.pop_back()
			
		"add_sync_output":
			_node_data.outputs.pop_back()

		"remove_parallel_output", "remove_random_output", "remove_sync_output":
			var port_data = _undo_data.get("port_data")
			var index = _undo_data.get("index")
			if index > -1:
				_node_data.outputs.insert(index, port_data)
		
		"remove_sync_input":
			var port_data = _undo_data.get("port_data")
			var index = _undo_data.get("index")
			if index > -1:
				_node_data.inputs.insert(index, port_data)
