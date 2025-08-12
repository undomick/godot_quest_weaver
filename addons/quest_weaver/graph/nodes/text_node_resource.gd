# res://addons/quest_weaver/graph/nodes/text_node_resource.gd
@tool
class_name TextNodeResource
extends GraphNodeResource

enum TextTarget {
	ADD_TO_QUEST_LOG,      # Fügt einen Eintrag zum Logbuch hinzu (mehrzeilig)
	SET_QUEST_DESCRIPTION  # Überschreibt die aktuelle Beschreibung (mehrzeilig)
}

@export var target_property: TextTarget = TextTarget.ADD_TO_QUEST_LOG
@export_multiline var text_content: String = ""

func _init() -> void:
	category = "Logic"
	input_ports = ["In"]
	output_ports = ["Out"]

#func get_editor_summary() -> String:
	## Schritt 1: Bestimme die Kategorie für die erste Zeile.
	#var category_text: String
	#if target_property == TextTarget.ADD_TO_QUEST_LOG:
		#category_text = "[LOG]"
	#else:
		#category_text = "[DESCRIPTION]"
#
	## Ersetze manuelle Umbrüche durch Leerzeichen, damit unsere
	## Umbruch-Logik in _draw() saubere Worttrennungen durchführen kann.
	#var single_line_text = text_content.replace("\n", " ").strip_edges()
	#
	## Das [TRUNCATE]-Präfix ist das Signal an den QWGraphNode,
	## die intelligente Umbruch- und Kürzungslogik zu verwenden.
	#return category_text +"[TRUNCATE]" + single_line_text

func get_editor_summary() -> String:
	var category_text: String
	if target_property == TextTarget.ADD_TO_QUEST_LOG:
		category_text = "[LOG]\n"
	else:
		category_text = "[DESCRIPTION]\n"
	
	if text_content.is_empty():
		return "%s (Empty Text)" % category_text
		
	# Ersetze manuelle Umbrüche durch Leerzeichen, damit unsere
	# Umbruch-Logik in _draw() saubere Worttrennungen durchführen kann.
	var single_line_text = text_content.replace("\n", " ").strip_edges()
	
	# Das [TRUNCATE]-Präfix ist das Signal an den QWGraphNode,
	# die intelligente Umbruch- und Kürzungslogik zu verwenden.
	return "[TRUNCATE]" + category_text + single_line_text

func execute(controller) -> void: pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["target_property"] = self.target_property
	data["text_content"] = self.text_content
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.target_property = data.get("target_property", TextTarget.ADD_TO_QUEST_LOG)
	self.text_content = data.get("text_content", "")
