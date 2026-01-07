# res://addons/quest_weaver/nodes/logic/start_scope_node/start_scope_node_executor.gd
class_name StartScopeNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var scope_node = node as StartScopeNodeResource
	if not is_instance_valid(scope_node): return

	var controller = context.quest_controller
	var scope_manager = controller._scope_manager
	var should_start = scope_manager.handle_start_scope(scope_node)
	var logger = context.logger
	if logger:
		logger.log("Flow", "Executing StartScopeNode '%s': Entering scope '%s'." % [scope_node.id, scope_node.scope_id])

	if should_start:
		# Complete the node normally and fire the "On Start" output (Port 0).
		controller.complete_node(scope_node)
	else:
		# Important: Mark the node as logically complete without firing the default port.
		controller._mark_node_as_logically_complete(scope_node)
		
		# Fire the "On Max Reached" output (Port 1)
		controller._trigger_next_nodes_from_port(scope_node, 1)
