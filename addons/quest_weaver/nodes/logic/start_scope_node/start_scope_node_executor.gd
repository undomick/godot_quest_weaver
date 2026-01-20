# res://addons/quest_weaver/nodes/logic/start_scope_node/start_scope_node_executor.gd
class_name StartScopeNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource, instance: QuestInstance) -> void:
	var scope_node = node as StartScopeNodeResource
	if not is_instance_valid(scope_node): return

	var controller = context.quest_controller
	var scope_manager = controller._scope_manager
	var logger = context.logger
	
	# Pass instance to manager so it can read/write execution counts there
	var should_start = scope_manager.handle_start_scope(scope_node, instance)
	
	if logger:
		logger.log("Flow", "StartScopeNode '%s': Entering scope '%s'. Allowed? %s" % [scope_node.id, scope_node.scope_id, should_start])

	if should_start:
		# Scope authorized: Enter via "On Start" (Port 0)
		controller.complete_node(scope_node)
	else:
		# Limit reached: Exit via "On Max Reached" (Port 1)
		# Important: Mark logically complete but do NOT trigger port 0.
		controller._mark_node_as_logically_complete(scope_node)
		controller._trigger_next_nodes_from_port(scope_node, 1)
