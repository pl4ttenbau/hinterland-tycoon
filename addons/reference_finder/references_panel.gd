@tool
extends VBoxContainer

var editor_interface: EditorInterface

var title_label: Label
var results_tree: Tree
var status_label: Label

# editors theme colors
var color_file_path: Color
var color_line_number: Color
var color_code_text: Color
var color_count: Color

func _ready():
    name = "ReferencesPanel"
    
    # Get editor theme colors
    _load_theme_colors()
    
    # Title
    title_label = Label.new()
    title_label.text = "References"
    title_label.add_theme_font_size_override("font_size", 16)
    add_child(title_label)
    
    # Tree for results
    results_tree = Tree.new()
    results_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    results_tree.hide_root = true
    results_tree.columns = 3
    results_tree.set_column_title(0, "File")
    results_tree.set_column_title(1, "Line")
    results_tree.set_column_title(2, "Code")
    results_tree.set_column_expand(0, false)
    results_tree.set_column_expand(1, false)
    results_tree.set_column_expand(2, true)
    results_tree.set_column_custom_minimum_width(0, 250)
    results_tree.set_column_custom_minimum_width(1, 50)
    results_tree.item_activated.connect(_on_item_activated)
    add_child(results_tree)
    
    # Status label
    status_label = Label.new()
    status_label.text = "No search performed"
    add_child(status_label)

func _load_theme_colors():
    # trying to get editor theme colors / fallback to default colors
    if editor_interface:
        var base_control = editor_interface.get_base_control()
        if base_control:
            # File paths: use member variable color (cyan/blue)
            color_file_path = base_control.get_theme_color("member_variable_color", "Editor")
            if color_file_path == Color.BLACK or color_file_path.a == 0:
                color_file_path = Color(0.4, 0.7, 1.0)  # Light blue fallback
            
            # Line numbers: use line number color
            color_line_number = base_control.get_theme_color("line_number_color", "Editor")
            if color_line_number == Color.BLACK or color_line_number.a == 0:
                color_line_number = Color(0.67, 0.78, 0.67, 0.6)  # Grayish green fallback
            
            # Code text: use normal text color but slightly dimmed
            color_code_text = base_control.get_theme_color("font_color", "Editor")
            if color_code_text == Color.BLACK or color_code_text.a == 0:
                color_code_text = Color(0.9, 0.9, 0.9)  # Light gray fallback
            
            # Count: use keyword color (pink/magenta)
            color_count = base_control.get_theme_color("keyword_color", "Editor")
            if color_count == Color.BLACK or color_count.a == 0:
                color_count = Color(1.0, 0.44, 0.52)  # Pink fallback
            
            return
    
    # Fallback colors if we can not get the theme colors
    color_file_path = Color(0.4, 0.7, 1.0)  # Cyan
    color_line_number = Color(0.67, 0.78, 0.67, 0.6)  # Gray-green
    color_code_text = Color(0.9, 0.9, 0.9)  # Light gray
    color_count = Color(1.0, 0.44, 0.52)  # Pink

func show_references(token: String, references: Array):
    results_tree.clear()
    
    # Reload colors in case theme has changed
    _load_theme_colors()
    
    if references.is_empty():
        title_label.text = "References to '%s': None found" % token
        status_label.text = "No references found"
        return
    
    title_label.text = "References to '%s': %d found" % [token, references.size()]
    status_label.text = "%d references found" % references.size()
    
    var root = results_tree.create_item()
    
    # Group by file
    var files_dict = {}
    for ref in references:
        var file = ref.file
        if not files_dict.has(file):
            files_dict[file] = []
        files_dict[file].append(ref)
    
    # Create tree items
    for file in files_dict.keys():
        var file_item = results_tree.create_item(root)
        var short_file = file.replace("res://", "")
        
        # Set file path with cyan color
        file_item.set_text(0, short_file)
        file_item.set_custom_color(0, color_file_path)
        
        # Set count with pink/keyword color
        file_item.set_text(1, "(%d)" % files_dict[file].size())
        file_item.set_custom_color(1, color_count)
        
        file_item.set_metadata(0, null)  # File items have no metadata
        
        for ref in files_dict[file]:
            var ref_item = results_tree.create_item(file_item)
            ref_item.set_text(0, "")
            
            # Set line number with line number color
            ref_item.set_text(1, str(ref.line))
            ref_item.set_custom_color(1, color_line_number)
            
            # Set code text with normal editor text color
            ref_item.set_text(2, ref.text)
            ref_item.set_custom_color(2, color_code_text)
            
            ref_item.set_metadata(0, ref)  # Store reference data

func _on_item_activated():
    var selected = results_tree.get_selected()
    if not selected:
        return
    
    var ref = selected.get_metadata(0)
    if not ref:
        # This is a file item, not a reference / Ignore
        return
    
    # Open the file at the specified line
    if editor_interface:
        var script = load(ref.file)
        if script:
            editor_interface.edit_script(script, ref.line, 0, true)
            editor_interface.set_main_screen_editor("Script")
