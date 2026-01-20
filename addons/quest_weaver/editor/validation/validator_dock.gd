# res://addons/quest_weaver/editor/validation/validator_dock.gd
@tool
class_name QuestWeaverValidator
extends MarginContainer

signal validation_requested
signal result_selected(node_id: String)

# We use the categories to dynamically build the debug UI checkboxes.
const DEBUG_CATEGORIES = ["System", "Flow", "Executor", "Inventory", "Animation", "SaveLoad"]

var _debug_settings: QuestWeaverDebugSettings

@onready var validate_button: Button = %ValidateButton
@onready var results_tree: Tree = %ResultsTree
@onready var category_list: VBoxContainer = %CategoryList

func _ready():
	validate_button.text = "Validate Active Quest"
	validate_button.icon = get_theme_icon("Search", "EditorIcons")
	
	# Configure the results tree columns
	results_tree.set_column_title(0, "Severity")
	results_tree.set_column_title(1, "Message")
	results_tree.set_column_title(2, "Node")
	
	results_tree.set_column_expand(0, false) # Severity: do not expand
	results_tree.set_column_expand(1, true)  # Message: expand to fill space
	results_tree.set_column_expand(2, false) # Node: do not expand
	
	# Set minimum widths for better readability
	results_tree.set_column_custom_minimum_width(0, 120)  # Fixed width for Severity icon/text
	results_tree.set_column_custom_minimum_width(1, 200) # Minimum for Message
	results_tree.set_column_custom_minimum_width(2, 200) # Fixed width for Node ID
	
	validate_button.pressed.connect(_on_validate_button_pressed)
	results_tree.item_selected.connect(_on_results_tree_item_selected)
	
	# --- Load settings and build the debug UI ---
	_load_debug_settings()
	_build_debug_ui()

# Called externally by the editor to display validation results.
func display_results(results: Array[ValidationResult]):
	results_tree.clear()
	var root = results_tree.create_item()
	
	if results.is_empty():
		var item = results_tree.create_item(root)
		item.set_text(1, "Validation successful: No issues found.")
		item.set_icon(0, get_theme_icon("StatusSuccess", "EditorIcons"))
		return
	
	var error_icon = get_theme_icon("Error", "EditorIcons")
	var warning_icon = get_theme_icon("Warning", "EditorIcons")
	var info_icon = get_theme_icon("Info", "EditorIcons")
	
	for result in results:
		var item = results_tree.create_item(root)
		item.set_text(1, result.message)
		item.set_text(2, result.node_id)
		item.set_metadata(0, result.node_id)
		
		match result.severity:
			ValidationResult.Severity.ERROR:
				item.set_icon(0, error_icon)
				item.set_text(0, "Error")
			ValidationResult.Severity.WARNING:
				item.set_icon(0, warning_icon)
				item.set_text(0, "Warning")
			ValidationResult.Severity.INFO:
				item.set_icon(0, info_icon)
				item.set_text(0, "Info")

# Forwards the button click signal to the editor.
func _on_validate_button_pressed():
	validation_requested.emit()

# Forwards the item selection signal to the editor to focus the node.
func _on_results_tree_item_selected():
	var selected_item = results_tree.get_selected()
	if not selected_item: return
		
	var node_id = selected_item.get_metadata(0)
	if node_id and not node_id.is_empty():
		result_selected.emit(node_id)

# --- DEBUG SETTINGS ---

# Loads the settings resource or creates it if it doesn't exist.
func _load_debug_settings():
	if ResourceLoader.exists(QWConstants.DEBUG_SETTINGS_PATH):
		_debug_settings = ResourceLoader.load(QWConstants.DEBUG_SETTINGS_PATH)
	else:
		_debug_settings = QuestWeaverDebugSettings.new()
		# Save it immediately so it exists for the next time.
		ResourceSaver.save(_debug_settings, QWConstants.DEBUG_SETTINGS_PATH)

	# Ensure all categories from our master list exist in the settings file.
	# This makes adding new categories in the future easy.
	var settings_changed := false
	for category in DEBUG_CATEGORIES:
		if not _debug_settings.active_categories.has(category):
			_debug_settings.active_categories[category] = true # Default new categories to 'on'.
			settings_changed = true
	
	if settings_changed:
		ResourceSaver.save(_debug_settings, QWConstants.DEBUG_SETTINGS_PATH)

# Creates the CheckBox controls dynamically based on the master list.
func _build_debug_ui():
	for child in category_list.get_children():
		child.queue_free()

	for category in DEBUG_CATEGORIES:
		var checkbox = CheckBox.new()
		checkbox.text = category
		checkbox.button_pressed = _debug_settings.active_categories.get(category, true)
		# When a checkbox is toggled, call the handler function.
		checkbox.toggled.connect(_on_debug_category_toggled.bind(category))
		category_list.add_child(checkbox)

# Called when any checkbox is toggled by the user.
func _on_debug_category_toggled(is_pressed: bool, category: String):
	if not is_instance_valid(_debug_settings): return
	
	# Update the value in our settings resource...
	_debug_settings.active_categories[category] = is_pressed
	# ...and save the change back to the .tres file immediately.
	ResourceSaver.save(_debug_settings, QWConstants.DEBUG_SETTINGS_PATH)
