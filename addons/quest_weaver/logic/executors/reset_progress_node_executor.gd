# res://addons/quest_weaver/logic/executors/reset_progress_node_executor.gd
class_name ResetProgressNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var reset_node = node as ResetProgressNodeResource
	if not is_instance_valid(reset_node): return

	var controller = context.quest_controller
	var target_scope_id = reset_node.target_scope_id
	if target_scope_id.is_empty():
		push_warning("ResetProgressNode '%s' has no target_scope_id." % reset_node.id)
		controller.complete_node(reset_node)
		return

	var start_node_of_scope: StartScopeNodeResource = null
	var end_nodes_of_scope: Array[EndScopeNodeResource] = []
	for node_def in controller._node_definitions.values():
		if node_def is StartScopeNodeResource and node_def.scope_id == target_scope_id:
			start_node_of_scope = node_def
		elif node_def is EndScopeNodeResource and node_def.scope_id == target_scope_id:
			end_nodes_of_scope.append(node_def)
	
	if not start_node_of_scope:
		push_warning("Could not find StartScopeNode for Scope '%s'." % target_scope_id)
		controller.complete_node(reset_node)
		return
	if end_nodes_of_scope.is_empty():
		push_warning("Could not find ANY EndScopeNode for Scope '%s'. Aborting reset." % target_scope_id)
		controller.complete_node(reset_node)
		return

	var nodes_in_scope: Dictionary = {}
	var queue: Array = [start_node_of_scope.id]
	var visited: Dictionary = { start_node_of_scope.id: true }

	while not queue.is_empty():
		var current_node_id = queue.pop_front()
		
		var node_def = controller._node_definitions.get(current_node_id)
		if is_instance_valid(node_def):
			if node_def.id != start_node_of_scope.id:
				nodes_in_scope[node_def.id] = node_def
			
			var connections = controller._node_connections.get(current_node_id, [])
			for connection in connections:
				var next_node_id = connection.get("to_node")
				
				var next_node_def = controller._node_definitions.get(next_node_id)
				if visited.has(next_node_id) or \
				   (next_node_def in end_nodes_of_scope) or \
				   (next_node_def == reset_node):
					continue
				
				visited[next_node_id] = true
				queue.push_back(next_node_id)
	
	print("Resetting %d nodes in scope '%s'." % [nodes_in_scope.size(), target_scope_id])

	for node_id in nodes_in_scope:
		if controller._active_nodes.has(node_id):
			var node_instance = controller._active_nodes[node_id]
			if node_instance is TaskNodeResource:
				var executor = controller._executors.get(node_instance.get_script())
				if executor and executor.has_method("cleanup_listeners"):
					executor.cleanup_listeners(context, node_instance)
			controller._active_nodes.erase(node_id)
		if controller._completed_nodes.has(node_id): controller._completed_nodes.erase(node_id)
		
		controller._timer_manager.remove_timer(node_id)

		var node_def = controller._node_definitions.get(node_id)
		if is_instance_valid(node_def):
			node_def.status = GraphNodeResource.Status.LOCKED
			if node_def is TaskNodeResource:
				for objective in node_def.objectives:
					objective.current_progress = 0
					objective.set_status(ObjectiveResource.Status.INACTIVE)

	if reset_node.restart_scope_on_completion:
		controller._mark_node_as_logically_complete(reset_node)
		controller._activate_node(start_node_of_scope)
	else:
		controller.complete_node(reset_node)
