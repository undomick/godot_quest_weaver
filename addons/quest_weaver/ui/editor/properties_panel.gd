# res://addons/quest_weaver/ui/properties_panel.gd
@tool
extends Window

signal property_update_requested(node_id: String, property_name: String, new_value: Variant, sub_resource: Resource)
signal complex_action_requested(node_id: String, action: String, payload: Dictionary)
signal dive_in_requested(graph_path: String)
signal node_ports_changed(node_id: String)

# --- UI References ---
@onready var node_type_label: Label = %NodeTypeLabel
@onready var editor_host: VBoxContainer = %PropertyFieldsContainer

# --- Dependencies & State ---
var node_registry: NodeTypeRegistry
var data_manager: QWGraphData
var editor_plugin: EditorPlugin
var current_editor_instance: Node
var _inspected_node_data: GraphNodeResource

const SETTING_SIZE = "properties_panel_size"
const SETTING_POSITION = "properties_panel_position"


func _ready() -> void:
	about_to_popup.connect(_on_about_to_popup)
	close_requested.connect(_on_close_requested)
	hide()

func initialize(p_node_registry: NodeTypeRegistry, p_data_manager: QWGraphData, p_editor_plugin: EditorPlugin) -> void:
	self.node_registry = p_node_registry
	self.data_manager = p_data_manager
	self.editor_plugin = p_editor_plugin

func inspect_node(node_data: GraphNodeResource) -> void:
	if not is_instance_valid(node_registry):
		push_error("PropertiesPanel: Node Registry isn't initialized.")
		return
	
	self._inspected_node_data = node_data

	if is_instance_valid(current_editor_instance):
		current_editor_instance.queue_free()
		current_editor_instance = null
	for child in editor_host.get_children():
		child.queue_free()

	var node_script = node_data.get_script()
	node_type_label.text = node_registry.get_name_for_script(node_script)
	
	var editor_path = node_registry.get_editor_path_for_script(node_script)
	
	if not editor_path.is_empty() and ResourceLoader.exists(editor_path):
		var editor_scene = load(editor_path)
		current_editor_instance = editor_scene.instantiate()
		
		if current_editor_instance.has_signal("property_update_requested"):
			current_editor_instance.property_update_requested.connect(
				func(id: String, prop: String, val: Variant, sub_res: Resource = null):
					property_update_requested.emit(id, prop, val, sub_res)
			)
		
		if current_editor_instance.has_signal("complex_action_requested"):
			current_editor_instance.complex_action_requested.connect(complex_action_requested.emit)
		if current_editor_instance.has_signal("dive_in_requested"):
			current_editor_instance.dive_in_requested.connect(dive_in_requested.emit)
		
		# <-- NEW CONNECTION LOGIC
		if current_editor_instance.has_signal("ports_need_refresh"):
			current_editor_instance.ports_need_refresh.connect(
				func(id): node_ports_changed.emit(id)
			)
		# -->
		
		editor_host.add_child(current_editor_instance)
		current_editor_instance.call_deferred("set_node_data", node_data)
	else:
		var id_label = Label.new()
		id_label.text = node_data.id
		add_property_row("ID", id_label)

func refresh_inspected_node() -> void:
	if not visible or not is_instance_valid(_inspected_node_data):
		return
		
	var current_graph = data_manager.get_active_graph()
	if not is_instance_valid(current_graph):
		return

	var fresh_node_data = current_graph.nodes.get(_inspected_node_data.id)
	if is_instance_valid(fresh_node_data):
		inspect_node(fresh_node_data)

func add_property_row(prop_name: String, editor_control: Control) -> void:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = prop_name + ":"
	label.custom_minimum_size.x = 100
	row.add_child(label)
	editor_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(editor_control)
	editor_host.add_child(row)

func get_inspected_node_id() -> String:
	if is_instance_valid(_inspected_node_data):
		return _inspected_node_data.id
	return ""

# --- Window Management (Unchanged) ---
func _on_close_requested() -> void:
	if is_instance_valid(editor_plugin):
		editor_plugin.save_setting(SETTING_SIZE, size)
		editor_plugin.save_setting(SETTING_POSITION, position)
	hide()

func _on_about_to_popup() -> void:
	if not is_instance_valid(editor_plugin): return
	var loaded_size = editor_plugin.load_setting(SETTING_SIZE, null)
	var loaded_position = editor_plugin.load_setting(SETTING_POSITION, null)
	if loaded_size is Vector2i: size = loaded_size
	if loaded_position is Vector2i: position = loaded_position
	else:
		var viewport_rect = get_viewport().get_visible_rect()
		position = Vector2i(viewport_rect.position) + (Vector2i(viewport_rect.size) - size) / 2
