# res://addons/quest_weaver/nodes/action/give_take_item_node/give_take_item_node_executor.gd
class_name GiveTakeItemNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource, _instance: QuestInstance) -> void:
	var item_node = node as GiveTakeItemNodeResource
	if not is_instance_valid(item_node): 
		context.quest_controller.complete_node(node)
		return
	
	var logger = context.logger
	var controller = context.quest_controller
	var adapter = controller._inventory_adapter
	
	if is_instance_valid(logger):
		logger.log("Executor", "\n--- [GiveTakeItemNode] Executing node '%s' ---" % item_node.id)
	
	# Case 1: No inventory system available -> Failure
	if not is_instance_valid(adapter):
		if is_instance_valid(logger):
			logger.warn("Inventory", "  - No inventory adapter configured. Activating 'Failure' path.")
		controller._trigger_next_nodes_from_port(item_node, 1) # Port 1: Failure
		controller._mark_node_as_logically_complete(item_node)
		return 
	
	# Case 2: Validation Failure -> Failure
	if item_node.item_id.is_empty() or item_node.amount <= 0:
		if is_instance_valid(logger):
			logger.warn("Inventory", "  - item_id is empty or amount is invalid. Activating 'Failure' path.")
		controller._trigger_next_nodes_from_port(item_node, 1) # Port 1: Failure
		controller._mark_node_as_logically_complete(item_node)
		return 
		
	# Case 3: Core logic
	match item_node.action:
		item_node.Action.GIVE:
			if is_instance_valid(logger):
				logger.log("Inventory", "  - Action: GIVE %d x '%s'" % [item_node.amount, item_node.item_id])
			
			adapter.give_item(item_node.item_id, item_node.amount)
			
			# Give always succeeds
			controller._trigger_next_nodes_from_port(item_node, 0) # Port 0: Success
			controller._mark_node_as_logically_complete(item_node)

		item_node.Action.TAKE:
			if is_instance_valid(logger):
				logger.log("Inventory", "  - Action: TAKE %d x '%s'" % [item_node.amount, item_node.item_id])
			
			var success = adapter.take_item(item_node.item_id, item_node.amount)
			if success:
				if is_instance_valid(logger): logger.log("Inventory", "  - Result: SUCCESS")
				controller._trigger_next_nodes_from_port(item_node, 0) # Port 0: Success
			else:
				if is_instance_valid(logger): logger.log("Inventory", "  - Result: FAILURE (Insufficient items)")
				controller._trigger_next_nodes_from_port(item_node, 1) # Port 1: Failure
			
			# Mark finished without firing default port again
			controller._mark_node_as_logically_complete(item_node)
