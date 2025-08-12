# res://addons/quest_weaver/logic/executors/parallel_node_executor.gd
class_name ParallelNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var parallel_node = node as ParallelNodeResource
	if not is_instance_valid(parallel_node): return
	
	var controller = context.quest_controller

	print("Executing ParallelNode '%s': Evaluating %d branches." % [parallel_node.id, parallel_node.outputs.size()])
	parallel_node.status = GraphNodeResource.Status.COMPLETED
	
	controller._completed_nodes[parallel_node.id] = parallel_node
	if controller._active_nodes.has(parallel_node.id):
		controller._active_nodes.erase(parallel_node.id)
	
	var connections = controller._node_connections.get(parallel_node.id, [])
	if connections.is_empty(): return
	
	# Wichtig: Wir übergeben den ExecutionContext an die check-Methode der Condition.
	for i in range(parallel_node.outputs.size()):
		var output_info: ParallelOutputPort = parallel_node.outputs[i]
		var should_fire = true
		if is_instance_valid(output_info.condition):
			should_fire = output_info.condition.check(context) # <- Hier wird der Kontext weitergereicht
		
		if should_fire:
			for connection in connections:
				if connection.from_port == i:
					var next_node_def = controller._node_definitions.get(connection.to_node)
					if next_node_def:
						controller._activate_node(next_node_def, connection.to_port)
					break
