# res://addons/quest_weaver/nodes/flow/parallel_node/parallel_node_executor.gd
class_name ParallelNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var parallel_node = node as ParallelNodeResource
	if not is_instance_valid(parallel_node): return
	
	var logger = context.logger

	if is_instance_valid(logger):
		logger.log("Flow", "Executing ParallelNode '%s': Evaluating %d branches." % [parallel_node.id, parallel_node.outputs.size()])
	
	parallel_node.status = GraphNodeResource.Status.COMPLETED
	
	var controller = context.quest_controller
	controller._completed_nodes[parallel_node.id] = parallel_node
	if controller._active_nodes.has(parallel_node.id):
		controller._active_nodes.erase(parallel_node.id)
	
	var connections = controller._node_connections.get(parallel_node.id, [])
	if connections.is_empty(): return
	
	# Check conditions for each output port
	for i in range(parallel_node.outputs.size()):
		var output_info: ParallelOutputPort = parallel_node.outputs[i]
		var should_fire = true
		
		# Important: We pass the ExecutionContext to the condition's check method.
		if is_instance_valid(output_info.condition):
			should_fire = output_info.condition.check(context)
		
		if should_fire:
			for connection in connections:
				if connection.from_port == i:
					var next_node_def = controller._node_definitions.get(connection.to_node)
					if next_node_def:
						controller._activate_node(next_node_def, connection.to_port)
					break
