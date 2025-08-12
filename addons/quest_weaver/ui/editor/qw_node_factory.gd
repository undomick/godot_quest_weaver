@tool
class_name QWNodeFactory
extends Node

# This signal is still needed for the backdrop creation, as it involves
# reading the selection from the GraphController, which is better handled
# by the main editor.
signal create_backdrop_requested

# --- Dependencies ---
var _node_registry: NodeTypeRegistry
var _data_manager: QWGraphData
var _history: QWEditorHistory
var _graph_controller: QuestWeaverGraphController
var _add_node_menu: PopupMenu
var _editor: QuestWeaverEditor # Reference to the main editor to call select_and_inspect_node

# --- State ---
var _pending_node_creation_pos: Vector2
var _pending_connection_data: Dictionary
var _is_initialized := false


func initialize(p_editor: QuestWeaverEditor, p_registry: NodeTypeRegistry, p_data_manager: QWGraphData, p_history: QWEditorHistory, p_graph_controller: QuestWeaverGraphController, p_menu: PopupMenu) -> void:
	self._editor = p_editor
	self._node_registry = p_registry
	self._data_manager = p_data_manager
	self._history = p_history
	self._graph_controller = p_graph_controller
	self._add_node_menu = p_menu


func show_add_node_menu(position: Vector2, connect_from_data: Dictionary = {}) -> void:
	if not _is_initialized:
		_setup_add_node_menu()
		_is_initialized = true
	
	_pending_node_creation_pos = position
	_pending_connection_data = connect_from_data
	
	_add_node_menu.popup(Rect2i(get_viewport().get_mouse_position(), Vector2.ZERO))


func _setup_add_node_menu() -> void:
	_add_node_menu.clear()
	
	var category_resource: GraphNodeCategory = QWConstants.GRAPH_NODE_CATEGORY
	var icon_size = Vector2i(16, 16)
	
	var node_names = _node_registry.get_all_node_names()
	for i in range(node_names.size()):
		var type_name = node_names[i]
		var category_name = "Default"
		var node_script: Script = _node_registry.get_script_for_name(type_name)
		
		if is_instance_valid(node_script):
			var temp_instance: GraphNodeResource = node_script.new()
			if is_instance_valid(temp_instance):
				category_name = temp_instance.category
		
		var category_color: Color = category_resource.categories.get(category_name, Color.GRAY)
		var image = Image.create(icon_size.x, icon_size.y, false, Image.FORMAT_RGBA8)
		image.fill(category_color)
		var icon = ImageTexture.create_from_image(image)
		
		_add_node_menu.add_icon_item(icon, type_name, i)
		_add_node_menu.set_item_metadata(i, {"action": "create_node", "type_name": type_name})

	_add_node_menu.add_separator()
	var backdrop_index = _add_node_menu.get_item_count()
	_add_node_menu.add_item("Create Backdrop from Selection", backdrop_index)
	_add_node_menu.set_item_metadata(backdrop_index, {"action": "create_backdrop"})
	
	if not _add_node_menu.is_connected("id_pressed", _on_add_node_menu_id_pressed):
		_add_node_menu.id_pressed.connect(_on_add_node_menu_id_pressed)


func _on_add_node_menu_id_pressed(item_id: int) -> void:
	var metadata = _add_node_menu.get_item_metadata(item_id)
	if not metadata: return
	
	match metadata.get("action"):
		"create_node":
			# Use call_deferred to ensure the menu is closed and the editor state is stable
			# before proceeding with the complex node creation logic. This is critical.
			call_deferred("_create_new_node", metadata.get("type_name"))
		"create_backdrop":
			create_backdrop_requested.emit()


func _create_new_node(type_name: String) -> void:
	var editable_graph = _data_manager.make_active_graph_editable()
	if not is_instance_valid(editable_graph):
		return

	var node_script = _node_registry.get_script_for_name(type_name)
	if not is_instance_valid(node_script):
		return
		
	var new_node_data: GraphNodeResource = node_script.new()
	
	# This is the old, robust, and correct logic. ALWAYS assign a new, unique ID here.
	new_node_data.id = "%s_%d_%d" % [type_name.to_snake_case(), Time.get_unix_time_from_system(), randi() & 0xFFFF]
	new_node_data.graph_position = _pending_node_creation_pos
	
	# The factory is now responsible for creating and executing the command.
	var command = QWActionHandler.CreateNodeCommand.new(_editor, editable_graph, node_script, _pending_node_creation_pos, _pending_connection_data)
	_history.execute_command(command)
	
	# Clean up the state after the command has been created.
	_pending_connection_data.clear()
	
	# This is a visual aid, it's safe to clear it now.
	_graph_controller.set_is_connecting(false)
	
	await get_tree().process_frame
	# The factory calls the editor to perform the final selection.
	_editor.select_and_inspect_node(new_node_data.id)
