# res://addons/quest_weaver/nodes/flow/random_node/random_node_executor.gd
class_name RandomNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var random_node = node as RandomNodeResource
	if not is_instance_valid(random_node): return
	
	var logger = null
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var services = main_loop.root.get_node_or_null("QuestWeaverServices")
		if is_instance_valid(services):
			logger = services.logger
			
	if not is_instance_valid(logger): return
	
	logger.log("Flow", "Executing RandomNode '%s': Choosing random branch." % random_node.id)
	random_node.status = GraphNodeResource.Status.COMPLETED
	var controller = context.quest_controller
	controller._completed_nodes[random_node.id] = random_node
	if controller._active_nodes.has(random_node.id):
		controller._active_nodes.erase(random_node.id)

	if random_node.outputs.is_empty(): return

	var total_weight = 0
	for output_port in random_node.outputs:
		if is_instance_valid(output_port): total_weight += output_port.weight
	
	if total_weight <= 0: return
		
	var random_choice = randi_range(1, total_weight)
	var chosen_port_index = -1
	var current_weight_sum = 0
	for i in range(random_node.outputs.size()):
		var output_port = random_node.outputs[i]
		current_weight_sum += output_port.weight
		if random_choice <= current_weight_sum:
			chosen_port_index = i
			break
	
	if chosen_port_index == -1: chosen_port_index = 0
	
	var connections = controller._node_connections.get(random_node.id, [])
	for connection in connections:
		if connection.from_port == chosen_port_index:
			var next_node_def = controller._node_definitions.get(connection.to_node)
			if next_node_def:
				controller._activate_node(next_node_def, connection.to_port)
			break
