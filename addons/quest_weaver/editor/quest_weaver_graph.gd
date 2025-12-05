# res://addons/quest_weaver/editor/quest_weaver_graph.gd
@tool
class_name QuestWeaverGraphController
extends GraphEdit

## SIGNALS ##
signal selection_finished(node_id: String)
signal node_selection_requested(node_id: String)
signal deletion_requested(node_ids: Array[StringName])
signal connection_to_empty_requested(from_node: StringName, from_port: int, release_position: Vector2)
signal node_moved(node_id: String, new_position: Vector2)
signal connection_request_forwarded(from_node: StringName, from_port: int, to_node: StringName, to_port: int)
signal disconnection_request_forwarded(from_node: StringName, from_port: int, to_node: StringName, to_port: int)
signal view_changed(scroll_offset: Vector2, zoom: float)

## REFERENCES & STATE ##
var node_registry: NodeTypeRegistry
var data_manager: QWGraphData
var editor_scale: float = 1.0
var is_connecting := false
var _connection_start_data: Dictionary
var _is_rebuilding_graph := false
var _nodes_to_be_ready: int = 0
var _graph_resource_for_connection: QuestGraphResource = null

## INITIALIZATION ##

func _ready():
	node_selected.connect(_on_view_node_selected)
	delete_nodes_request.connect(_on_view_nodes_deleted)
	connection_to_empty.connect(_on_view_connection_to_empty)
	connection_request.connect(connection_request_forwarded.emit)
	disconnection_request.connect(disconnection_request_forwarded.emit)
	scroll_offset_changed.connect(func(_offset): _emit_view_changed_signal())

func initialize(p_node_registry: NodeTypeRegistry, p_data_manager: QWGraphData, p_editor_scale: float):
	self.node_registry = p_node_registry
	self.data_manager = p_data_manager
	self.editor_scale = p_editor_scale

## PUBLIC API ##

func display_graph(graph_resource: QuestGraphResource):
	await _rebuild_visual_graph(graph_resource)
	if is_instance_valid(graph_resource):
		call_deferred("set_scroll_offset", graph_resource.editor_scroll_offset)
		call_deferred("set_zoom", graph_resource.editor_zoom)

func update_node_ports(graph_resource: QuestGraphResource, node_id: String):
	if _is_rebuilding_graph: return
	if not is_instance_valid(graph_resource): return
	
	var visual_node: GraphElement = get_node_or_null(node_id)
	var node_data = graph_resource.nodes.get(node_id)
	
	if not (is_instance_valid(visual_node) and is_instance_valid(node_data)):
		return
	
	# Update internals (Slots/Ports)
	if visual_node is GraphNode:
		var connections_list = get_connection_list()
		for conn in connections_list:
			if conn.from_node == node_id or conn.to_node == node_id:
				disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
		
		_build_node_internal_structure(visual_node, node_data)
		
		if visual_node is QWGraphNode:
			visual_node.summary_text = node_data.get_editor_summary()
			visual_node.queue_redraw()
	
	_enforce_node_size(visual_node, node_data)
	
	# Force a rebuild of connections with a delay.
	await get_tree().process_frame 
	
	_rebuild_visual_connections_only(graph_resource)

func update_visual_node_position(graph_resource: QuestGraphResource, node_id: String):
	if not is_instance_valid(graph_resource): return

	var visual_node = get_node_or_null(node_id)
	var node_data = graph_resource.nodes.get(node_id)
	
	if is_instance_valid(visual_node) and is_instance_valid(node_data):
		visual_node.position_offset = node_data.graph_position

func update_summary_text(graph_resource: QuestGraphResource, node_id: String):
	if _is_rebuilding_graph: return
	
	var visual_node: QWGraphNode = get_node_or_null(node_id)
	var node_data = graph_resource.nodes.get(node_id)
	
	if is_instance_valid(visual_node) and is_instance_valid(node_data):
		visual_node.summary_text = node_data.get_editor_summary()
		visual_node.queue_redraw()

func redraw_node_structure(graph_resource: QuestGraphResource, node_id: String):
	if _is_rebuilding_graph: return
	
	var visual_node: GraphNode = get_node_or_null(node_id)
	var node_data = graph_resource.nodes.get(node_id)
	
	if is_instance_valid(visual_node) and is_instance_valid(node_data):
		_build_node_internal_structure(visual_node, node_data)
		if visual_node is QWGraphNode:
			visual_node.summary_text = node_data.get_editor_summary()
			visual_node.queue_redraw()
		_enforce_node_size(visual_node, node_data)
		call_deferred("_rebuild_visual_connections_only", graph_resource)

func create_single_visual_node(node_data: GraphNodeResource):
	var node_id = String(node_data.id)
	if not has_node(NodePath(node_id)):
		_create_visual_node(node_data)

func rebuild_connections(graph_resource: QuestGraphResource):
	call_deferred("_rebuild_visual_connections_only", graph_resource)

func set_is_connecting(p_is_connecting: bool, from_node: StringName = "", from_port: int = -1):
	self.is_connecting = p_is_connecting
	if is_connecting:
		_connection_start_data = {"from_node": from_node, "from_port": from_port}
	else:
		_connection_start_data.clear()

func get_connection_start_data() -> Dictionary:
	return _connection_start_data

func add_visual_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if is_instance_valid(get_node_or_null(NodePath(from_node))) and is_instance_valid(get_node_or_null(NodePath(to_node))):
		connect_node(from_node, from_port, to_node, to_port)

func remove_visual_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if is_instance_valid(get_node_or_null(NodePath(from_node))) and is_instance_valid(get_node_or_null(NodePath(to_node))):
		disconnect_node(from_node, from_port, to_node, to_port)

# This avoids the complex callable/lambda issue with UndoRedo.
func select_visual_node(node_id: String) -> void:
	var node = get_node_or_null(node_id)
	if node is GraphElement:
		node.selected = true
	# We also deselect all other nodes to ensure only the pasted ones are selected.
	for child in get_children():
		if child is GraphElement and child.name != node_id:
			child.selected = false

func refresh_from_data(graph_resource: QuestGraphResource):
	if not is_instance_valid(graph_resource):
		display_graph(null) # Clear if the resource is invalid
		return

	_synchronize_visual_graph(graph_resource)

func refresh_single_node_visuals(node_id: String) -> void:
	var current_graph = data_manager.get_active_graph()
	if not is_instance_valid(current_graph): return

	var node_data = current_graph.nodes.get(node_id)
	var visual_node = get_node_or_null(node_id)
	
	if not (is_instance_valid(node_data) and is_instance_valid(visual_node)): return

	if node_data.has_method("_update_ports_from_data"):
		node_data._update_ports_from_data()

	# --- Logic for Backdrops (GraphFrame) ---
	if visual_node is GraphFrame and node_data is BackdropNodeResource:
		var style_copy: StyleBoxFlat = visual_node.get_theme_stylebox("panel").duplicate(true)
		style_copy.bg_color = node_data.color
		visual_node.add_theme_stylebox_override("panel", style_copy)
		visual_node.add_theme_stylebox_override("panel_selected", style_copy)
		visual_node.add_theme_font_size_override("title_font_size", node_data.title_font_size)
		visual_node.title = node_data.title
		visual_node.update_minimum_size()
	
	# --- Logic for all other nodes (GraphNode and its children) ---
	elif visual_node is GraphNode:
		visual_node.theme_type_variation = node_data.category
		visual_node.title = node_registry.get_name_for_script(node_data.get_script())
		
		if visual_node is QWGraphNode:
			visual_node.summary_text = node_data.get_editor_summary()
			visual_node.queue_redraw()

		_build_node_internal_structure(visual_node, node_data)
		_enforce_node_size(visual_node, node_data)

func clear_visual_connections_from_port(node_id: String, port_index: int):
	# Get a list of all connections currently managed by the GraphEdit.
	var connection_list = get_connection_list()
	
	for connection in connection_list:
		# Check if the connection originates from the port we are about to delete.
		if connection.from == node_id and connection.from_port == port_index:
			# If so, remove it visually using the GraphEdit's own method.
			disconnect_node(connection.from, connection.from_port, connection.to, connection.to_port)

func update_node_structure_and_connections(node_id: String) -> void:
	if _is_rebuilding_graph: return

	var current_graph = data_manager.get_active_graph()
	if not is_instance_valid(current_graph): return

	var node_data = current_graph.nodes.get(node_id)
	var visual_node = get_node_or_null(node_id)
	
	if not (is_instance_valid(node_data) and is_instance_valid(visual_node) and visual_node is GraphNode):
		return

	_build_node_internal_structure(visual_node, node_data)
	if visual_node is QWGraphNode:
		visual_node.summary_text = node_data.get_editor_summary()
		visual_node.queue_redraw()
	_enforce_node_size(visual_node, node_data)

	call_deferred("_rebuild_visual_connections_only", current_graph)


## PRIVATE DRAWING LOGIC ##

func _synchronize_visual_graph(graph_resource: QuestGraphResource) -> void:
	for node_id in graph_resource.nodes:
		var visual_node = get_node_or_null(node_id)
		
		if is_instance_valid(visual_node):
			refresh_single_node_visuals(node_id)
		else:
			# If the node doesn't exist visually, create it.
			create_single_visual_node(graph_resource.nodes[node_id])
		
	var visual_nodes_to_remove: Array[Node] = []
	for child in get_children():
		if child is GraphElement and not graph_resource.nodes.has(child.name):
			visual_nodes_to_remove.append(child)
	for node_to_remove in visual_nodes_to_remove:
		node_to_remove.queue_free()
	
	call_deferred("rebuild_connections", graph_resource)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
	   (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and \
	   event.is_command_or_control_pressed():
		
		call_deferred("_emit_view_changed_signal")
	
	# Detect when the user finishes a click or a box selection.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		call_deferred("_emit_selection_finished")

func _emit_view_changed_signal():
	if is_instance_valid(self):
		view_changed.emit(scroll_offset, zoom)

func _build_node_internal_structure(visual_node: GraphNode, node_data: GraphNodeResource):
	for child in visual_node.get_children():
		if child is Container:
			visual_node.remove_child(child)
			child.queue_free()
	visual_node.clear_all_slots()

	var input_count = node_data.input_ports.size()
	var output_count = node_data.output_ports.size()
	var port_row_count = max(input_count, output_count)

	for i in range(port_row_count):
		var is_input_enabled = i < input_count and not node_data.input_ports[i].is_empty()
		var is_output_enabled = i < output_count and node_data.output_ports[i] != " "

		visual_node.set_slot(
			i,
			is_input_enabled, 0, Color.WHITE if is_input_enabled else Color.GRAY.darkened(0.4),
			is_output_enabled, 0, Color.WHITE if is_output_enabled else Color.GRAY.darkened(0.4)
		)

		var row_container = HBoxContainer.new()
		
		row_container.custom_minimum_size.y = 24
		
		visual_node.add_child(row_container)
		
		var input_label = Label.new()
		if i < input_count:
			input_label.text = node_data.input_ports[i]
			input_label.modulate.a = 1.0 if is_input_enabled else 0.4
		row_container.add_child(input_label)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		if node_data is RandomNodeResource or node_data is ParallelNodeResource:
			row_container.show_behind_parent = false
		else: row_container.show_behind_parent = true
		
		row_container.add_child(spacer)
		
		var output_label = Label.new()
		if i < output_count:
			output_label.text = node_data.output_ports[i]
			output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			output_label.modulate.a = 1.0 if is_output_enabled else 0.4
		row_container.add_child(output_label)

func _rebuild_visual_graph(graph_resource: QuestGraphResource):
	_is_rebuilding_graph = true
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			child.queue_free()
	
	_graph_resource_for_connection = null
	_nodes_to_be_ready = 0
	
	if not is_instance_valid(graph_resource) or graph_resource.nodes.is_empty():
		_is_rebuilding_graph = false
		return
		
	await get_tree().process_frame
	_nodes_to_be_ready = graph_resource.nodes.size()
	_graph_resource_for_connection = graph_resource
	
	for node_id in graph_resource.nodes:
		var node_data: GraphNodeResource = graph_resource.nodes[node_id]
		_create_visual_node(node_data, true)

func _create_visual_node(node_data: GraphNodeResource, is_part_of_full_rebuild: bool = false) -> GraphElement:
	if not is_instance_valid(node_registry):
		push_warning("GraphController: Node Registry not initialized, cannot create visual node.")
		return null
	
	var visual_node: GraphElement

	# Node creation logic
	if node_data is BackdropNodeResource:
		var frame = GraphFrame.new()
		frame.mouse_filter = Control.MOUSE_FILTER_PASS
		frame.resizable = true
		frame.size = node_data.node_size
		frame.resize_request.connect(func(new_size: Vector2):
			frame.size = new_size
			node_data.node_size = new_size # Update data live for snappier feel
		)
		frame.resize_end.connect(func(new_size: Vector2):
			frame.size = new_size
			node_data.node_size = new_size
		)
		
		visual_node = frame
		
	elif node_data is CommentNodeResource:
		var g_node = QWGraphNode.new() 
		g_node.resizable = true
		g_node.custom_minimum_size = Vector2(150, 100)
		g_node.size = node_data.node_size
		g_node.summary_text = node_data.get_editor_summary()
		g_node.resize_end.connect(func(new_size: Vector2):
			node_data.node_size = new_size
		)
		
		visual_node = g_node
	
	else:
		var g_node = QWGraphNode.new()
		g_node.resizable = false
		g_node.summary_text = node_data.get_editor_summary()
		visual_node = g_node

	# Simplified common logic
	visual_node.name = node_data.id
	if is_part_of_full_rebuild:
		visual_node.ready.connect(_on_visual_node_ready, CONNECT_ONE_SHOT)
	visual_node.position_offset = node_data.graph_position
	visual_node.position_offset_changed.connect(_on_view_node_moved.bind(visual_node.name))
	
	add_child(visual_node)
	
	_apply_node_decorations(visual_node, node_data)
	
	_enforce_node_size(visual_node, node_data)
	return visual_node

func _on_visual_node_ready():
	_nodes_to_be_ready -= 1
	if _nodes_to_be_ready <= 0:
		if is_instance_valid(_graph_resource_for_connection):
			_rebuild_visual_connections_only(_graph_resource_for_connection)
			_graph_resource_for_connection = null
		_is_rebuilding_graph = false

func _rebuild_visual_connections_only(graph_resource: QuestGraphResource):
	if not is_instance_valid(graph_resource): return
	
	clear_connections()
	
	for connection in graph_resource.connections:
		if connection.has_all(["from_node", "from_port", "to_node", "to_port"]):
			var from_node_path = NodePath(connection.from_node)
			var to_node_path = NodePath(connection.to_node)
			
			# Check if both nodes exist visually
			if has_node(from_node_path) and has_node(to_node_path):
				# Connect checks for errors internally, so we can just call it
				connect_node(connection.from_node, connection.from_port, connection.to_node, connection.to_port)

func _apply_node_decorations(visual_node: GraphElement, node_data: GraphNodeResource) -> void:
	if not is_instance_valid(visual_node) or not is_instance_valid(node_data):
		return
	
	var category_resource = QWConstants.GRAPH_NODE_CATEGORY
	var category_color: Color = Color.DARK_GRAY
	
	if category_resource and category_resource.categories.has(node_data.category):
		category_color = category_resource.categories[node_data.category]
	
	if visual_node is GraphFrame and node_data is BackdropNodeResource:
		var style_copy: StyleBoxFlat = visual_node.get_theme_stylebox("panel").duplicate(true)
		style_copy.bg_color = node_data.color
	
		visual_node.add_theme_stylebox_override("panel", style_copy)
		visual_node.add_theme_stylebox_override("panel_selected", style_copy)
		visual_node.add_theme_font_size_override("title_font_size", node_data.title_font_size)
		visual_node.title = node_data.title
		visual_node.resizable = true
		
		var resizer_icon = get_theme_icon("resizer", "GraphNode")
		visual_node.add_theme_icon_override("resizer", resizer_icon)
		return

	if visual_node is GraphNode:
		visual_node.title = node_registry.get_name_for_script(node_data.get_script())
		
		var base_style = visual_node.get_theme_stylebox("titlebar", "GraphNode")
		var title_style: StyleBoxFlat

		if base_style is StyleBoxFlat:
			title_style = base_style.duplicate()
		else:
			title_style = StyleBoxFlat.new()
			title_style.corner_radius_top_left = 3
			title_style.corner_radius_top_right = 3
			title_style.content_margin_left = 12
			title_style.content_margin_right = 12
			title_style.content_margin_top = 4
			title_style.content_margin_bottom = 4
		
		title_style.bg_color = category_color
		visual_node.add_theme_stylebox_override("titlebar", title_style)
		
		var title_style_selected = title_style.duplicate()
		title_style_selected.bg_color = category_color.lightened(0.2)
		visual_node.add_theme_stylebox_override("titlebar_selected", title_style_selected)
		
		# --- B: ICON (Header) ---
		var icon_texture = node_data.get_icon()
		var titlebar_hbox = visual_node.get_titlebar_hbox()
		
		if is_instance_valid(titlebar_hbox):
			var existing_icon = titlebar_hbox.get_node_or_null("QWHeaderIcon")
			if existing_icon: existing_icon.queue_free()
			
			if icon_texture:
				var icon_rect = TextureRect.new()
				icon_rect.name = "QWHeaderIcon"
				icon_rect.texture = icon_texture
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.custom_minimum_size = Vector2(24, 24)
				
				titlebar_hbox.add_child(icon_rect)
				titlebar_hbox.move_child(icon_rect, 0)

		_build_node_internal_structure(visual_node, node_data)

func _enforce_node_size(visual_node: GraphElement, node_data: GraphNodeResource):
	if node_data is CommentNodeResource or node_data is BackdropNodeResource:
		return

	var type_info: NodeTypeInfo = node_registry.get_info_for_script(node_data.get_script())
	if is_instance_valid(type_info):
		var size_enum = type_info.default_size
		var standard_size = QWNodeSizes.get_vector_for_size(size_enum)
		
		visual_node.custom_minimum_size = standard_size
		visual_node.set_size(standard_size)
		
		visual_node.update_minimum_size()

## INTERNAL SIGNAL HANDLERS ##

func _on_view_node_moved(node_id: StringName):
	var node_path = NodePath(node_id)
	if not has_node(node_path): return
	var visual_node: GraphElement = get_node(node_path)
	node_moved.emit(String(node_id), visual_node.position_offset)

func _on_view_node_selected(p_visual_node: Node):
	if p_visual_node is GraphElement:
		node_selection_requested.emit(p_visual_node.name)

func _on_view_nodes_deleted(nodes: Array[StringName]):
	var all_nodes_to_delete: Array[StringName] = nodes

	for child in get_children():
		if child is GraphFrame and child.selected:
			if not all_nodes_to_delete.has(child.name):
				all_nodes_to_delete.append(child.name)

	if not all_nodes_to_delete.is_empty():
		deletion_requested.emit(all_nodes_to_delete)

func _on_view_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2):
	connection_to_empty_requested.emit(from_node, from_port, release_position)

func _emit_selection_finished() -> void:
	var selected_nodes: Array[GraphElement] = []
	for child in get_children():
		# Ensure we only check nodes that can be selected.
		if child is GraphElement and child.selected:
			selected_nodes.append(child)
	
	if selected_nodes.size() == 1:
		var single_node: GraphElement = selected_nodes[0]
		if is_instance_valid(single_node):
			selection_finished.emit(single_node.name)
