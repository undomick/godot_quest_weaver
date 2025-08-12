# res://addons/quest_weaver/ui/qw_graph_node.gd
@tool
class_name QWGraphNode
extends GraphNode

var summary_text: String = ""


func _draw():
	if summary_text.is_empty():
		return
	
	var font = get_theme_font("title_font")
	var font_size = get_theme_font_size("title_font_size") - 2
	var margin = 48.0

	var final_summary_text = summary_text

	if summary_text.begins_with("[TRUNCATE]"):
		var text_to_process = summary_text.trim_prefix("[TRUNCATE]")
		var available_width = size.x - margin * 2
		
		var lines: Array[String] = []
		var remaining_text = text_to_process
		
		while not remaining_text.is_empty() and lines.size() < 2:
			if font.get_string_size(remaining_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
				lines.append(remaining_text)
				remaining_text = ""
				break
			
			var wrap_index = -1
			for i in range(remaining_text.length(), 0, -1):
				var substring = remaining_text.left(i)
				if font.get_string_size(substring, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
					wrap_index = substring.rfind(" ")
					break
			
			if wrap_index > 0:
				lines.append(remaining_text.left(wrap_index).strip_edges())
				remaining_text = remaining_text.substr(wrap_index).strip_edges()
			else:
				var hard_break_index = remaining_text.length()
				for i in range(remaining_text.length(), 0, -1):
					if font.get_string_size(remaining_text.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
						hard_break_index = i
						break
				lines.append(remaining_text.left(hard_break_index))
				remaining_text = remaining_text.substr(hard_break_index).strip_edges()

		if not remaining_text.is_empty():
			var last_line = ""
			for i in range(remaining_text.length(), 0, -1):
				var substring = remaining_text.left(i) + "..."
				if font.get_string_size(substring, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
					last_line = substring
					break
			if last_line.is_empty() and font.get_string_size("...", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
				last_line = "..."
			lines.append(last_line)

		final_summary_text = "\n".join(lines)

	var line_spacing = font.get_height(font_size) + 2
	var text_to_process = final_summary_text
	var is_global_warning = text_to_process.begins_with("[WARN]")
	if is_global_warning:
		text_to_process = text_to_process.trim_prefix("[WARN]")

	var lines_to_draw: PackedStringArray = text_to_process.split("\n")
	var total_text_height = lines_to_draw.size() * line_spacing
	var current_y = (size.y - total_text_height) / 2.0 + font.get_ascent(font_size)

	for line in lines_to_draw:
		var color = Color.WHITE
		var text_to_draw = line
		if is_global_warning:
			color = Color.ORANGE_RED
		elif text_to_draw.begins_with("[WARN]"):
			color = Color.ORANGE_RED
			text_to_draw = text_to_draw.trim_prefix("[WARN]")

		draw_string(
			font, Vector2(margin, current_y), text_to_draw,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - margin * 2, font_size, color
		)
		current_y += line_spacing
