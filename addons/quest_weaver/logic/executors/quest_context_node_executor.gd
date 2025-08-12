# res://addons/quest_weaver/logic/executors/quest_context_node_executor.gd
class_name QuestContextNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var context_node = node as QuestContextNodeResource
	if not is_instance_valid(context_node):
		push_error("Executor expects a QuestContextNodeResource.")
		context.quest_controller.complete_node(node)
		return
	
	context.quest_controller.start_quest(context_node)
	
	context.quest_controller.complete_node(node)
