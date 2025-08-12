# res://addons/quest_weaver/ui/conditions/objective_editor_entry.gd
@tool
class_name ObjectiveEditorEntry
extends VBoxContainer

signal description_changed(new_description: String)
signal trigger_type_changed(new_trigger_type: int)
signal trigger_param_changed(param_name: String, new_value: Variant)
signal delete_requested
signal direct_property_changed(property_name: String, new_value: Variant)

@onready var description_edit: LineEdit = %DescriptionEdit
@onready var delete_button: Button = %DeleteButton
@onready var trigger_type_picker: OptionButton = %TriggerTypePicker
@onready var track_progress_checkbox: CheckBox = %TrackProgressCheckbox
@onready var trigger_params_container: VBoxContainer = %TriggerParamsContainer
@onready var id_line_edit: LineEdit = %IdLineEdit
@onready var copy_id_button: Button = %CopyIdButton

var objective_resource: ObjectiveResource
var _is_setting_up := false

func _ready():
	# This robust pattern works for LineEdits.
	description_edit.text_submitted.connect(func(text): _on_description_changed(text))
	description_edit.focus_exited.connect(func(): _on_description_changed(description_edit.text))
	
	delete_button.pressed.connect(delete_requested.emit)
	trigger_type_picker.item_selected.connect(_on_trigger_type_selected)
	track_progress_checkbox.toggled.connect(_on_track_progress_toggled)
	
	trigger_type_picker.clear()
	for type_name in ObjectiveResource.TriggerType.keys():
		trigger_type_picker.add_item(type_name)
		
	copy_id_button.icon = get_theme_icon("Duplicate", "EditorIcons")
	copy_id_button.pressed.connect(_on_copy_id_pressed)

func set_objective(obj_res: ObjectiveResource):
	_is_setting_up = true
	self.objective_resource = obj_res
	id_line_edit.text = obj_res.id
	description_edit.text = obj_res.description
	trigger_type_picker.select(obj_res.trigger_type)
	track_progress_checkbox.button_pressed = obj_res.track_progress_since_activation
	
	call_deferred("_rebuild_trigger_param_ui")
	call_deferred("_finish_setup")

func _finish_setup() -> void:
	_is_setting_up = false

func _rebuild_trigger_param_ui():
	for child in trigger_params_container.get_children():
		child.queue_free()
	if not is_instance_valid(objective_resource): return
	
	match objective_resource.trigger_type:
		ObjectiveResource.TriggerType.ITEM_COLLECT:
			var item_id_completer = _create_param_completer("item_id")
			QWEditorUtils.populate_item_completer(item_id_completer)
			add_param_row("Item ID", item_id_completer)
			
			var amount_spinbox = _create_param_spinbox("amount")
			add_param_row("Amount", amount_spinbox)
		
		ObjectiveResource.TriggerType.LOCATION_ENTER, ObjectiveResource.TriggerType.INTERACT, ObjectiveResource.TriggerType.KILL:
			var key_map = {
				ObjectiveResource.TriggerType.LOCATION_ENTER: "location_id",
				ObjectiveResource.TriggerType.INTERACT: "target_path",
				ObjectiveResource.TriggerType.KILL: "enemy_id"
			}
			var param_key = key_map[objective_resource.trigger_type]
			var param_edit = _create_param_line_edit(param_key)
			add_param_row(param_key.replace("_", " ").capitalize(), param_edit)

			if objective_resource.trigger_type == ObjectiveResource.TriggerType.KILL:
				var amount_spinbox = _create_direct_property_spinbox("required_progress")
				add_param_row("Required", amount_spinbox)
	
	track_progress_checkbox.visible = (objective_resource.trigger_type == ObjectiveResource.TriggerType.ITEM_COLLECT)

# --- UI Creation Helper Functions ---

func _create_param_completer(param_name: String) -> AutoCompleteLineEdit:
	var completer = QWConstants.AutoCompleteLineEditScene.instantiate()
	completer.text = objective_resource.trigger_params.get(param_name, "")
	completer.text_submitted.connect(_on_param_changed.bind(param_name))
	return completer

func _create_param_line_edit(param_name: String) -> LineEdit:
	var line_edit = LineEdit.new()
	line_edit.text = str(objective_resource.trigger_params.get(param_name, ""))
	line_edit.text_submitted.connect(_on_param_changed.bind(param_name))
	line_edit.focus_exited.connect(func(): _on_param_changed(line_edit.text, param_name))
	return line_edit

func _create_param_spinbox(param_name: String) -> SpinBox:
	var spinbox = SpinBox.new()
	spinbox.min_value = 1; spinbox.step = 1; spinbox.allow_greater = true
	spinbox.set_value_no_signal(objective_resource.trigger_params.get(param_name, 1))
	
	# The simple, direct, and working connection.
	spinbox.value_changed.connect(_on_param_spinbox_changed.bind(param_name))
	return spinbox

func _create_direct_property_spinbox(prop_name: String) -> SpinBox:
	var spinbox = SpinBox.new()
	spinbox.min_value = 1; spinbox.step = 1; spinbox.allow_greater = true
	spinbox.set_value_no_signal(objective_resource.get(prop_name))
	
	# The simple, direct, and working connection.
	spinbox.value_changed.connect(_on_direct_property_spinbox_changed.bind(prop_name))
	return spinbox

# --- Signal Handlers ---

func _on_description_changed(new_text: String):
	if _is_setting_up: return
	if is_instance_valid(objective_resource) and objective_resource.description != new_text:
		description_changed.emit(new_text)

func _on_trigger_type_selected(index: int):
	if _is_setting_up: return
	if is_instance_valid(objective_resource) and objective_resource.trigger_type != index:
		trigger_type_changed.emit(index)

func _on_track_progress_toggled(is_pressed: bool):
	if _is_setting_up: return
	if is_instance_valid(objective_resource) and objective_resource.track_progress_since_activation != is_pressed:
		direct_property_changed.emit("track_progress_since_activation", is_pressed)

func _on_param_changed(new_value_text: String, param_name: String):
	if _is_setting_up: return
	if objective_resource.trigger_params.get(param_name, "") != new_value_text:
		trigger_param_changed.emit(param_name, new_value_text)

func _on_param_spinbox_changed(value: float, param_name: String):
	if _is_setting_up: return
	var new_value = int(value)
	if objective_resource.trigger_params.get(param_name, 1) != new_value:
		trigger_param_changed.emit(param_name, new_value)

func _on_direct_property_spinbox_changed(value: float, prop_name: String):
	if _is_setting_up: return
	var new_value = int(value)
	if objective_resource.get(prop_name) != new_value:
		direct_property_changed.emit(prop_name, new_value)
		
func _on_copy_id_pressed():
	DisplayServer.clipboard_set(id_line_edit.text)

func add_param_row(label_text: String, control: Control):
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 80
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	trigger_params_container.add_child(row)
