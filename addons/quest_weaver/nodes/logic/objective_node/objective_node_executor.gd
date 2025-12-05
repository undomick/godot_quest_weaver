# res://addons/quest_weaver/nodes/logic/objective_node/objective_node_executor.gd
class_name ObjectiveNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var obj_node = node as ObjectiveNodeResource
	var logger = null
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var services = main_loop.root.get_node_or_null("QuestWeaverServices")
		if is_instance_valid(services):
			logger = services.logger
	
	if not is_instance_valid(obj_node) or obj_node.target_objective_id.is_empty():
		if is_instance_valid(logger):
			logger.warn("Executor", "ObjectiveNode '%s' has no target ID." % node.id)
		context.quest_controller.complete_node(node)
		return
	
	var target_status = ObjectiveResource.Status.COMPLETED
	
	match obj_node.action:
		ObjectiveNodeResource.Action.COMPLETE:
			target_status = ObjectiveResource.Status.COMPLETED
		ObjectiveNodeResource.Action.FAIL:
			target_status = ObjectiveResource.Status.FAILED
		ObjectiveNodeResource.Action.RESET:
			target_status = ObjectiveResource.Status.ACTIVE
	
	context.quest_controller.set_manual_objective_status(obj_node.target_objective_id, target_status)
	
	context.quest_controller.complete_node(node)
