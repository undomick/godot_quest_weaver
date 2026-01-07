# res://addons/quest_weaver/editor/side_panel.gd
@tool
extends VBoxContainer

signal create_new_file_at_path(path: String)
signal open_file_requested(path: String)
signal bookmark_selected(path: String)
signal close_bookmark_requested(path: String)
signal save_active_graph_requested
signal save_single_file_requested(path: String)
signal save_all_files_requested

var data_manager: QWGraphData

@onready var new_button: Button = %NewButton
@onready var open_button: Button = %OpenButton
@onready var save_button: Button = %SaveButton
@onready var donate_button: Button = %DonateButton
@onready var docs_button: Button = %DocsButton
@onready var filter_edit: LineEdit = %FilterEdit
@onready var list: ItemList = %List
@onready var context_menu: PopupMenu = %ContextMenu
@onready var new_file_dialog: FileDialog = $NewFileDialog
@onready var open_file_dialog: FileDialog = $OpenFileDialog

var _open_files: Array[String] = []
var _context_menu_item_index: int = -1

var _search_icon: Texture2D
var _clear_icon: Texture2D

func initialize(p_data_manager: QWGraphData):
	self.data_manager = p_data_manager

func _ready() -> void:
	save_button.disabled = true
	
	apply_theme()
	list.clear()
	
	new_button.pressed.connect(_on_new_button_pressed)
	open_button.pressed.connect(_on_open_button_pressed)
	save_button.pressed.connect(save_active_graph_requested.emit)
	donate_button.pressed.connect(_on_donate_button_pressed)
	docs_button.pressed.connect(_on_docs_button_pressed)
	
	filter_edit.gui_input.connect(_on_filter_gui_input)
	filter_edit.text_changed.connect(_on_filter_text_changed)
	
	list.item_clicked.connect(_on_list_item_clicked)
	list.item_selected.connect(_on_list_item_selected)

	context_menu.clear()
	context_menu.add_item("Close", 0)
	context_menu.add_item("Close All Others", 1)
	context_menu.add_item("Close All", 2)
	context_menu.add_separator()
	context_menu.add_item("Save", 3)
	context_menu.add_item("Save All", 4)
	
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	context_menu.about_to_popup.connect(_on_context_menu_about_to_popup)
	
	new_file_dialog.file_selected.connect(create_new_file_at_path.emit)
	open_file_dialog.file_selected.connect(open_file_requested.emit)

func apply_theme() -> void:
	_search_icon = get_theme_icon("Search", "EditorIcons")
	_clear_icon = get_theme_icon("Close", "EditorIcons")
	
	new_button.icon = get_theme_icon("New", "EditorIcons")
	open_button.icon = get_theme_icon("Load", "EditorIcons")
	save_button.icon = get_theme_icon("Save", "EditorIcons")
	docs_button.icon = get_theme_icon("Help", "EditorIcons")
	
	filter_edit.clear_button_enabled = false
	filter_edit.right_icon = _search_icon

# --- PUBLIC API ---

func get_open_files() -> Array[String]:
	if _open_files == null:
		return []
	return _open_files

func add_file_to_open_list(path: String) -> void:
	if path.is_empty() or _open_files.has(path):
		return
	_open_files.append(path)
	_redraw_list()

func remove_file_from_open_list(path: String) -> void:
	if _open_files.has(path):
		_open_files.erase(path)
		_redraw_list()

func mark_file_as_unsaved(_file_path: String, _is_unsaved: bool) -> void:
	_redraw_list()

func update_selection(active_path: String) -> void:
	save_button.disabled = not data_manager.has_unsaved_changes(active_path)
	for i in range(list.item_count):
		if list.get_item_metadata(i) == active_path:
			if not list.is_selected(i):
				list.select(i)
			return
	list.deselect_all()

# --- INTERNAL LOGIC & HANDLER ---

func _on_filter_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		filter_edit.right_icon = _search_icon
	else:
		filter_edit.right_icon = _clear_icon
	
	_redraw_list()

func _on_filter_gui_input(event: InputEvent) -> void:
	if filter_edit.text.is_empty():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var icon_width = _clear_icon.get_width()
		var style = filter_edit.get_theme_stylebox("normal")
		var icon_area_start_x = filter_edit.size.x - icon_width - style.get_margin(Side.SIDE_RIGHT)
		
		if event.position.x > icon_area_start_x:
			filter_edit.clear()
			get_viewport().set_input_as_handled()

func _redraw_list() -> void:
	var current_selection = data_manager.get_active_graph_path()
	list.clear()
	
	var files_to_display: Array[String] = []
	var filter_text = filter_edit.text.to_lower()
	
	for path in _open_files:
		var file_basename = path.get_file().get_basename()
		
		if filter_text.is_empty() or file_basename.to_lower().contains(filter_text):
			files_to_display.append(path)
	
	files_to_display.sort()

	for path in files_to_display:
		var display_name = path.get_file()
		if data_manager.has_unsaved_changes(path):
			display_name += QWConstants.MODIFIED_SUFFIX
		var index = list.add_item(display_name)
		list.set_item_metadata(index, path)
	
	update_selection(current_selection)

func _on_new_button_pressed():
	new_file_dialog.popup_centered()

func _on_open_button_pressed():
	open_file_dialog.popup_centered()

func _on_donate_button_pressed() -> void:
	OS.shell_open("https://ko-fi.com/jundrie")

func _on_docs_button_pressed() -> void:
	OS.shell_open("https://github.com/undomick/godot_nexus_quest_weaver/wiki")

func _on_list_item_clicked(index: int, _at_pos: Vector2, mouse_btn: int) -> void:
	if mouse_btn == MOUSE_BUTTON_RIGHT:
		_context_menu_item_index = index
		list.select(index)
		context_menu.popup(Rect2i(get_global_mouse_position(), Vector2i.ZERO))

func _on_list_item_selected(index: int) -> void:
	var path = list.get_item_metadata(index)
	if path != data_manager.get_active_graph_path():
		bookmark_selected.emit(path)

func _on_context_menu_id_pressed(id: int) -> void:
	if _context_menu_item_index == -1: return

	var path = list.get_item_metadata(_context_menu_item_index)

	match id:
		0: # Close
			close_bookmark_requested.emit(path)
		1: # Close All Others
			for p in _open_files.duplicate():
				if p != path:
					close_bookmark_requested.emit(p)
		2: # Close All
			for p in _open_files.duplicate():
				close_bookmark_requested.emit(p)
		3: # Save
			save_single_file_requested.emit(path)
		4: # Save All
			save_all_files_requested.emit()

	_context_menu_item_index = -1

func _on_context_menu_about_to_popup() -> void:
	if _context_menu_item_index < 0 or _context_menu_item_index >= list.item_count:
		return
	var path = list.get_item_metadata(_context_menu_item_index)

	var has_unsaved_changes = data_manager.has_unsaved_changes(path)
	context_menu.set_item_disabled(context_menu.get_item_index(3), not has_unsaved_changes)
	
	var any_unsaved_files = not data_manager.get_all_unsaved_paths().is_empty()
	context_menu.set_item_disabled(context_menu.get_item_index(4), not any_unsaved_files)
