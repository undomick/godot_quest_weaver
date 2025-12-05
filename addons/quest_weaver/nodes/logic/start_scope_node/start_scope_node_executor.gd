# res://addons/quest_weaver/nodes/logic/start_scope_node/start_scope_node_executor.gd
class_name StartScopeNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var scope_node = node as StartScopeNodeResource
	if not is_instance_valid(scope_node): return

	var controller = context.quest_controller

	# Safe logger lookup to avoid static dependency issues
	var logger = null
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var services = main_loop.root.get_node_or_null("QuestWeaverServices")
		if is_instance_valid(services):
			logger = services.logger

	# Check if the execution limit is reached. 0 means infinite.
	var limit_reached = (scope_node.max_executions > 0 and \
						 scope_node.current_executions >= scope_node.max_executions)

	if limit_reached:
		if logger:
			logger.log("Flow", "Executing StartScopeNode '%s': Max executions (%d) reached." % [scope_node.id, scope_node.max_executions])
		
		# Fire the "On Max Reached" output (Port 1)
		controller._trigger_next_nodes_from_port(scope_node, 1)
		
		# Important: Mark the node as logically complete without firing the default port.
		controller._mark_node_as_logically_complete(scope_node)
	else:
		# Increment execution counter
		scope_node.current_executions += 1
		
		if logger:
			logger.log("Flow", "Executing StartScopeNode '%s': Entering scope '%s'. (Execution #%d)" % [scope_node.id, scope_node.scope_id, scope_node.current_executions])
		
		# Complete the node normally and fire the "On Start" output (Port 0).
		controller.complete_node(scope_node)
