# res://addons/quest_weaver/nodes/logic/sub_graph_node/sub_graph_node_executor.gd
class_name SubGraphNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var subgraph_node = node as SubGraphNodeResource
	if not is_instance_valid(subgraph_node): return

	var controller = context.quest_controller
	var graph_path = subgraph_node.quest_graph_path

	if graph_path.is_empty() or not ResourceLoader.exists(graph_path):
		controller.complete_node(subgraph_node)
		return

	if subgraph_node.wait_for_completion:
		subgraph_node.status = GraphNodeResource.Status.ACTIVE
		controller.push_to_call_stack(subgraph_node.id)
	
	controller.start_sub_graph(graph_path)

	if not subgraph_node.wait_for_completion:
		controller.complete_node(subgraph_node)
