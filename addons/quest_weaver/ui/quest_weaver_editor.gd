# res://addons/quest_weaver/ui/quest_weaver_editor.gd
@tool
class_name QuestWeaverEditor
extends Control

signal validation_finished(results: Array)

@onready var graph_controller: QuestWeaverGraphController = %GraphEdit
@onready var properties_panel: Window = %PropertiesPanel
@onready var side_panel: VBoxContainer = %SidePanel
@onready var add_node_menu: PopupMenu = %AddNodeMenu
@onready var version_label: Label = %VersionLabel
@onready var data_manager: QWGraphData = %DataManager
@onready var localization_button: Button = %LocalizatonButton

var node_registry: NodeTypeRegistry
var editor_plugin_instance: QuestWeaverPlugin
var editor_session_data: QuestEditorData
var validator: QuestValidator
var _input_handler: QWInputHandler
var _history: QWEditorHistory
var _clipboard: QWClipboard
var _action_handler: QWActionHandler
var _node_factory: QWNodeFactory
var _editor_interface: EditorInterface

# State variables for node creation context
var _pending_node_creation_pos: Vector2
var _pending_connection_data: Dictionary

# State variables for live debugging
var _live_debugging_active := false
var _live_node_id: String = ""
var _completed_node_ids: Dictionary = {}
var _live_stylebox: StyleBoxFlat
var _completed_stylebox: StyleBoxFlat
var _live_pulse_tween: Tween


func initialize(plugin: QuestWeaverPlugin, p_session_data: QuestEditorData, p_editor_interface: EditorInterface) -> void:
	self.editor_plugin_instance = plugin
	self.editor_session_data = p_session_data
	self._editor_interface = p_editor_interface
	
	node_registry = ResourceLoader.load(QWConstants.Settings.node_type_registry_path)
	if is_instance_valid(node_registry): node_registry.validate_registry()
	
	_history = QWEditorHistory.new()
	_clipboard = QWClipboard.new()
	validator = QuestValidator.new()
	_action_handler = QWActionHandler.new(); _action_handler.name = "ActionHandler"; add_child(_action_handler)
	_node_factory = QWNodeFactory.new(); _node_factory.name = "NodeFactory"; add_child(_node_factory)
	_input_handler = QWInputHandler.new(); _input_handler.name = "InputHandler"; add_child(_input_handler)
	
	_history.initialize(self)
	_clipboard.initialize(node_registry)
	_action_handler.initialize(self, _history, data_manager, properties_panel, graph_controller, _clipboard)
	_node_factory.initialize(self, node_registry, data_manager, _history, graph_controller, add_node_menu)
	_input_handler.initialize(self, _history, _action_handler, graph_controller, _editor_interface)
	properties_panel.initialize(node_registry, data_manager, editor_plugin_instance)
	graph_controller.initialize(node_registry, data_manager, 1.0)
	side_panel.initialize(data_manager)
	
	version_label.text = "v%s" % editor_plugin_instance.get_version()
	_connect_signals()
	_history.version_changed.connect(_on_history_changed)
	_load_session_data()


func _connect_signals() -> void:
	properties_panel.property_update_requested.connect(_action_handler.on_node_property_update_requested)
	properties_panel.complex_action_requested.connect(_action_handler.on_complex_action_requested)
	properties_panel.dive_in_requested.connect(edit_graph)
	properties_panel.node_ports_changed.connect(_on_node_ports_changed)
	
	side_panel.create_new_file_at_path.connect(_on_create_new_file_at_path)
	side_panel.open_file_requested.connect(edit_graph)
	side_panel.bookmark_selected.connect(_on_bookmark_selected)
	side_panel.close_bookmark_requested.connect(_on_close_bookmark_requested)
	side_panel.save_active_graph_requested.connect(data_manager.save_active_graph)
	side_panel.save_single_file_requested.connect(save_single_file)
	side_panel.save_all_files_requested.connect(_action_handler.save_all_modified_graphs)

	graph_controller.begin_node_move.connect(_action_handler.on_begin_node_move)
	graph_controller.end_node_move.connect(_action_handler.on_end_node_move)
	graph_controller.node_selection_requested.connect(select_and_inspect_node)
	graph_controller.selection_finished.connect(_on_selection_finished_and_popup)
	graph_controller.deletion_requested.connect(_action_handler.on_nodes_deleted)
	graph_controller.connection_to_empty.connect(_on_connection_to_empty)
	graph_controller.connection_request_forwarded.connect(_action_handler.on_connection_request)
	graph_controller.disconnection_request_forwarded.connect(_action_handler.on_disconnection_request)
	graph_controller.view_changed.connect(_on_graph_view_changed)
	graph_controller.gui_input.connect(_on_graph_editor_gui_input)
	
	data_manager.active_graph_changed.connect(_on_active_graph_changed)
	data_manager.graph_dirty_status_changed.connect(side_panel.mark_file_as_unsaved)
	data_manager.graph_was_saved.connect(_on_graph_was_saved)
	
	localization_button.pressed.connect(_on_scan_keys_pressed)
	
	_action_handler.node_data_changed.connect(_on_node_data_changed)
	_node_factory.create_backdrop_requested.connect(_create_backdrop_from_selection)


func _input(event: InputEvent) -> void:
	if not visible: return
	if _input_handler.handle_event(event):
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if not graph_controller.get_global_rect().has_point(get_global_mouse_position()):
			clear_graph_selection()
			if properties_panel.visible:
				properties_panel.call_deferred("hide")


func get_history() -> QWEditorHistory: return _history


func get_action_handler() -> QWActionHandler: return _action_handler


func set_editor_scale(scale: float) -> void:
	if is_instance_valid(graph_controller):
		graph_controller.editor_scale = scale


func cancel_any_active_drags() -> void:
	if is_instance_valid(_action_handler) and _action_handler.has_method("on_end_node_move"):
		_action_handler.on_end_node_move()


func edit_graph(path: String) -> void:
	side_panel.add_file_to_open_list(path)
	data_manager.set_active_graph(path)


func select_and_inspect_node(node_id: String) -> void:
	var current_graph = data_manager.get_active_graph()
	if not is_instance_valid(current_graph):
		return
	
	var node_data = current_graph.nodes.get(node_id)
	if is_instance_valid(node_data):
		properties_panel.inspect_node(node_data)


func clear_graph_selection() -> void:
	if not is_instance_valid(graph_controller):
		return
	for node in graph_controller.get_children():
		if node is GraphElement and node.selected:
			node.selected = false


func save_single_file(path: String) -> void:
	# The logic for the currently active graph remains the same.
	if path == data_manager.get_active_graph_path():
		data_manager.save_active_graph()
	else:
		# For background files, call our new, non-visual save function.
		data_manager.save_graph(path)


func validate_open_files_exist() -> void:
	if not is_instance_valid(side_panel): return
	
	var files_to_close: Array[String] = []
	var open_files = side_panel.get_open_files()
	
	for path in open_files:
		if not FileAccess.file_exists(path):
			files_to_close.append(path)
			
	if not files_to_close.is_empty():
		for path_to_close in files_to_close:
			_handle_bookmark_closure(path_to_close)


func _on_history_changed() -> void:
	var current_graph = data_manager.get_active_graph()
	if not is_instance_valid(current_graph):
		return
	
	graph_controller.refresh_from_data(current_graph)
	
	if properties_panel.is_visible():
		properties_panel.call_deferred("refresh_inspected_node")


func _on_selection_finished_and_popup(node_id: String) -> void:
	# First, we ensure the properties are up-to-date with the selected node.
	select_and_inspect_node(node_id)
	
	# NOW, after the selection action is complete, it is safe to open the window.
	properties_panel.popup()


func _on_graph_editor_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		# This now correctly holds the position data in the factory
		_node_factory.show_add_node_menu(graph_controller.scroll_offset + (graph_controller.get_local_mouse_position() / graph_controller.zoom))
		get_viewport().set_input_as_handled()


func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	# This also now correctly calls the factory
	var connect_data = {"from_node": from_node, "from_port": from_port}
	_node_factory.show_add_node_menu(release_position, connect_data)


func _on_node_type_selected_from_menu(type_name: String) -> void:
	call_deferred("_on_node_type_selected_for_creation", type_name)


func _on_node_ports_changed(node_id: String) -> void:
	var current_graph = data_manager.get_active_graph()
	if is_instance_valid(current_graph):
		graph_controller.update_node_ports(current_graph, node_id)


func _create_backdrop_from_selection() -> void:
	var editable_graph = data_manager.make_active_graph_editable()
	if not is_instance_valid(editable_graph): return
	
	var selected_visual_nodes: Array[GraphElement] = []
	for node in graph_controller.get_children():
		if node is GraphElement and node.selected:
			selected_visual_nodes.append(node)
	
	if selected_visual_nodes.is_empty(): return
	
	var command = CreateBackdropCommand.new(editable_graph, selected_visual_nodes)
	_history.execute_command(command)


func _on_active_graph_changed(new_graph_resource: QuestGraphResource) -> void:
	graph_controller.display_graph(new_graph_resource)
	side_panel.update_selection(data_manager.get_active_graph_path())
	properties_panel.call_deferred("hide")


func _on_create_new_file_at_path(path: String):
	var new_res = QuestGraphResource.new()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Could not create new quest file at '%s'." % path)
		return
	file.store_var(new_res.to_dictionary(), true)
	file.close()
	
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().create_timer(0.1).timeout
	edit_graph(path)


func _on_bookmark_selected(path: String) -> void:
	data_manager.set_active_graph(path)


func _on_close_bookmark_requested(path: String) -> void:
	if data_manager.has_unsaved_changes(path):
		var dialog = QWConstants.QuestConfirmationDialogScene.instantiate()
		get_tree().root.add_child(dialog)
		dialog.save_requested.connect(
			func():
				save_single_file(path)
				_handle_bookmark_closure(path)
		)
		dialog.discard_requested.connect(
			func():
				data_manager.discard_changes(path)
				_handle_bookmark_closure(path)
		)
		dialog.prompt("Unsaved Changes", "Graph '%s' has unsaved changes. Save before closing?" % path.get_file())
	else:
		_handle_bookmark_closure(path)


func _handle_bookmark_closure(closed_path: String) -> void:
	var was_active = (data_manager.get_active_graph_path() == closed_path)
	data_manager.close_graph(closed_path)
	side_panel.remove_file_from_open_list(closed_path)

	if was_active:
		var remaining_files = side_panel.get_open_files()
		if not remaining_files.is_empty():
			edit_graph(remaining_files[0])
		else:
			data_manager.set_active_graph("")


func _on_graph_view_changed(scroll_offset: Vector2, zoom: float):
	data_manager.update_view_state(data_manager.get_active_graph_path(), scroll_offset, zoom)


func _on_graph_was_saved(_path: String):
	call_deferred("_update_quest_registry")
	QWEditorUtils.clear_cache()


func _load_session_data() -> void:
	if not is_instance_valid(editor_session_data) or not is_instance_valid(side_panel):
		return

	for path in editor_session_data.open_files:
		if FileAccess.file_exists(path):
			side_panel.add_file_to_open_list(path)
	
	var last_file = editor_session_data.last_focused_file
	if FileAccess.file_exists(last_file):
		edit_graph(last_file)
	elif not editor_session_data.open_files.is_empty():
		for path in editor_session_data.open_files:
			if FileAccess.file_exists(path):
				edit_graph(path)
				break


func _update_quest_registry() -> void:
	if QWConstants.Settings.quest_registry_path.is_empty() or QWConstants.Settings.quest_scan_folder.is_empty():
		return
	
	var registry: QuestRegistry = ResourceLoader.load(QWConstants.Settings.quest_registry_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not is_instance_valid(registry):
		return
	
	QuestRegistrar.update_registry_from_project(registry, QWConstants.Settings.quest_scan_folder)


func _on_scan_keys_pressed():
	LocalizationKeyScanner.update_localization_file(
		QWConstants.Settings.quest_scan_folder,
		QWConstants.Settings.localization_csv_path
	)
	EditorInterface.get_resource_filesystem().scan()


func add_visual_node(node_data: GraphNodeResource) -> void:
	if is_instance_valid(graph_controller):
		graph_controller.create_single_visual_node(node_data)


func remove_visual_node(node_id: String) -> void:
	if is_instance_valid(graph_controller):
		var node_to_remove = graph_controller.get_node_or_null(NodePath(node_id))
		if is_instance_valid(node_to_remove):
			node_to_remove.queue_free()


func add_visual_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if is_instance_valid(graph_controller):
		graph_controller.add_visual_connection(from_node, from_port, to_node, to_port)


func remove_visual_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if is_instance_valid(graph_controller):
		graph_controller.remove_visual_connection(from_node, from_port, to_node, to_port)


# This function is called whenever the ActionHandler confirms that node data has changed.
func _on_node_data_changed(node_id: String, action: String) -> void:
	#var structural_change_actions = [
		#"add_parallel_output", "remove_parallel_output", "add_random_output",
		#"remove_random_output", "add_sync_input", "remove_sync_input",
		#"add_sync_output", "remove_sync_output"
	#]
	var structural_change_actions = ["add_parallel_output","remove_parallel_output", "add_random_output",
	"remove_random_output", "add_sync_input", "remove_sync_input", "add_sync_output", "remove_sync_output"]
	
	var partial_refresh_actions = []
	
	var current_graph = data_manager.get_active_graph()
	
	if action in structural_change_actions:
		var old_scroll = graph_controller.scroll_offset; var old_zoom = graph_controller.zoom
		graph_controller.display_graph(current_graph)
	elif action in partial_refresh_actions:
		graph_controller.update_node_structure_and_connections(node_id)
	else:
		graph_controller.refresh_single_node_visuals(node_id)
	
	if properties_panel.visible and properties_panel.get_inspected_node_id() == node_id:
		properties_panel.call_deferred("refresh_inspected_node")


func _on_validation_requested() -> void:
	var current_graph = data_manager.get_active_graph()
	if not is_instance_valid(current_graph):
		validation_finished.emit([])
		return
	
	var results: Array[ValidationResult] = validator.validate_graph(current_graph)
	validation_finished.emit(results)


func _on_validation_result_selected(node_id: String) -> void:
	if node_id.is_empty():
		return
		
	clear_graph_selection()
	
	var node_to_select = graph_controller.get_node_or_null(NodePath(node_id))
	if is_instance_valid(node_to_select):
		node_to_select.selected = true
		var node_pos = node_to_select.position_offset
		var view_size = graph_controller.size
		var current_zoom = graph_controller.zoom if graph_controller.zoom > 0 else 1.0
		graph_controller.scroll_offset = node_pos - (view_size / (2.0 * current_zoom))


func _on_debug_session_started():
	_live_debugging_active = true
	_clear_all_highlights()
	_completed_node_ids.clear()
	_live_node_id = ""


func _on_debug_session_ended():
	_live_debugging_active = false
	_clear_all_highlights()
	if is_instance_valid(_live_pulse_tween):
		_live_pulse_tween.kill()


func _on_debug_node_activated(node_id: String):
	if not _live_debugging_active: return
	if _completed_node_ids.has(_live_node_id):
		_update_node_style(_live_node_id, _completed_stylebox)
	else:
		_update_node_style(_live_node_id, null)
	if is_instance_valid(_live_pulse_tween):
		_live_pulse_tween.kill()
	_live_node_id = node_id
	_update_node_style(_live_node_id, _live_stylebox)
	_pulse_live_node(node_id)


func _on_debug_node_completed(node_id: String):
	if not _live_debugging_active: return
	if node_id == _live_node_id:
		_live_node_id = ""
		if is_instance_valid(_live_pulse_tween):
			_live_pulse_tween.kill()
	_completed_node_ids[node_id] = true
	_update_node_style(node_id, _completed_stylebox)


func _update_node_style(node_id: String, style: StyleBox):
	if node_id.is_empty(): return
	var visual_node = graph_controller.get_node_or_null(NodePath(node_id))
	if is_instance_valid(visual_node) and visual_node is GraphNode:
		visual_node.set("theme_override_styles/panel", style)


func _clear_all_highlights():
	if is_instance_valid(graph_controller) and graph_controller.is_visible_in_tree():
		for child in graph_controller.get_children():
			if child is GraphNode:
				child.set("theme_override_styles/panel", null)


func _pulse_live_node(node_id: String):
	var visual_node = graph_controller.get_node_or_null(NodePath(node_id))
	if not is_instance_valid(visual_node): return
	var new_stylebox: StyleBoxFlat = _live_stylebox.duplicate(true)
	visual_node.set("theme_override_styles/panel", new_stylebox)
	_live_pulse_tween = create_tween().set_loops()
	_live_pulse_tween.tween_property(new_stylebox, "bg_color", _live_stylebox.bg_color.lightened(0.2), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_live_pulse_tween.tween_property(new_stylebox, "bg_color", _live_stylebox.bg_color, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
