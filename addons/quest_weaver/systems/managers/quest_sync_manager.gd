# res://addons/quest_weaver/systems/managers/quest_sync_manager.gd
class_name QuestSyncManager
extends RefCounted

## Manages synchronization logic. State is stored in QuestInstance.

var _controller_weak: WeakRef

func _init(p_controller: QuestController):
	self._controller_weak = weakref(p_controller)

func _get_controller() -> QuestController:
	return _controller_weak.get_ref() as QuestController

## Called by SynchronizeNodeExecutor when an input is received.
func handle_input(node_def: SynchronizeNodeResource, instance: QuestInstance, received_on_port: int) -> void:
	var controller = _get_controller()
	if not controller: return

	var node_id = node_def.id
	var logger = controller._get_logger()

	# 1. Fetch State (or init)
	# State Format: { "inputs_received": [false, false, true] }
	var state = instance.get_node_state(node_id)
	var inputs_received: Array = state.get("inputs_received", [])
	
	# Init array if empty or size mismatch (e.g. after editing graph)
	if inputs_received.size() != node_def.inputs.size():
		inputs_received = []
		inputs_received.resize(node_def.inputs.size())
		inputs_received.fill(false)

	if logger:
		logger.log("Flow", "Synchronizer '%s' received input on port %d." % [node_id, received_on_port])

	# 2. Update State
	if received_on_port >= 0 and received_on_port < inputs_received.size():
		if not inputs_received[received_on_port]:
			inputs_received[received_on_port] = true
			instance.set_node_data(node_id, "inputs_received", inputs_received)
	else:
		push_warning("Synchronizer '%s' received signal on invalid port %d." % [node_id, received_on_port])

	# 3. Check Completion
	var should_complete = false
	match node_def.completion_mode:
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_ALL:
			if not false in inputs_received: should_complete = true
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_ANY:
			# Fires only on the very first input received (count == 1)
			if inputs_received.count(true) == 1: should_complete = true
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_N_INPUTS:
			if inputs_received.count(true) >= node_def.required_input_count: should_complete = true

	if should_complete:
		if logger: logger.log("Flow", "  - Synchronizer '%s' met completion condition." % node_id)
		
		# Fire outputs
		_fire_outputs(node_def, instance, inputs_received, controller)
		
		# Mark logically complete (cleanup state)
		instance.set_node_active(node_id, false)
		instance.clear_node_state(node_id)
	else:
		if logger: logger.log("Flow", "  - Synchronizer '%s' waiting. State: %s" % [node_id, inputs_received])

func _fire_outputs(node_def: SynchronizeNodeResource, instance: QuestInstance, inputs_state: Array, controller: QuestController) -> void:
	var connections = controller._node_connections.get(node_def.id, [])

	for i in range(node_def.outputs.size()):
		var output_port = node_def.outputs[i]
		var should_fire = true
		
		if is_instance_valid(output_port.condition):
			# Special handling for CHECK_SYNCHRONIZER condition type
			# We construct a temporary context just for this check if needed,
			# OR we ensure ConditionResource reads from instance if implemented.
			# Since CHECK_SYNCHRONIZER relies on the array, we pass it via a Dictionary context.
			var check_context = controller._execution_context
			
			if output_port.condition.type == ConditionResource.ConditionType.CHECK_SYNCHRONIZER:
				check_context = { "sync_inputs_received_array": inputs_state }
			
			should_fire = output_port.condition.check(check_context, instance)
		
		if should_fire:
			for connection in connections:
				if connection.from_port == i:
					var next_node_def = controller._node_definitions.get(connection.to_node)
					if next_node_def:
						controller._activate_node(next_node_def, connection.to_port)

func clear():
	# No internal state to clear anymore
	pass
