# res://addons/quest_weaver/nodes/logic/text_node/text_node_executor.gd
class_name TextNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var text_node = node as TextNodeResource
	if not is_instance_valid(text_node):
		push_error("Executor erwartet einen TextNodeResource.")
		context.quest_controller.complete_node(node)
		return

	match text_node.target_property:
		TextNodeResource.TextTarget.ADD_TO_QUEST_LOG:
			context.quest_controller.add_quest_log_entry(text_node.id, text_node.text_content)
		TextNodeResource.TextTarget.SET_QUEST_DESCRIPTION:
			context.quest_controller.set_quest_description(text_node.id, text_node.text_content)
	
	context.quest_controller.complete_node(node)
