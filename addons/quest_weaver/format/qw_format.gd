# res://addons/dein_plugin_name/QWFormat.gd
@tool
class_name QWFormat
extends RefCounted

class QuestGraphFormatSaver extends ResourceFormatSaver:
	func _get_recognized_extensions(_for_resource: Resource = null) -> PackedStringArray:
		return [QWConstants.FILE_EXTENSION]

	func _recognize(p_resource: Resource) -> bool:
		return p_resource is QuestGraphResource

	func _save(p_resource: Resource, p_path: String, _flags: int = 0) -> Error:
		var data_to_save = p_resource.to_dictionary()

		var file = FileAccess.open(p_path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()

		# Saves the Dictionary as Text in the ".quest" fileformat.
		file.store_var(data_to_save, true)
		
		if file.get_error() != OK:
			return FAILED
			
		file.close()
		return OK
