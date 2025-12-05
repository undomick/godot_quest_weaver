# res://addons/quest_weaver/nodes/logic/quest_node/quest_node_executor.gd
class_name QuestNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var quest_node = node as QuestNodeResource
	if not is_instance_valid(quest_node):
		push_error("Executor expects a QuestNodeResource.")
		context.quest_controller.complete_node(node)
		return

	context.quest_controller.set_quest_status(quest_node.target_quest_id, quest_node.action)
	
	context.quest_controller.complete_node(node)
