# res://addons/quest_weaver/plugin.gd
@tool
class_name QuestWeaverPlugin
extends EditorPlugin

var main_view: QuestWeaverEditor = null
var editor_data: QuestEditorData
var validator_dock: QuestWeaverValidator
var debugger_node: QuestWeaverDebugger
var import_plugin: EditorImportPlugin
var export_plugin: EditorExportPlugin
var saver: ResourceFormatSaver

func _enable_plugin() -> void:
	var base_path = get_plugin_path()
	var global_path = base_path + "/core/quest_weaver_global.gd"
	var services_path = base_path + "/core/quest_weaver_services.gd"
	
	add_autoload_singleton("QuestWeaverGlobal", global_path)
	add_autoload_singleton("QuestWeaverServices", services_path)
	_load_editor_data()

func _disable_plugin() -> void:
	remove_autoload_singleton("QuestWeaverGlobal")
	remove_autoload_singleton("QuestWeaverServices")

func _enter_tree() -> void:
	import_plugin = QWConstants.ImportPluginScript.new()
	export_plugin = QWConstants.ExportPluginScript.new()
	saver = QWFormat.QuestGraphFormatSaver.new()
	add_import_plugin(import_plugin)
	add_export_plugin(export_plugin)
	ResourceSaver.add_resource_format_saver(saver)

	var icon = load(QWConstants.ICON_PATH)
	add_custom_type(QWConstants.RESOURCE_TYPE_NAME, "Resource", QWConstants.QuestGraphResourceScript, icon)
	
	var base_control = EditorInterface.get_base_control()
	validator_dock = base_control.find_child(QWConstants.VALIDATOR_DOCK_NAME, true, false)

	if not is_instance_valid(validator_dock):
		validator_dock = QWConstants.ValidatorDockScene.instantiate()
		validator_dock.name = QWConstants.VALIDATOR_DOCK_NAME
		add_control_to_bottom_panel(validator_dock, "Quest Validator")

	debugger_node = QWConstants.QuestWeaverDebuggerNode.new()
	debugger_node.name = "QuestWeaverDebuggerHost"
	add_child(debugger_node)
	add_debugger_plugin(debugger_node.get_plugin_instance())
	
	var editor_interface = get_editor_interface()
	if editor_interface:
		editor_interface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)

func _exit_tree() -> void:
	_disconnect_signals()
	
	if is_instance_valid(main_view) and is_instance_valid(editor_data):
		if is_instance_valid(main_view.side_panel):
			editor_data.open_files = main_view.side_panel.get_open_files()
		if is_instance_valid(main_view.data_manager):
			editor_data.last_focused_file = main_view.data_manager.get_active_graph_path()
		if not editor_data.resource_path.is_empty():
			ResourceSaver.save(editor_data, editor_data.resource_path)
	
	var base_control = EditorInterface.get_base_control()
	if is_instance_valid(base_control):
		var dock_to_remove = base_control.find_child(QWConstants.VALIDATOR_DOCK_NAME, true, false)
		if is_instance_valid(dock_to_remove):
			remove_control_from_bottom_panel(dock_to_remove)
			dock_to_remove.queue_free()
	if is_instance_valid(main_view):
		main_view.queue_free()
	if is_instance_valid(debugger_node) and is_instance_valid(debugger_node.get_plugin_instance()):
		remove_debugger_plugin(debugger_node.get_plugin_instance())
	
	remove_custom_type(QWConstants.RESOURCE_TYPE_NAME)
	
	call_deferred("_deferred_cleanup")

func _deferred_cleanup() -> void:
	if is_instance_valid(saver):
		ResourceSaver.remove_resource_format_saver(saver)
	if is_instance_valid(export_plugin):
		remove_export_plugin(export_plugin)
	if is_instance_valid(import_plugin):
		remove_import_plugin(import_plugin)
	
	import_plugin = null
	export_plugin = null
	saver = null

func _load_editor_data() -> QuestEditorData:
	var path = QWConstants.Settings.editor_data_path
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path, "QuestEditorData", ResourceLoader.CACHE_MODE_REPLACE)
	else:
		var new_data = QuestEditorData.new()
		var save_err = ResourceSaver.save(new_data, path)
		if save_err != OK:
			push_error("QuestWeaver: Could not save new editor_data resource at '%s'" % path)
		return new_data

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool):
	if not visible:
		if is_instance_valid(main_view):
			main_view.cancel_any_active_drags()
			
			main_view.visible = false
			if is_instance_valid(main_view.properties_panel):
				main_view.properties_panel.hide()
		return

	if not is_instance_valid(main_view):
		editor_data = _load_editor_data()
		main_view = QWConstants.MainViewScene.instantiate()
		EditorInterface.get_editor_main_screen().add_child(main_view)
		
		_connect_signals()
		
		# Get the EditorInterface instance
		var editor_interface = get_editor_interface()
		
		# FIX: Pass the editor_interface instance to the initialize function
		main_view.call_deferred("initialize", self, editor_data, editor_interface)
		
		if editor_interface:
			main_view.set_editor_scale(editor_interface.get_editor_scale())
		
	main_view.visible = true

func _handles(object: Object) -> bool:
	return object is QuestGraphResource

func _build() -> bool:
	if is_instance_valid(main_view) and main_view.is_node_ready():
		var action_handler = main_view.get_action_handler()
		
		if is_instance_valid(action_handler):
			action_handler.save_all_modified_graphs()
			print("[QuestWeaver] Auto-saved all modified quests before build/run.")
	
	return true

func _edit(object: Object) -> void:
	if object is QuestGraphResource:
		_make_visible(true)
		main_view.edit_graph(object.resource_path)

func _connect_signals() -> void:
	if is_instance_valid(validator_dock) and is_instance_valid(main_view):
		validator_dock.validation_requested.connect(main_view._on_validation_requested)
		validator_dock.result_selected.connect(main_view._on_validation_result_selected)
		main_view.validation_finished.connect(validator_dock.display_results)
	if is_instance_valid(debugger_node) and is_instance_valid(main_view):
		debugger_node.session_started.connect(main_view._on_debug_session_started)
		debugger_node.session_ended.connect(main_view._on_debug_session_ended)
		debugger_node.node_activated_in_game.connect(main_view._on_debug_node_activated)
		debugger_node.node_completed_in_game.connect(main_view._on_debug_node_completed)

func _disconnect_signals() -> void:
	var editor_interface = get_editor_interface()
	if is_instance_valid(editor_interface):
		var fs = editor_interface.get_resource_filesystem()
		if fs.is_connected("filesystem_changed", _on_filesystem_changed):
			fs.filesystem_changed.disconnect(_on_filesystem_changed)
			
	if is_instance_valid(validator_dock) and is_instance_valid(main_view):
		if validator_dock.is_connected("validation_requested", main_view._on_validation_requested):
			validator_dock.validation_requested.disconnect(main_view._on_validation_requested)
		if validator_dock.is_connected("result_selected", main_view._on_validation_result_selected):
			validator_dock.result_selected.disconnect(main_view._on_validation_result_selected)
		if main_view.is_connected("validation_finished", validator_dock.display_results):
			main_view.validation_finished.disconnect(validator_dock.display_results)
	
	if is_instance_valid(debugger_node) and is_instance_valid(main_view):
		if debugger_node.session_started.is_connected(main_view._on_debug_session_started):
			debugger_node.session_started.disconnect(main_view._on_debug_session_started)
		if debugger_node.session_ended.is_connected(main_view._on_debug_session_ended):
			debugger_node.session_ended.disconnect(main_view._on_debug_session_ended)
		if debugger_node.node_activated_in_game.is_connected(main_view._on_debug_node_activated):
			debugger_node.node_activated_in_game.disconnect(main_view._on_debug_node_activated)
		if debugger_node.node_completed_in_game.is_connected(main_view._on_debug_node_completed):
			debugger_node.node_completed_in_game.disconnect(main_view._on_debug_node_completed)

func _on_filesystem_changed() -> void:
	if is_instance_valid(main_view) and main_view.has_method("validate_open_files_exist"):
		main_view.call_deferred("validate_open_files_exist")

func save_setting(key: String, value: Variant) -> void:
	var setting_key = "plugins/quest_weaver/%s" % key
	var editor_settings = get_editor_interface().get_editor_settings()
	editor_settings.set_setting(setting_key, value)
	ProjectSettings.save()

func load_setting(key: String, default_value: Variant) -> Variant:
	var setting_key = "plugins/quest_weaver/%s" % key
	var editor_settings = get_editor_interface().get_editor_settings()
	
	if editor_settings.has_setting(setting_key):
		return editor_settings.get_setting(setting_key)
	else:
		return default_value

func get_plugin_path() -> String:
	return get_script().resource_path.get_base_dir()

func _get_plugin_name() -> String:
	return "QuestWeaver"

func _get_plugin_icon() -> Texture2D:
	return load(get_plugin_path() + "/assets/icon.svg")

func get_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	config.load(get_plugin_path() + "/plugin.cfg")
	return config.get_value("plugin", "version")
