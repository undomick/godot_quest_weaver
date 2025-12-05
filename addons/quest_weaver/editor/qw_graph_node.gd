# res://addons/quest_weaver/editor/qw_graph_node.gd
@tool
class_name QWGraphNode
extends GraphNode

var summary_text: String = "":
	set(value):
		# Minimize redraws by only updating if text actually changed
		if summary_text != value:
			summary_text = value
			queue_redraw()

func _draw():
	if summary_text.is_empty():
		return
	
	var font = get_theme_font("title_font")
	var font_size = get_theme_font_size("title_font_size") - 2
	
	var margin_left = 60.0  
	var margin_right = 20.0
	var available_width = size.x - (margin_left + margin_right)
	var final_lines: PackedStringArray = []

	# --- CASE 1: TRUNCATE MODE (e.g. TaskNode) ---
	# Limits text to ~2 lines and adds "..." if it exceeds the width.
	if summary_text.begins_with("[TRUNCATE]"):
		var text_to_process = summary_text.trim_prefix("[TRUNCATE]")
		var remaining_text = text_to_process.replace("\n", " ") # Flatten text for preview
		
		var processed_lines: Array[String] = []
		while not remaining_text.is_empty() and processed_lines.size() < 2:
			# Check if the rest fits in one line
			if font.get_string_size(remaining_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
				processed_lines.append(remaining_text)
				remaining_text = ""
				break
			
			# Find wrap point by searching backwards for the last space
			var wrap_index = -1
			for i in range(remaining_text.length(), 0, -1):
				var sub = remaining_text.left(i)
				if font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
					wrap_index = sub.rfind(" ")
					break
			
			if wrap_index > 0:
				processed_lines.append(remaining_text.left(wrap_index).strip_edges())
				remaining_text = remaining_text.substr(wrap_index).strip_edges()
			else:
				# Fallback: Hard break if a single word is longer than the node width
				var hard_idx = 1
				for i in range(remaining_text.length(), 0, -1):
					if font.get_string_size(remaining_text.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
						hard_idx = i
						break
				processed_lines.append(remaining_text.left(hard_idx))
				remaining_text = remaining_text.substr(hard_idx).strip_edges()

		if not remaining_text.is_empty():
			processed_lines.append("...")
			
		final_lines = PackedStringArray(processed_lines)

	# --- CASE 2: FULL TEXT MODE (e.g. CommentNode) ---
	else:
		final_lines = _wrap_text_smart(summary_text, font, font_size, available_width)

	# --- DRAWING & POSITIONING ---
	
	var header_height = 32.0 # Default fallback
	var titlebar = get_titlebar_hbox()
	if is_instance_valid(titlebar):
		header_height = titlebar.size.y
	
	var line_spacing = font.get_height(font_size) + 2
	var total_text_height = final_lines.size() * line_spacing
	
	# Vertical Positioning: Center text in the BODY (ignoring header height)
	var available_body_height = size.y - header_height
	var start_y = header_height + (available_body_height - total_text_height) / 2.0 + font.get_ascent(font_size)
	
	# Safety Clamp: Prevent text from rendering inside the header when resized too small
	start_y = max(start_y, header_height + font.get_ascent(font_size) + 4)

	var current_y = start_y

	for line in final_lines:
		var color = Color.WHITE.darkened(0.1)
		var text_to_draw = line
		
		# Highlight warning lines
		if text_to_draw.begins_with("[WARN]"):
			color = Color.ORANGE_RED
			text_to_draw = text_to_draw.trim_prefix("[WARN]")

		draw_string(
			font, Vector2(margin_left, current_y), text_to_draw,
			HORIZONTAL_ALIGNMENT_LEFT, available_width, font_size, color
		)
		current_y += line_spacing

# --- HELPER FOR SMART WRAPPING ---
func _wrap_text_smart(text: String, font: Font, font_size: int, max_width: float) -> PackedStringArray:
	var result_lines: PackedStringArray = []
	
	# 1. Respect manual line breaks (Enter key)
	var paragraphs = text.split("\n")
	
	for paragraph in paragraphs:
		if paragraph.is_empty():
			result_lines.append("")
			continue
			
		if font.get_string_size(paragraph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			result_lines.append(paragraph)
			continue
		
		# 2. Auto-wrap long paragraphs word by word
		var words = paragraph.split(" ")
		var current_line = ""
		
		for word in words:
			var test_line = word if current_line.is_empty() else current_line + " " + word
			
			if font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
				current_line = test_line
			else:
				if not current_line.is_empty():
					result_lines.append(current_line)
				current_line = word
				
				# Edge Case: Single word wider than node (Hard Break) - intentionally clipped/ignored here
				if font.get_string_size(current_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
					pass 
		
		if not current_line.is_empty():
			result_lines.append(current_line)
			
	return result_lines
