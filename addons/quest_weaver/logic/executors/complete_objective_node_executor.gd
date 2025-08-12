# res://addons/quest_weaver/logic/executors/complete_objective_node_executor.gd
class_name CompleteObjectiveNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var comp_node = node as CompleteObjectiveNodeResource
	var logger = QuestWeaverServices.logger
	
	if not is_instance_valid(comp_node) or comp_node.target_objective_id.is_empty():
		if is_instance_valid(logger):
			logger.warn("Executor", "CompleteObjectiveNode '%s' has no target_objective_id. Skipping." % node.id)
		context.quest_controller.complete_node(node)
		return
	
	if is_instance_valid(logger):
		logger.log("Executor", "Completing manual objective with ID: '%s'" % comp_node.target_objective_id)
		
	context.quest_controller.complete_manual_objective(comp_node.target_objective_id)
	context.quest_controller.complete_node(node)
