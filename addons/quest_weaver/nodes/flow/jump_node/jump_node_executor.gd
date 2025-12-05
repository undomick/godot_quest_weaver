# res://addons/quest_weaver/nodes/flow/jump_node/jump_node_executor.gd
class_name JumpNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var jump_node = node as JumpNodeResource
	if not is_instance_valid(jump_node): return
	
	var controller = context.quest_controller
	
	if jump_node.target_anchor_name.is_empty():
		# Safe logger lookup to avoid static dependency issues on first load
		var logger = null
		var main_loop = Engine.get_main_loop()
		if main_loop and main_loop.root:
			var services = main_loop.root.get_node_or_null("QuestWeaverServices")
			if is_instance_valid(services):
				logger = services.logger
		
		if logger:
			logger.warn("Flow", "JumpNode '%s' has no target anchor name." % jump_node.id)
			
		# Terminate the node without jumping (Dead end)
		controller._mark_node_as_complete(jump_node)
		return

	# Call the controller to handle the jump logic
	controller.jump_to_anchor(jump_node, jump_node.target_anchor_name)
	
	# Mark node as complete (does not fire any output ports since JumpNode has none)
	controller._mark_node_as_complete(jump_node)
