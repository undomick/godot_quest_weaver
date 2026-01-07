# res://addons/quest_weaver/nodes/action/give_take_item_node/give_take_item_node_executor.gd
class_name GiveTakeItemNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var item_node = node as GiveTakeItemNodeResource
	if not is_instance_valid(item_node): 
		# If the node type is wrong for some reason, we safely complete it.
		context.quest_controller.complete_node(node)
		return
	
	var logger = context.logger
	
	if not is_instance_valid(logger):
		pass 
	
	var controller = context.quest_controller
	var adapter = controller._inventory_adapter
	
	if is_instance_valid(logger):
		logger.log("Executor", "\n--- [GiveTakeItemNode] Executing node '%s' ---" % item_node.id)
	
	# Case 1: No inventory system available
	if not is_instance_valid(adapter):
		if is_instance_valid(logger):
			logger.warn("Inventory", "  - No inventory adapter configured. Activating 'Failure' path.")
		controller._trigger_next_nodes_from_port(item_node, 1) # Port 1: Failure
		controller._mark_node_as_complete(item_node)
		return 
	
	# Case 2: Node is not configured correctly in the editor
	if item_node.item_id.is_empty() or item_node.amount <= 0:
		if is_instance_valid(logger):
			logger.warn("Inventory", "  - item_id is empty or amount is invalid. Activating 'Failure' path for safety.")
		# We choose Failure here because an unconfigured node should not result in success.
		controller._trigger_next_nodes_from_port(item_node, 1) # Port 1: Failure
		controller._mark_node_as_complete(item_node)
		return 
		
	# Case 3: Core logic
	match item_node.action:
		item_node.Action.GIVE:
			if is_instance_valid(logger):
				logger.log("Inventory", "  - Action: GIVE")
				logger.log("Inventory", "  - Attempting to give %d x '%s'." % [item_node.amount, item_node.item_id])
			adapter.give_item(item_node.item_id, item_node.amount)
			if is_instance_valid(logger):
				logger.log("Inventory", "  - Result: SUCCESS (Give action always succeeds for now)")
			controller._trigger_next_nodes_from_port(item_node, 0) # Port 0: Success
			controller._mark_node_as_complete(item_node)

		item_node.Action.TAKE:
			if is_instance_valid(logger):
				logger.log("Inventory", "  - Action: TAKE")
				logger.log("Inventory", "  - Attempting to take %d x '%s'." % [item_node.amount, item_node.item_id])
			var success = adapter.take_item(item_node.item_id, item_node.amount)
			if success:
				if is_instance_valid(logger):
					logger.log("Inventory", "  - Result: SUCCESS (Items were taken)")
				controller._trigger_next_nodes_from_port(item_node, 0) # Port 0: Success
			else:
				if is_instance_valid(logger):
					logger.log("Inventory", "  - Result: FAILURE (Not enough items to take)")
				controller._trigger_next_nodes_from_port(item_node, 1) # Port 1: Failure
			
			# The node is marked as complete regardless of success or failure.
			controller._mark_node_as_complete(item_node)
