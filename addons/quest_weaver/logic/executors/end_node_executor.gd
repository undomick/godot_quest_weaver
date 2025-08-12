# res://addons/quest_weaver/logic/executors/end_node_executor.gd
class_name EndNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var controller = context.quest_controller
	
	controller.complete_node(node)
	
	controller.pop_from_call_stack()
