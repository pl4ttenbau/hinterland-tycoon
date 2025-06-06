@tool
class_name LoggieTools extends Node

## Removes BBCode from the given text.
## If [param specific_tags] is an array, it removes only the tags found in that array.
## Otherwise, it removes the tags found in the default_tags array:[br]
## [param ["b", "i", "u", "s", "indent", "code", "url", "center", "right", "color", "bgcolor", "fgcolor"]]
static func remove_BBCode(text: String, specific_tags = null) -> String:
	# The bbcode tags to remove.
	var default_tags = ["b", "i", "u", "s", "indent", "code", "url", "center", "right", "color", "bgcolor", "fgcolor"]
	var tags = specific_tags if specific_tags is Array else default_tags

	var regex = RegEx.new()
	var tags_pattern = "|".join(tags)
	regex.compile("\\[/?(" + tags_pattern + ")(=[^\\]]*)?\\]")

	var stripped_text = regex.sub(text, "", true)
	return stripped_text

## Concatenates all elements of the given [param args] array into one single string, in consecutive order.
## If [param custom_converter_fn] is provided, and is a [Callable], that function will be used to convert each element of the array into a string
## instead of using [method convert_to_string]. That function will receive 1 argument, which will be a 'Variant', and it has to return a 'String'.
static func concatenate_args(args : Array, custom_converter_fn : Variant = null) -> String:
	if args.size() == 0:
		return ""

	var converter_fn : Callable = LoggieTools.convert_to_string
	if custom_converter_fn is Callable and custom_converter_fn.is_valid() and !custom_converter_fn.is_null():
		converter_fn = custom_converter_fn

	# Start with first element without modifying array
	var final_msg : String = converter_fn.call(args[0])

	# Start from index 1 since we already handled index 0
	for i in range(1, args.size()):
		var arg = args[i]
		var is_not_followed_by_a_null_arg = true if (i + 1 <= args.size() - 1) and (args[i + 1] != null) else false
		if (arg != null) or (arg == null and is_not_followed_by_a_null_arg):
			var converted_arg : String = converter_fn.call(arg)
			final_msg += (" " + converted_arg)

	return final_msg

## Converts a text with BBCode in it to markdown.
## A limited set of BBCode tags are supported for this conversion, because standard Markdown can't handle everything
## that BBCode can. For example, colors will be entirely stripped.
static func convert_BBCode_to_markdown(text: String) -> String:
	# Purge the unsupported tags.
	var unsupported_tags = ["indent", "url", "center", "right", "color", "bgcolor", "fgcolor"]
	text = LoggieTools.remove_BBCode(text, unsupported_tags)

	# Space out all instances where "*" characters from multiple tags are strung together,
	# since that would break them from rendering with the proper effect in markdown.
	# This is only an issue with [b] and [i] tags because they both use the same "*" character
	# in markdown to be represented.
	text = text.replace("[/b][i]", "** *")
	text = text.replace("[/b][/i]", "** *")
	text = text.replace("[/i][b]", "* **")
	text = text.replace("[/i][/b]", "* **")
	text = text.replace("[/i][i]", "* *")
	text = text.replace("[/i][/i]", "* *")
	text = text.replace("[/b][b]", "** **")
	text = text.replace("[/b][/b]", "** **")

	# Perform all supported conversion.
	var supported_conversions = {
		"[b]" : "**", "[/b]" : "**",
		"[i]" : "*",  "[/i]" : "*",
		"[u]" : "__", "[/u]" : "__",
		"[s]" : "~~", "[/s]" : "~~",
	}
	for bbcodetag in supported_conversions.keys():
		text = text.replace(bbcodetag, supported_conversions[bbcodetag])

	return text

## Converts [param something] into a string, with custom handling for
## certain native and custom classes.
static func convert_to_string(something : Variant) -> String:
	var result : String
	if something is Dictionary:
		result = JSON.new().stringify(something, "  ", false, true)
	elif something is LoggieMsg:
		result = something.string()
	else:
		result = str(something)
	return result

## Takes the given [param str] and returns a terminal-ready version of it by converting its content
## to the appropriate format required to display the string correctly in the provided [param mode]
## msg format mode.
## [b]The provided [param str] is expected to be either in Plain or BBCode format.[/b]
static func convert_string_to_format_mode(str : String, mode : LoggieEnums.MsgFormatMode) -> String:
	match mode:
		LoggieEnums.MsgFormatMode.ANSI:
			# We put the message through the rich_to_ANSI converter which takes care of converting BBCode
			# to appropriate ANSI. (Only if the MsgFormatMode is set to ANSI).
			# Godot claims to be already preparing BBCode output for ANSI, but it only works with a small
			# predefined set of colors, and I think it totally strips stuff like [b], [i], etc.
			# It is possible to display those stylings in ANSI, but we have to do our own conversion here
			# to support these features instead of having them stripped.
			str = LoggieTools.rich_to_ANSI(str)
		LoggieEnums.MsgFormatMode.BBCODE:
			# No need to do anything for BBCODE mode, because we already expect all strings to
			# start out with this format in mind.
			pass
		LoggieEnums.MsgFormatMode.MARKDOWN:
			str = LoggieTools.convert_BBCode_to_markdown(str)
		LoggieEnums.MsgFormatMode.PLAIN, _:
			str = LoggieTools.remove_BBCode(str)
	return str

## Converts a given [Color] to an ANSI compatible representation of it in code.
static func color_to_ANSI(color: Color) -> String:
	var r = int(color.r * 255)
	var g = int(color.g * 255)
	var b = int(color.b * 255)
	return "\u001b[38;2;%d;%d;%dm" % [r, g, b]

## Strips the BBCode from the given text, and converts all [b], [i] and [color] tags to appropriate ANSI representable codes,
## then returns the converted string. The result of this conversion becomes an ANSI compatible representation of the given [param text].
static func rich_to_ANSI(text: String) -> String:
	var regex_color = RegEx.new()
	regex_color.compile("\\[color=(.*?)\\](.*?)\\[/color\\]")
	
	# Process color tags first.
	while regex_color.search(text):
		var match = regex_color.search(text)
		var color_str = match.get_string(1).to_upper()
		var color: Color
		var color_code: String
		var reset_code = "\u001b[0m"
		
		# Try to parse the color string
		if LoggieTools.NamedColors.has(color_str):
			color = LoggieTools.NamedColors[color_str]
		else:
			color = Color(color_str)
		
		if color:
			color_code = color_to_ANSI(color)
		else:
			color_code = ""
			reset_code = ""
		
		var replacement = color_code + match.get_string(2) + reset_code
		text = text.replace(match.get_string(0), replacement)
	
	# Process bold and italic tags.
	var bold_on = "\u001b[1m"
	var bold_off = "\u001b[22m"
	var italic_on = "\u001b[3m"
	var italic_off = "\u001b[23m"

	text = text.replace("[b]", bold_on).replace("[/b]", bold_off)
	text = text.replace("[i]", italic_on).replace("[/i]", italic_off)

	# Remove any other BBCode tags but retain the text between them.
	var regex_bbcode = RegEx.new()
	regex_bbcode.compile("\\[(b|/b|i|/i|color=[^\\]]+|/color)\\]")
	text = regex_bbcode.sub(text, "", true)

	return text

## Returns a dictionary of call stack data related to the stack the call to this function is a part of.
## This function only works in debug builds, and on the main thread, because it uses [method get_stack].
## Read more about why in that function's documentation.
static func get_current_stack_frame_data() -> Dictionary:
	var stack = get_stack()
	if stack.size() > 0:
		stack.reverse()
		# Prune the frames starting from the first one that comes from loggie_message and onwards.
		var pruned_stack = []
		for index in stack.size():
			var source : String = stack[index].source
			var prune_breakpoint_files = ["loggie", "loggie_message"]
			if prune_breakpoint_files.has(source.get_file().get_basename()):
				break
			pruned_stack.push_back(stack[index])
		
		# The back-most remaining entry in the pruned stack is the first non-Loggie caller.
		if pruned_stack.size() >= 1:
			return pruned_stack.back()

	return {
		"source" : "UnknownStackFrameSource",
		"line" : 0,
		"function" : "UnknownFunction"
	}

## Returns the `class_name` of a script.
## [br][param path_or_script] should be either an absolute path to the script 
## (String, e.g. "res://my_script.gd"), or a [Script] object.
## [br][param proxy] defines which kind of text will be used as a replacement
## for the class name if the script has no 'class_name'.
static func get_class_name_from_script(path_or_script : Variant, proxy : LoggieEnums.NamelessClassExtensionNameProxy) -> String:
	var script
	var _class_name = ""

	if path_or_script is String or path_or_script is StringName:
		if !ResourceLoader.exists(path_or_script, "Script"):
			return _class_name
		script = load(path_or_script)
	elif path_or_script is Script:
		script = path_or_script

	if not (script is Script):
		push_error("Invalid 'path_or_script' param provided to get_class_name_from_script: {path}".format({"path" : path_or_script}))
	else:
		if not script.has_method("get_global_name"):
			# User is using a pre-4.3 version of Godot that doesn't have Script.get_global_name.
			# We must use a different method to achieve this then.
			return extract_class_name_from_gd_script(path_or_script, proxy)

		# Try to get the class name directly.
		_class_name = script.get_global_name()

		if _class_name != "":
			return _class_name

		# If that's empty, the script is either a base class, or a class without a name.
		# Check if this script has a base script, and if so, use that one as the target whose name to obtain.
		# If it doesn't have it, use what the [param proxy] demands.
		var base_script = script.get_base_script()
		if base_script != null:
			return get_class_name_from_script(base_script, proxy)
		else:
			match proxy:
				LoggieEnums.NamelessClassExtensionNameProxy.BASE_TYPE:
					_class_name = script.get_instance_base_type()
				LoggieEnums.NamelessClassExtensionNameProxy.SCRIPT_NAME:
					_class_name = script.get_script_property_list().front()["name"]

	return _class_name

## Opens and reads a .gd script file to find out its 'class_name' or what it 'extends'.
## [param path_or_script] should be either an absolute path to the script 
## (String, e.g. "res://my_script.gd"), or a [Script] object.
## [br][param proxy] defines which kind of text will be used as a replacement
## for the class name if the script has no 'class_name'.
## [br][br][b]Note:[/b] This is a compatibility method that will be used on older versions of Godot which
## don't support [method Script.get_global_name].
static func extract_class_name_from_gd_script(path_or_script : Variant, proxy : LoggieEnums.NamelessClassExtensionNameProxy) -> String:
	var path : String

	if path_or_script is String:
		path = path_or_script
	elif path_or_script is Script:
		path = path_or_script.resource_path
	else:
		push_error("Invalid 'path_or_script' param provided to extract_class_name_from_gd_script: {path}".format({"path" : path_or_script}))
		return ""

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return "File Open Error {filepath}".format({"filepath" : path})

	var _class_name: String = ""

	for line_num in 40:  # Loop only up to 40 lines
		if file.eof_reached():
			break

		var line = file.get_line().strip_edges()

		if line.begins_with("class_name"):
			_class_name = line.split(" ")[1]
			break

	if _class_name == "":
		var script = load(path)
		if script is Script:
			match proxy:
				LoggieEnums.NamelessClassExtensionNameProxy.BASE_TYPE:
					_class_name = script.get_instance_base_type()
				LoggieEnums.NamelessClassExtensionNameProxy.SCRIPT_NAME:
					_class_name = script.get_script_property_list().front()["name"]

	file.close()
	return _class_name

## Takes the given [param string] and returns an array made out of chunks of the given size.
## The string is chunked from start to end.
static func chunk_string(string : String, chunk_size : int) -> Array:
	var message_chunks = []
	if string.length() >= chunk_size:
		# Cut chunk_size pieces from the left side of the string and push them to message_chunks.
		while string.length() >= chunk_size:
			message_chunks.append(string.left(chunk_size))
			string = string.substr(chunk_size, -1)
			
		# Append the remaining slice as the final chunk.
		if string.length() > 0:
			message_chunks.append(string)
		return message_chunks
	else:
		return [string]

## Copies the directory at the given [param path_dir_to_copy] path and places the copy at the given [param path_dir_to_copy_into] path.
## Returns a dictionary with 2 keys:
##[codeblock]
##`errors` : Array[Error] # An array of all errors that occured during the process. ('Error.OK' is an exception and won't be included here)
##`messages` : Array[LoggieMsg] # An array of messages describing the process, including informational or error related content.
##[/codeblock]
static func copy_dir_absolute(path_dir_to_copy: String, path_dir_to_copy_into: String, overwrite_existing_files_with_same_name : bool = false) -> Dictionary:
	const debug_enabled = false
	var result = {
		"errors" : [],
		"messages" : []
	}
	
	# Ensure source directory is openable.
	var source_dir = DirAccess.open(path_dir_to_copy)
	if source_dir == null:
		var open_error = DirAccess.get_open_error()
		result.errors.push_back(open_error)
		result.messages.push_back(LoggieMsg.new("Failed to open source directory: ", path_dir_to_copy, " with error: ", error_string(open_error)))
		return result

	# Ensure target directory is openable.
	var target_dir = DirAccess.open(path_dir_to_copy_into)
	var target_dir_path_abs = ProjectSettings.globalize_path(path_dir_to_copy_into)
	if target_dir == null:
		var msg = LoggieMsg.new("📂 Target directory not found - creating it at:").msg(path_dir_to_copy_into).color(Color.CADET_BLUE)
		result.messages.push_back(msg)
		DirAccess.make_dir_recursive_absolute(path_dir_to_copy_into)
		target_dir = DirAccess.open(path_dir_to_copy_into)

	# Copy all files from the current source directory into the target directory.
	for file_name : String in source_dir.get_files():
		var file_path_abs = ProjectSettings.globalize_path(path_dir_to_copy.path_join(file_name))
		var target_file_path_abs = target_dir_path_abs.path_join(file_name)
		var copying_msg = LoggieMsg.new("📝 Copying file...")
		copying_msg.msg(file_path_abs).italic().color(Color.CORNFLOWER_BLUE).add(" -> ")
		copying_msg.msg(target_file_path_abs).bold().color(Color.CORNFLOWER_BLUE)
		
		var is_overwrite_required = false
		if FileAccess.file_exists(target_file_path_abs):
			is_overwrite_required = true
			if overwrite_existing_files_with_same_name:
				copying_msg.nl().msg("\t[!] Target file already exists and will be overwritten.").bold().color(Color.DARK_KHAKI)
			else:
				copying_msg.nl().msg("\t🛑 File will not be copied as overwriting existing files is disabled.").bold().color(Color.SALMON)

		result.messages.push_back(copying_msg)
		
		if (not is_overwrite_required) or (is_overwrite_required and overwrite_existing_files_with_same_name):
			var copy_error = DirAccess.copy_absolute(file_path_abs, target_file_path_abs)
			if copy_error != OK:
				result.errors.push_back(copy_error)
				result.messages.push_back(LoggieMsg.new("Attempt to copy file failed with error: '", error_string(copy_error)))

	# Create all of source directory's subdirectories in the target directory and copy their contents.
	for dir_name : String in source_dir.get_directories():
		var source_subdir_path = path_dir_to_copy.path_join(dir_name)
		var source_subdir_path_abs = ProjectSettings.globalize_path(source_subdir_path)
		var target_subdir_path = path_dir_to_copy_into.path_join(dir_name)
		var dir_path_abs = ProjectSettings.globalize_path(target_subdir_path)

		result.messages.push_back(LoggieMsg.new("📂 Creating directory: ").msg("{dir}".format({"dir": dir_path_abs})).color(Color.CADET_BLUE))
		var make_dir_error = DirAccess.make_dir_recursive_absolute(dir_path_abs)
		if make_dir_error != OK:
			result.errors.push_back(make_dir_error)
			var error_msg = LoggieMsg.new("Attempt to create directory at absolute path recursively failed with error: '", error_string(make_dir_error))
			result.messages.push_back(error_msg)
			continue

		# Recursively copy the contents of the subdirectory
		var subdir_copy_result = copy_dir_absolute(source_subdir_path_abs, target_subdir_path, overwrite_existing_files_with_same_name)
		result.errors = result.errors + subdir_copy_result.errors
		result.messages = result.messages + subdir_copy_result.messages
	
	if debug_enabled:
		for msg : LoggieMsg in result.messages:
			print_rich(msg.string())
			
	return result

## A dictionary of named colors matching the constants from [Color] used to help with rich text coloring.
## There may be a way to obtain these Color values without this dictionary if one can somehow check for the 
## existence and value of a constant on the Color class (since they're already there),
## but I can't seem to find a way, so this will have to do for now.
static var NamedColors = {
	"ALICE_BLUE": Color(0.941176, 0.972549, 1, 1),
	"ANTIQUE_WHITE": Color(0.980392, 0.921569, 0.843137, 1),
	"AQUA": Color(0, 1, 1, 1),
	"AQUAMARINE": Color(0.498039, 1, 0.831373, 1),
	"AZURE": Color(0.941176, 1, 1, 1),
	"BEIGE": Color(0.960784, 0.960784, 0.862745, 1),
	"BISQUE": Color(1, 0.894118, 0.768627, 1),
	"BLACK": Color(0, 0, 0, 1),
	"BLANCHED_ALMOND": Color(1, 0.921569, 0.803922, 1),
	"BLUE": Color(0, 0, 1, 1),
	"BLUE_VIOLET": Color(0.541176, 0.168627, 0.886275, 1),
	"BROWN": Color(0.647059, 0.164706, 0.164706, 1),
	"BURLYWOOD": Color(0.870588, 0.721569, 0.529412, 1),
	"CADET_BLUE": Color(0.372549, 0.619608, 0.627451, 1),
	"CHARTREUSE": Color(0.498039, 1, 0, 1),
	"CHOCOLATE": Color(0.823529, 0.411765, 0.117647, 1),
	"CORAL": Color(1, 0.498039, 0.313726, 1),
	"CORNFLOWER_BLUE": Color(0.392157, 0.584314, 0.929412, 1),
	"CORNSILK": Color(1, 0.972549, 0.862745, 1),
	"CRIMSON": Color(0.862745, 0.0784314, 0.235294, 1),
	"CYAN": Color(0, 1, 1, 1),
	"DARK_BLUE": Color(0, 0, 0.545098, 1),
	"DARK_CYAN": Color(0, 0.545098, 0.545098, 1),
	"DARK_GOLDENROD": Color(0.721569, 0.52549, 0.0431373, 1),
	"DARK_GRAY": Color(0.662745, 0.662745, 0.662745, 1),
	"DARK_GREEN": Color(0, 0.392157, 0, 1),
	"DARK_KHAKI": Color(0.741176, 0.717647, 0.419608, 1),
	"DARK_MAGENTA": Color(0.545098, 0, 0.545098, 1),
	"DARK_OLIVE_GREEN": Color(0.333333, 0.419608, 0.184314, 1),
	"DARK_ORANGE": Color(1, 0.54902, 0, 1),
	"DARK_ORCHID": Color(0.6, 0.196078, 0.8, 1),
	"DARK_RED": Color(0.545098, 0, 0, 1),
	"DARK_SALMON": Color(0.913725, 0.588235, 0.478431, 1),
	"DARK_SEA_GREEN": Color(0.560784, 0.737255, 0.560784, 1),
	"DARK_SLATE_BLUE": Color(0.282353, 0.239216, 0.545098, 1),
	"DARK_SLATE_GRAY": Color(0.184314, 0.309804, 0.309804, 1),
	"DARK_TURQUOISE": Color(0, 0.807843, 0.819608, 1),
	"DARK_VIOLET": Color(0.580392, 0, 0.827451, 1),
	"DEEP_PINK": Color(1, 0.0784314, 0.576471, 1),
	"DEEP_SKY_BLUE": Color(0, 0.74902, 1, 1),
	"DIM_GRAY": Color(0.411765, 0.411765, 0.411765, 1),
	"DODGER_BLUE": Color(0.117647, 0.564706, 1, 1),
	"FIREBRICK": Color(0.698039, 0.133333, 0.133333, 1),
	"FLORAL_WHITE": Color(1, 0.980392, 0.941176, 1),
	"FOREST_GREEN": Color(0.133333, 0.545098, 0.133333, 1),
	"FUCHSIA": Color(1, 0, 1, 1),
	"GAINSBORO": Color(0.862745, 0.862745, 0.862745, 1),
	"GHOST_WHITE": Color(0.972549, 0.972549, 1, 1),
	"GOLD": Color(1, 0.843137, 0, 1),
	"GOLDENROD": Color(0.854902, 0.647059, 0.12549, 1),
	"GRAY": Color(0.745098, 0.745098, 0.745098, 1),
	"GREEN": Color(0, 1, 0, 1),
	"GREEN_YELLOW": Color(0.678431, 1, 0.184314, 1),
	"HONEYDEW": Color(0.941176, 1, 0.941176, 1),
	"HOT_PINK": Color(1, 0.411765, 0.705882, 1),
	"INDIAN_RED": Color(0.803922, 0.360784, 0.360784, 1),
	"INDIGO": Color(0.294118, 0, 804, 1),
	"IVORY": Color(1, 1, 0.941176, 1),
	"KHAKI": Color(0.941176, 0.901961, 0.54902, 1),
	"LAVENDER": Color(0.901961, 0.901961, 0.980392, 1),
	"LAVENDER_BLUSH": Color(1, 0.941176, 0.960784, 1),
	"LAWN_GREEN": Color(0.486275, 0.988235, 0, 1),
	"LEMON_CHIFFON": Color(1, 0.980392, 0.803922, 1),
	"LIGHT_BLUE": Color(0.678431, 0.847059, 0.901961, 1),
	"LIGHT_CORAL": Color(0.941176, 0.501961, 0.501961, 1),
	"LIGHT_CYAN": Color(0.878431, 1, 1, 1),
	"LIGHT_GOLDENROD": Color(0.980392, 0.980392, 0.823529, 1),
	"LIGHT_GRAY": Color(0.827451, 0.827451, 0.827451, 1),
	"LIGHT_GREEN": Color(0.564706, 0.933333, 0.564706, 1),
	"LIGHT_PINK": Color(1, 0.713726, 0.756863, 1),
	"LIGHT_SALMON": Color(1, 0.627451, 0.478431, 1),
	"LIGHT_SEA_GREEN": Color(0.12549, 0.698039, 0.666667, 1),
	"LIGHT_SKY_BLUE": Color(0.529412, 0.807843, 0.980392, 1),
	"LIGHT_SLATE_GRAY": Color(0.466667, 0.533333, 0.6, 1),
	"LIGHT_STEEL_BLUE": Color(0.690196, 0.768627, 0.870588, 1),
	"LIGHT_YELLOW": Color(1, 1, 0.878431, 1),
	"LIME": Color(0, 1, 0, 1),
	"LIME_GREEN": Color(0.196078, 0.803922, 0.196078, 1),
	"LINEN": Color(0.980392, 0.941176, 0.901961, 1),
	"MAGENTA": Color(1, 0, 1, 1),
	"MAROON": Color(0.690196, 0.188235, 0.376471, 1),
	"MEDIUM_AQUAMARINE": Color(0.4, 0.803922, 0.666667, 1),
	"MEDIUM_BLUE": Color(0, 0, 0.803922, 1),
	"MEDIUM_ORCHID": Color(0.729412, 0.333333, 0.827451, 1),
	"MEDIUM_PURPLE": Color(0.576471, 0.439216, 0.858824, 1),
	"MEDIUM_SEA_GREEN": Color(0.235294, 0.701961, 0.443137, 1),
	"MEDIUM_SLATE_BLUE": Color(0.482353, 0.407843, 0.933333, 1),
	"MEDIUM_SPRING_GREEN": Color(0, 0.980392, 0.603922, 1),
	"MEDIUM_TURQUOISE": Color(0.282353, 0.819608, 0.8, 1),
	"MEDIUM_VIOLET_RED": Color(0.780392, 0.0823529, 0.521569, 1),
	"MIDNIGHT_BLUE": Color(0.0980392, 0.0980392, 0.439216, 1),
	"MINT_CREAM": Color(0.960784, 1, 0.980392, 1),
	"MISTY_ROSE": Color(1, 0.894118, 0.882353, 1),
	"MOCCASIN": Color(1, 0.894118, 0.709804, 1),
	"NAVAJO_WHITE": Color(1, 0.870588, 0.678431, 1),
	"NAVY_BLUE": Color(0, 0, 0.501961, 1),
	"OLD_LACE": Color(0.992157, 0.960784, 0.901961, 1),
	"OLIVE": Color(0.501961, 0.501961, 0, 1),
	"OLIVE_DRAB": Color(0.419608, 0.556863, 0.137255, 1),
	"ORANGE": Color(1, 0.647059, 0, 1),
	"ORANGE_RED": Color(1, 0.270588, 0, 1),
	"ORCHID": Color(0.854902, 0.439216, 0.839216, 1),
	"PALE_GOLDENROD": Color(0.933333, 0.909804, 0.666667, 1),
	"PALE_GREEN": Color(0.596078, 0.984314, 0.596078, 1),
	"PALE_TURQUOISE": Color(0.686275, 0.933333, 0.933333, 1),
	"PALE_VIOLET_RED": Color(0.858824, 0.439216, 0.576471, 1),
	"PAPAYA_WHIP": Color(1, 0.937255, 0.835294, 1),
	"PEACH_PUFF": Color(1, 0.854902, 0.72549, 1),
	"PERU": Color(0.803922, 0.521569, 0.247059, 1),
	"PINK": Color(1, 0.752941, 0.796078, 1),
	"PLUM": Color(0.866667, 0.627451, 0.866667, 1),
	"POWDER_BLUE": Color(0.690196, 0.878431, 0.901961, 1),
	"PURPLE": Color(0.627451, 0.12549, 0.941176, 1),
	"REBECCA_PURPLE": Color(0.4, 0.2, 0.6, 1),
	"RED": Color(1, 0, 0, 1),
	"ROSY_BROWN": Color(0.737255, 0.560784, 0.560784, 1),
	"ROYAL_BLUE": Color(0.254902, 0.411765, 0.882353, 1),
	"SADDLE_BROWN": Color(0.545098, 0.270588, 0.0745098, 1),
	"SALMON": Color(0.980392, 0.501961, 0.447059, 1),
	"SANDY_BROWN": Color(0.956863, 0.643137, 0.376471, 1),
	"SEA_GREEN": Color(0.180392, 0.545098, 0.341176, 1),
	"SEASHELL": Color(1, 0.960784, 0.933333, 1),
	"SIENNA": Color(0.627451, 0.321569, 0.176471, 1),
	"SILVER": Color(0.752941, 0.752941, 0.752941, 1),
	"SKY_BLUE": Color(0.529412, 0.807843, 0.921569, 1),
	"SLATE_BLUE": Color(0.415686, 0.352941, 0.803922, 1),
	"SLATE_GRAY": Color(0.439216, 0.501961, 0.564706, 1),
	"SNOW": Color(1, 0.980392, 0.980392, 1),
	"SPRING_GREEN": Color(0, 1, 0.498039, 1),
	"STEEL_BLUE": Color(0.27451, 0.509804, 0.705882, 1),
	"TAN": Color(0.823529, 0.705882, 0.54902, 1),
	"TEAL": Color(0, 0.501961, 0.501961, 1),
	"THISTLE": Color(0.847059, 0.74902, 0.847059, 1),
	"TOMATO": Color(1, 0.388235, 0.278431, 1),
	"TRANSPARENT": Color(1, 1, 1, 0),
	"TURQUOISE": Color(0.25098, 0.878431, 0.815686, 1),
	"VIOLET": Color(0.933333, 0.509804, 0.933333, 1),
	"WEB_GRAY": Color(0.501961, 0.501961, 0.501961, 1),
	"WEB_GREEN": Color(0, 0.501961, 0, 1),
	"WEB_MAROON": Color(0.501961, 0, 0, 1),
	"WEB_PURPLE": Color(0.501961, 0, 0.501961, 1),
	"WHEAT": Color(0.960784, 0.870588, 0.701961, 1),
	"WHITE": Color(1, 1, 1, 1),
	"WHITE_SMOKE": Color(0.960784, 0.960784, 0.960784, 1),
	"YELLOW": Color(1, 1, 0, 1),
	"YELLOW_GREEN": Color(0.603922, 0.803922, 0.196078, 1)
}
