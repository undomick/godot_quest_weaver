# res://addons/quest_weaver/systems/managers/quest_scope_manager.gd
class_name QuestScopeManager
extends Object

## Manages the execution state and reset logic for all active Scopes (StartScopeNode/EndScopeNode).

var _controller: QuestController

## Scope Definition (Read-only, loaded once from graph data)
## { "scope_id": { "start_node_id": "...", "nodes_in_scope": ["...", "..."] } }
var _scope_definitions: Dictionary = {} 

## Scope Runtime State (Saved/Loaded)
## { "scope_id": { "current_executions": 0 } }
var _scope_runtime_state: Dictionary = {}

func _init(p_controller: QuestController):
	self._controller = p_controller

## 1. Scope Definition (Builds the map of nodes inside each scope)

func initialize_scope_definitions(node_definitions: Dictionary, node_connections: Dictionary) -> void:
	_scope_definitions.clear()

	var start_nodes_by_id: Dictionary = {}
	var end_nodes_by_id: Dictionary = {}
	
	# Phase 1: Collect all scope nodes
	for node_def in node_definitions.values():
		if node_def is StartScopeNodeResource:
			start_nodes_by_id[node_def.scope_id] = node_def
		elif node_def is EndScopeNodeResource:
			if not end_nodes_by_id.has(node_def.scope_id):
				end_nodes_by_id[node_def.scope_id] = []
			end_nodes_by_id[node_def.scope_id].append(node_def)
	
	# Phase 2: Perform graph traversal (DFS) for each scope
	for scope_id in start_nodes_by_id:
		var start_node: StartScopeNodeResource = start_nodes_by_id[scope_id]
		var end_nodes: Array[EndScopeNodeResource] = end_nodes_by_id.get(scope_id, [])
		
		if end_nodes.is_empty():
			_controller._get_logger().warn("System", "Scope '%s' has a StartNode but no EndNode. Skipping scope definition." % scope_id)
			continue

		var nodes_in_scope: Array[String] = []
		var queue: Array = [start_node.id]
		var visited: Dictionary = { start_node.id: true }
		
		while not queue.is_empty():
			var current_node_id = queue.pop_front()
			
			# Check if we hit an EndScopeNode (boundary check)
			var node_def = node_definitions.get(current_node_id)
			var is_end_node = false
			if is_instance_valid(node_def) and node_def is EndScopeNodeResource and node_def.scope_id == scope_id:
				is_end_node = true # We do not include the EndScopeNode in the 'reset' list
			
			if not is_end_node:
				nodes_in_scope.append(current_node_id)

			# Traverse to neighbors
			var connections = node_connections.get(current_node_id, [])
			for connection in connections:
				var next_node_id = connection.get("to_node")
				
				# Stop traversal at EndScopeNode (boundary) or StartScopeNode (prevents infinite loop/false reset)
				var next_node_def = node_definitions.get(next_node_id)
				var is_scope_boundary = false
				if is_instance_valid(next_node_def):
					if (next_node_def is EndScopeNodeResource and next_node_def.scope_id == scope_id) or \
					   (next_node_def is StartScopeNodeResource and next_node_def.scope_id == scope_id):
						is_scope_boundary = true

				if not visited.has(next_node_id) and not is_scope_boundary:
					visited[next_node_id] = true
					queue.push_back(next_node_id)

		_scope_definitions[scope_id] = {
			"start_node_id": start_node.id,
			# Remove StartScopeNode itself from reset list
			"nodes_in_scope": nodes_in_scope.filter(func(id): return id != start_node.id)
		}

## 2. Start Scope Logic (Called by StartScopeNodeExecutor)

func handle_start_scope(node: StartScopeNodeResource) -> bool:
	var scope_id = node.scope_id
	if not _scope_runtime_state.has(scope_id):
		_scope_runtime_state[scope_id] = { "current_executions": 0 }
	
	var state = _scope_runtime_state[scope_id]
	var current_executions = state.current_executions
	var max_executions = node.max_executions
	
	var limit_reached = (max_executions > 0 and current_executions >= max_executions)
	
	if not limit_reached:
		state.current_executions += 1
		# Update the instance's variable that might be shown in the editor/debugger
		node.current_executions = state.current_executions
		return true
	
	return false

## 3. Reset Scope Logic (Called by ResetProgressNodeExecutor)

func handle_reset_scope(reset_node: ResetProgressNodeResource) -> Array[String]:
	var scope_id = reset_node.target_scope_id
	var definition = _scope_definitions.get(scope_id)
	
	if not definition:
		_controller._get_logger().warn("Executor", "ResetProgressNode: Could not find scope definition for '%s'." % scope_id)
		return []
	
	var nodes_to_reset = definition.nodes_in_scope.duplicate()
	
	# Add EndScopeNodes for cleanup too
	for node_def in _controller._node_definitions.values():
		if node_def is EndScopeNodeResource and node_def.scope_id == scope_id:
			nodes_to_reset.append(node_def.id)

	# Reset the status of all node definitions in scope
	for node_id in nodes_to_reset:
		var node_def = _controller._node_definitions.get(node_id)
		if is_instance_valid(node_def):
			node_def.status = GraphNodeResource.Status.INACTIVE
			if node_def is TaskNodeResource:
				for objective in node_def.objectives:
					objective.current_progress = 0
					objective.set_status(ObjectiveResource.Status.INACTIVE)
			
	# If restarting, reset the execution counter
	if reset_node.restart_scope_on_completion and _scope_runtime_state.has(scope_id):
		# This reset counter will be incremented again by the StartScopeNodeExecutor on next frame
		_scope_runtime_state[scope_id].current_executions = 0
	
	return nodes_to_reset

## 4. General API

func clear():
	_scope_runtime_state.clear()
	# Reset definition status too (in the controller's definitions cache)
	for scope_def in _scope_definitions.values():
		for node_id in scope_def.nodes_in_scope:
			var node_def = _controller._node_definitions.get(node_id)
			if is_instance_valid(node_def):
				node_def.status = GraphNodeResource.Status.INACTIVE

func get_save_data() -> Dictionary:
	return _scope_runtime_state.duplicate(true)

func load_save_data(data: Dictionary):
	_scope_runtime_state = data.duplicate(true)
	
	# Propagate loaded execution counts back to the node definitions for display/debugging
	for scope_id in _scope_runtime_state:
		var start_node_id = get_start_node_id_for_scope(scope_id)
		var start_node: StartScopeNodeResource = _controller._node_definitions.get(start_node_id)
		if is_instance_valid(start_node):
			start_node.current_executions = _scope_runtime_state[scope_id].current_executions

func get_start_node_id_for_scope(scope_id: String) -> String:
	var definition = _scope_definitions.get(scope_id)
	return definition.get("start_node_id", "") if definition else ""
