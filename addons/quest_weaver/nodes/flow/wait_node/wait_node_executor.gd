# res://addons/quest_weaver/nodes/flow/wait_node/wait_node_executor.gd
class_name WaitNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var wait_node = node as WaitNodeResource
	if not is_instance_valid(wait_node): return
	
	var controller = context.quest_controller
	var logger = context.logger
	
	if not is_instance_valid(logger): return
	
	logger.log("Executor", "Executing WaitNode '%s': Waiting for %s seconds..." % [wait_node.id, wait_node.wait_duration])
	wait_node.status = GraphNodeResource.Status.ACTIVE
	
	if not is_instance_valid(controller): return
	await controller.get_tree().create_timer(wait_node.wait_duration).timeout
	
	if not controller._active_nodes.has(wait_node.id):
		return
	
	logger.log("Executor", "  - WaitNode '%s' finished waiting." % wait_node.id)
	controller.complete_node(wait_node)
