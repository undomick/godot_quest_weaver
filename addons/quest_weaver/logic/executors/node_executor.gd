# res://addons/quest_weaver/logic/executors/node_executor.gd
class_name NodeExecutor
extends RefCounted

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Executor", "Executing node '%s' with base executor (no specific logic)." % node.id)
	
	context.quest_controller.complete_node(node)
