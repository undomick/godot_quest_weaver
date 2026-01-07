# res://addons/quest_weaver/nodes/logic/reset_progress_node/reset_progress_node_executor.gd
class_name ResetProgressNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var reset_node = node as ResetProgressNodeResource
	if not is_instance_valid(reset_node): return

	var controller = context.quest_controller
	var scope_manager = controller._scope_manager
	var target_scope_id = reset_node.target_scope_id
	
	if target_scope_id.is_empty():
		push_warning("ResetProgressNode '%s' has no target_scope_id." % reset_node.id)
		controller.complete_node(reset_node)
		return

	var nodes_to_reset_ids: Array[String] = scope_manager.handle_reset_scope(reset_node)
	
	if nodes_to_reset_ids.is_empty():
		push_warning("Could not find any nodes to reset in scope '%s'." % target_scope_id)
		controller.complete_node(reset_node)
		return

	var logger = controller._get_logger()
	if logger:
		logger.log("Flow", "Resetting %d nodes in scope '%s'." % [nodes_to_reset_ids.size(), target_scope_id])

	for node_id in nodes_to_reset_ids:
		var node_instance = controller._active_nodes.get(node_id)
		
		if is_instance_valid(node_instance):
			# Cleanup listeners (Tasks, Events)
			if node_instance is TaskNodeResource:
				var executor = controller._executors.get(node_instance.get_script())
				if executor and executor.has_method("cleanup_listeners"):
					executor.cleanup_listeners(context, node_instance)
			if node_instance is EventListenerNodeResource:
				controller._event_manager.unregister_listener(node_instance)
			if node_instance is TimerNodeResource:
				controller._timer_manager.remove_timer(node_id)
				
			controller._active_nodes.erase(node_id)
			
		if controller._completed_nodes.has(node_id): 
			controller._completed_nodes.erase(node_id)

	if reset_node.restart_scope_on_completion:
		var start_node_def = controller._node_definitions.get(scope_manager.get_start_node_id_for_scope(target_scope_id))
		
		controller._mark_node_as_logically_complete(reset_node) 
		
		if is_instance_valid(start_node_def):
			controller._activate_node(start_node_def)
		else:
			push_error("Could not find StartScopeNode with ID '%s' to restart." % target_scope_id)
	else:
		controller.complete_node(reset_node)
