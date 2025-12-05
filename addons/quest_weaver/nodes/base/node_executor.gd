# res://addons/quest_weaver/nodes/base/node_executor.gd
class_name NodeExecutor
extends RefCounted

# Base class for all Executors.
func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	# This base method serves as a fallback or template.
	context.quest_controller.complete_node(node)
