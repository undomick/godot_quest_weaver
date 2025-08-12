# res://addons/quest_weaver/logic/executors/branch_node_executor.gd
class_name BranchNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var branch_node = node as BranchNodeResource
	if not is_instance_valid(branch_node):
		context.quest_controller.complete_node(node)
		return

	var result_is_true = branch_node.check_all_conditions(context)
	
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Flow", "  <- Completing BranchNode: '%s' with result '%s'" % [branch_node.id, result_is_true])

	branch_node.status = GraphNodeResource.Status.COMPLETED
	var controller = context.quest_controller
	controller._completed_nodes[branch_node.id] = branch_node
	if controller._active_nodes.has(branch_node.id):
		controller._active_nodes.erase(branch_node.id)
	
	var port_to_trigger = 0 if result_is_true else 1
	
	controller._trigger_next_nodes_from_port(branch_node, port_to_trigger)
