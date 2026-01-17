# res://addons/quest_weaver/systems/managers/quest_sync_manager.gd
class_name QuestSyncManager
extends RefCounted

## Manages the state of all active SynchronizeNode instances.

var _active_synchronizers: Dictionary = {} # { "sync_node_id": { "inputs_received": [bool], "instance": SynchronizeNodeResource} }
var _controller: QuestController

func _init(p_controller: QuestController):
	self._controller = p_controller

## Called when a quest execution flow reaches a SynchronizeNode on a specific port.
func handle_input(sync_node_def: SynchronizeNodeResource, received_on_port: int) -> void:
	var node_id = sync_node_def.id
	var logger = _controller._get_logger() # Use the controller's helper for safe access

	if logger:
		logger.log("Flow", "Synchronizer '%s' received input on port %d." % [node_id, received_on_port])

	if not _active_synchronizers.has(node_id):
		var input_count = sync_node_def.inputs.size()
		_active_synchronizers[node_id] = {
			"inputs_received": [false] * input_count,
			"instance": sync_node_def.duplicate(true)
		}
		var instance = _active_synchronizers[node_id].instance
		instance.status = GraphNodeResource.Status.ACTIVE
		_controller._active_nodes[node_id] = instance

	var sync_state = _active_synchronizers[node_id]
	if received_on_port >= 0 and received_on_port < sync_state.inputs_received.size():
		if not sync_state.inputs_received[received_on_port]:
			sync_state.inputs_received[received_on_port] = true
	else:
		push_warning("Synchronizer '%s' received signal on invalid port %d." % [node_id, received_on_port])

	var should_complete = false
	match sync_node_def.completion_mode:
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_ALL:
			if not false in sync_state.inputs_received: should_complete = true
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_ANY:
			# Fires only on the very first input received.
			if sync_state.inputs_received.count(true) == 1: should_complete = true
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_N_INPUTS:
			var received_count = sync_state.inputs_received.count(true)
			if received_count >= sync_node_def.required_input_count: should_complete = true

	if should_complete:
		if logger: logger.log("Flow", "  - Synchronizer '%s' met its completion condition." % node_id)
		var instance_to_complete = sync_state.instance
		
		# Remove from tracking before firing outputs to prevent re-entry issues.
		remove_synchronizer(node_id)
		
		# Fire outputs with the final state.
		_fire_outputs(instance_to_complete, sync_state)
		
		# Mark the node as logically complete without firing default ports.
		_controller._mark_node_as_logically_complete(instance_to_complete)

	else:
		if logger: logger.log("Flow", "  - Synchronizer '%s' is waiting. Current state: %s" % [node_id, sync_state.inputs_received])

## Fires the outputs of a completed SynchronizeNode based on their conditions.
func _fire_outputs(sync_node_instance: SynchronizeNodeResource, final_sync_state: Dictionary) -> void:
	var connections = _controller._node_connections.get(sync_node_instance.id, [])

	for i in range(sync_node_instance.outputs.size()):
		var output_port_info: SynchronizeOutputPort = sync_node_instance.outputs[i]
		
		var should_fire = true
		if is_instance_valid(output_port_info.condition):
			# We pass the full ExecutionContext so conditions like CHECK_ITEM or CHECK_VARIABLE work.
			# For CHECK_SYNCHRONIZER, we create a specific context dictionary.
			var context_for_check
			if output_port_info.condition.type == ConditionResource.ConditionType.CHECK_SYNCHRONIZER:
				context_for_check = {
					"sync_inputs_received_array": final_sync_state.inputs_received,
				}
			else:
				# Pass the full runtime context for other checks
				context_for_check = _controller._execution_context
			
			should_fire = output_port_info.condition.check(context_for_check)
		
		if should_fire:
			for connection in connections:
				if connection.from_port == i:
					var next_node_def = _controller._node_definitions.get(connection.to_node)
					if next_node_def:
						_controller._activate_node(next_node_def, connection.to_port)
					break

## Restores state from save data.
func load_save_data(data: Dictionary):
	_active_synchronizers = data.duplicate(true)

## Returns data for the save system.
func get_save_data() -> Dictionary:
	return _active_synchronizers.duplicate(true)

## Clears internal state.
func clear():
	_active_synchronizers.clear()

## Removes a specific synchronizer, e.g. when a quest fails or is reset.
func remove_synchronizer(node_id: String):
	if _active_synchronizers.has(node_id):
		_active_synchronizers.erase(node_id)

func get_active_synchronizer_ids() -> Array:
	return _active_synchronizers.keys()
