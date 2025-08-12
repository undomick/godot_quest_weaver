# res://addons/quest_weaver/validation/validator_dock.gd
@tool
class_name QuestWeaverValidator
extends MarginContainer

signal validation_requested
signal result_selected(node_id: String)

const DEBUG_SETTINGS_PATH = "res://addons/quest_weaver/debugger/debug_settings.tres"
const DEBUG_CATEGORIES = ["System", "Flow", "Executor", "Inventory", "Animation", "SaveLoad"]
var _debug_settings: QuestWeaverDebugSettings

@onready var validate_button: Button = %ValidateButton
@onready var results_tree: Tree = %ResultsTree
@onready var category_list: VBoxContainer = %CategoryList

func _ready():
	validate_button.text = "Validate Active Quest"
	validate_button.icon = get_theme_icon("Search", "EditorIcons")
	
	results_tree.set_column_title(0, "Severity")
	results_tree.set_column_title(1, "Message")
	results_tree.set_column_title(2, "Node")
	
	results_tree.set_column_expand(0, false) # Severity: nicht expandieren
	results_tree.set_column_expand(1, true)  # Message: expandieren
	results_tree.set_column_expand(2, false) # Node: nicht expandieren
	
	results_tree.set_column_custom_minimum_width(0, 200) # 80 Pixel für "Severity"
	results_tree.set_column_custom_minimum_width(1, 200) # 200 Pixel für "Message"
	results_tree.set_column_custom_minimum_width(2, 200) # 120 Pixel für "Node"
	
	validate_button.pressed.connect(_on_validate_button_pressed)
	results_tree.item_selected.connect(_on_results_tree_item_selected)
	
	# --- Load settings and build the debug UI ---
	_load_debug_settings()
	_build_debug_ui()

# Diese Funktion wird von außen aufgerufen, um die Ergebnisse anzuzeigen.
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

# Leitet den Klick als Signal nach "außen" weiter.
func _on_validate_button_pressed():
	validation_requested.emit()

# Leitet die Auswahl als Signal nach "außen" weiter.
func _on_results_tree_item_selected():
	var selected_item = results_tree.get_selected()
	if not selected_item: return
		
	var node_id = selected_item.get_metadata(0)
	if node_id and not node_id.is_empty():
		result_selected.emit(node_id)

# --- DEBUG

# Loads the settings resource or creates it if it doesn't exist.
func _load_debug_settings():
	if ResourceLoader.exists(DEBUG_SETTINGS_PATH):
		_debug_settings = ResourceLoader.load(DEBUG_SETTINGS_PATH)
	else:
		_debug_settings = QuestWeaverDebugSettings.new()
		# Save it immediately so it exists for the next time.
		ResourceSaver.save(_debug_settings, DEBUG_SETTINGS_PATH)

	# Ensure all categories from our master list exist in the settings file.
	# This makes adding new categories in the future easy.
	var settings_changed := false
	for category in DEBUG_CATEGORIES:
		if not _debug_settings.active_categories.has(category):
			_debug_settings.active_categories[category] = true # Default new categories to 'on'.
			settings_changed = true
	
	if settings_changed:
		ResourceSaver.save(_debug_settings, DEBUG_SETTINGS_PATH)

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
	# ...and save the change back to the .tres file.
	ResourceSaver.save(_debug_settings, DEBUG_SETTINGS_PATH)
