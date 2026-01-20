# res://addons/quest_weaver/nodes/action/give_take_item_node/give_take_item_node_editor.gd
@tool
extends NodePropertyEditorBase

@onready var item_id_edit: AutoCompleteLineEdit = %ItemIDEdit
@onready var amount_spinbox: SpinBox = %AmountSpinBox
@onready var action_picker: OptionButton = %ActionPicker
@onready var terminal_checkbox: CheckBox = %TerminalCheckBox

var _is_setting_up := false

func _ready() -> void:
	# This connects all confirmation actions (Enter, focus loss, list click).
	item_id_edit.text_submitted.connect(_on_item_id_confirmed)
	amount_spinbox.value_changed.connect(_on_amount_changed)
	action_picker.item_selected.connect(_on_action_changed)
	terminal_checkbox.toggled.connect(_on_terminal_toggled)
	
	# --- TOOLTIPS ---
	item_id_edit.tooltip_text = "The unique identifier of the item.\nMust match an ID in your Inventory System or Item Registry."
	amount_spinbox.tooltip_text = "The quantity of items to process.\nMust be greater than 0."
	action_picker.tooltip_text = "Determines the operation:\n- Give: Adds items to the player's inventory (Always succeeds).\n- Take: Removes items (Fails and triggers 'Failure' port if not enough items exist)."

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is GiveTakeItemNodeResource: return

	_is_setting_up = true
	
	QWEditorUtils.populate_item_completer(item_id_edit)
	item_id_edit.text = node_data.item_id
	
	amount_spinbox.min_value = 1
	amount_spinbox.step = 1
	amount_spinbox.set_value_no_signal(node_data.amount)
	
	action_picker.clear()
	for action_name in node_data.Action.keys():
		action_picker.add_item(action_name)
	action_picker.select(node_data.action)
	
	terminal_checkbox.button_pressed = node_data.is_terminal
	
	call_deferred("_finish_setup")

func _finish_setup() -> void:
	_is_setting_up = false

func _on_item_id_confirmed(new_text: String) -> void:
	if _is_setting_up: return
	if is_instance_valid(edited_node_data) and edited_node_data.item_id != new_text:
		property_update_requested.emit(edited_node_data.id, "item_id", new_text)

func _on_amount_changed(value: float) -> void:
	if _is_setting_up: return
	if is_instance_valid(edited_node_data) and edited_node_data.amount != int(value):
		property_update_requested.emit(edited_node_data.id, "amount", int(value))

func _on_action_changed(index: int) -> void:
	if _is_setting_up: return
	if is_instance_valid(edited_node_data) and edited_node_data.action != index:
		property_update_requested.emit(edited_node_data.id, "action", index)

func _on_terminal_toggled(pressed: bool) -> void:
	if is_instance_valid(edited_node_data) and edited_node_data.is_terminal != pressed:
		property_update_requested.emit(edited_node_data.id, "is_terminal", pressed)
		edited_node_data.is_terminal = pressed
		edited_node_data._update_ports_from_data()
