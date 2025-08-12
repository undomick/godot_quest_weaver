@tool
class_name LocalizationKeyScanner
extends RefCounted

## Analyzes the project and updates CSV.
static func update_localization_file(scan_folder: String, csv_path: String) -> void:
	if scan_folder.is_empty() or csv_path.is_empty():
		push_warning("Key Scanner: Scan folder or CSV path not configured in settings.")
		return

	var existing_keys: Dictionary = _load_existing_keys(csv_path)
	var found_strings: Dictionary = {}

	# Rekursive Search for all .quest-Files
	var directories_to_scan := [scan_folder]
	while not directories_to_scan.is_empty():
		var current_dir_path = directories_to_scan.pop_front()
		var dir = DirAccess.open(current_dir_path)
		if not dir: continue
		
		for item_name in dir.get_files():
			var full_path = current_dir_path.path_join(item_name)
			if full_path.ends_with("." + QWConstants.FILE_EXTENSION):
				_scan_quest_file(full_path, found_strings)
		
		for item_name in dir.get_dirs():
			directories_to_scan.push_back(current_dir_path.path_join(item_name))
	
	# Filters the Strings, which already exists as Keys in the CSV.
	var new_keys_to_add: Array[String] = []
	for text in found_strings:
		if not existing_keys.has(text):
			new_keys_to_add.append(text)
	
	if new_keys_to_add.is_empty():
		print("[Key Scanner] Localization file is already up-to-date. No new keys found.")
		return
		
	# Add new Keys to CSV-File.
	_append_keys_to_csv(csv_path, new_keys_to_add)
	print("[Key Scanner] Added %d new key(s) to localization file '%s'." % [new_keys_to_add.size(), csv_path.get_file()])

## Reads a single Quest and collects the texts.
static func _scan_quest_file(path: String, found_strings: Dictionary):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var data = file.get_var(true)
	file.close()
	
	if not data is Dictionary or not data.has("nodes"): return

	for node_data in data.get("nodes").values():
		var script_path = node_data.get("@script_path", "").get_file().replace(".gd", "")
		
		if QWConstants.TRANSLATABLE_FIELDS.has(script_path):
			for field_name in QWConstants.TRANSLATABLE_FIELDS[script_path]:
				var text = node_data.get(field_name, "")
				if not text.is_empty():
					found_strings[text] = true # Dictionary, for avoiding duplicates
		
		# Special Case: TaskNode has Objectives
		if script_path == "TaskNodeResource":
			for objective_data in node_data.get("objectives", []):
				var text = objective_data.get("description", "")
				if not text.is_empty():
					found_strings[text] = true

## reads existing CSV to avoid duplicates.
static func _load_existing_keys(path: String) -> Dictionary:
	var keys := {}
	if not FileAccess.file_exists(path):
		return keys

	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return keys
	
	# Skip header
	file.get_csv_line()
	
	while not file.eof_reached():
		var line_data = file.get_csv_line()
		if line_data.size() > 0 and not line_data[0].is_empty():
			keys[line_data[0]] = true
	return keys

## stores new keys in CSV.
static func _append_keys_to_csv(path: String, new_keys: Array[String]):
	var file_existed = FileAccess.file_exists(path)
	var file = FileAccess.open(path, FileAccess.WRITE_READ)
	if not file:
		push_error("Key Scanner: Could not open/create CSV file at '%s'." % path)
		return
		
	if not file_existed:
		file.store_line("keys,en,de") # add header only in new files
	
	file.seek_end() # go to end of file
	
	for key in new_keys:
		# respect special signs
		var escaped_key = "\"%s\"" % key.replace("\"", "\"\"")
		file.store_line("%s,%s,%s" % [escaped_key, escaped_key, escaped_key])
