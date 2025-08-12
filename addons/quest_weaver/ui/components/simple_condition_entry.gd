# res://addons/quest_weaver/ui/editors/components/simple_condition_entry.gd
@tool
extends HBoxContainer

signal changed(new_data: Dictionary)
signal removed

@onready var key_edit: LineEdit = %KeyEdit
@onready var op_picker: OptionButton = %OperatorPicker
@onready var value_edit: LineEdit = %ValueEdit
@onready var remove_button: Button = %RemoveButton

func _ready() -> void:
	op_picker.clear()

	for op_name in EventListenerNodeResource.SimpleOperator.keys():
		op_picker.add_item(op_name)
	
	key_edit.text_submitted.connect(func(_text): _on_value_changed())
	key_edit.focus_exited.connect(_on_value_changed)
	op_picker.item_selected.connect(func(_index): _on_value_changed())
	value_edit.text_submitted.connect(func(_text): _on_value_changed())
	value_edit.focus_exited.connect(_on_value_changed)
	remove_button.pressed.connect(removed.emit)

func set_data(data: Dictionary):
	key_edit.text = data.get("key", "")
	op_picker.select(data.get("op", 0))
	value_edit.text = data.get("value", "")

func _on_value_changed():
	# Sammle die aktuellen Daten aus den UI-Feldern
	var new_data = {
		"key": key_edit.text,
		"op": op_picker.selected,
		"value": value_edit.text
	}
	# Sende sie als einzelnes Signal nach oben
	changed.emit(new_data)
