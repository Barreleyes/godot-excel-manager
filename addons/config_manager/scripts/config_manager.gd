@tool
extends Control

const ExcelStructure = preload("res://addons/config_manager/scripts/excel_structure.gd")
const ExcelParser = preload("res://addons/config_manager/scripts/excel_parser.gd")
const CodeGenerator = preload("res://addons/config_manager/scripts/code_generator.gd")
const EnumStructure = preload("res://addons/config_manager/scripts/enum_structure.gd")
const EnumParser = preload("res://addons/config_manager/scripts/enum_parser.gd")
const EnumValueRowScene = preload("res://addons/config_manager/ui/enum_value_row.tscn")

# 主要组件引用
@onready var toolbar: HBoxContainer = $VBoxContainer/Toolbar
@onready var content_area: HSplitContainer = $VBoxContainer/ContentArea
@onready var property_panel: Control = $VBoxContainer/ContentArea/RightPanel

# 工具栏按钮
@onready var search_edit: LineEdit = $VBoxContainer/Toolbar/SearchEdit
@onready var regenerate_btn: Button = $VBoxContainer/Toolbar/RegenerateBtn
@onready var export_json_btn: Button = $VBoxContainer/Toolbar/ExportJsonBtn
@onready var config_btn: Button = $VBoxContainer/Toolbar/ConfigBtn
#打开导出的类定义文件
@onready var open_table_classes_btn:Button=$VBoxContainer/Toolbar/OpenCode
#打开enum定义文件
@onready var open_enum_btn:Button=$VBoxContainer/Toolbar/OpenEnumFile
#在资源管理器中打开json文件夹
@onready var open_json_folder_btn:Button=$VBoxContainer/Toolbar/OpenJsonFolder
#在资源管理器中打开excel文件夹
@onready var open_excel_folder_btn:Button=$VBoxContainer/Toolbar/OpenExcelFolder

#右侧面板
@onready var info_label: Label = $VBoxContainer/ContentArea/RightPanel/InfoLabel
@onready var property_view_switcher:TabContainer=$VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher

# 右侧面板/Excel属性=1
@onready var new_excel_btn: Button = $"VBoxContainer/ContentArea/LeftPanel/TabContainer/Excel管理/Control/HBoxContainer/NewExcelBtn"
@onready var table_properties: Control = $VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/TableProperties
@onready var field_list: VBoxContainer = $VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/TableProperties/FieldListContainer/FieldList
@onready var copy_structure_btn: Button = $VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/TableProperties/HBoxContainer/CopyBtn
@onready var export_selected_excel_btn:Button=$VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/TableProperties/FieldToolbar/ExportFileJson
@onready var open_selectec_excel_btn:Button=$VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/TableProperties/FieldToolbar/OpenExcel
@onready var copy_used_enum_define_btn:Button=$VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/TableProperties/HBoxContainer/CopyEnumDefine
# 右侧面板/Enum属性=2
@onready var add_enum_value_btn:Button = $VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/EnumProperties/Toolbar/AddEnumValue
@onready var enum_value_list: VBoxContainer = $VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/EnumProperties/EnumListContainer/EnumValueList
@onready var save_enum_btn:Button=$VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/EnumProperties/SaveBtn
@onready var is_flag_checkbox:CheckBox=$VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/EnumProperties/Control/IsFlag
@onready var del_enum: Button = $VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/EnumProperties/Toolbar/DelEnum

# 左侧面板/Excel管理
@onready var new_folder_btn: Button = $"VBoxContainer/ContentArea/LeftPanel/TabContainer/Excel管理/Control/HBoxContainer/NewFolderBtn"
@onready var add_field_btn: Button = $VBoxContainer/ContentArea/RightPanel/PropertyViewSwitcher/TableProperties/FieldToolbar/AddFieldBtn
@onready var refresh_btn: Button = $"VBoxContainer/ContentArea/LeftPanel/TabContainer/Excel管理/Control/HBoxContainer/RefreshButton"
@onready var file_tree: Tree = $"VBoxContainer/ContentArea/LeftPanel/TabContainer/Excel管理/FileTree"
# 左侧面板/Enum管理
@onready var new_enum_btn:Button = $"VBoxContainer/ContentArea/LeftPanel/TabContainer/Enum管理/Control/HBoxContainer/NewEnum"
@onready var refresh_enum:Button = $"VBoxContainer/ContentArea/LeftPanel/TabContainer/Enum管理/Control/HBoxContainer/RefreshButton"
@onready var enum_tree:Tree = $"VBoxContainer/ContentArea/LeftPanel/TabContainer/Enum管理/EnumTree"



# 对话框和菜单
@onready var file_context_menu: PopupMenu = $FileContextMenu

# 插件引用
var plugin: EditorPlugin
var editor_interface: EditorInterface
var editor_plugin: EditorPlugin

# 配置
var excel_root_path: String = "res://Configs/"
var class_definitions_path: String = "res://Scripts/ConfigClasses/"
var json_export_path: String = "res://Configs/Json/"
var enum_path: String = "res://Scripts/Enums/"

# 当前选中项
var selected_item_path: String = ""
var selected_item_type: String = "" # "folder", "excel", "none"
var current_excel_structure: ExcelStructure

# 枚举管理相关
var selected_enum_name: String = ""
var current_enum_structure: EnumStructure
var enum_file_path: String = ""  # 固定的枚举文件路径
var all_enums: Array[EnumStructure] = []
# 对话框
var config_dialog: AcceptDialog
const ConfigDialog = preload("res://addons/config_manager/ui/config_dialog.tscn")

# 拖拽相关
var drag_data: Dictionary = {}
var drag_preview: Control

func _ready():
	_setup_ui()
	_connect_signals()
	_load_settings()
	_refresh_file_tree()
	_refresh_enum_tree()
	_setup_dialogs()
	
	# 设置拖拽功能
	_setup_drag_functionality()

func _setup_drag_functionality():
	if file_tree.has_method("setup"):
		file_tree.setup(self)

# 公共方法供拖拽树调用
func refresh_file_tree():
	_refresh_file_tree()

func set_plugin(p_plugin: EditorPlugin):
	plugin = p_plugin
	editor_interface = plugin.get_editor_interface_ref()

func _setup_ui():
	# 设置基本布局
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 初始化右侧面板
	_update_property_panel()

func _connect_signals():
	# 工具栏信号连接
	search_edit.text_changed.connect(_on_search_text_changed)
	regenerate_btn.pressed.connect(_on_regenerate_pressed)
	export_json_btn.pressed.connect(_on_export_json_pressed)
	new_folder_btn.pressed.connect(_on_new_folder_pressed)
	
	# 新增按钮信号连接
	open_table_classes_btn.pressed.connect(_on_open_table_classes_pressed)
	open_enum_btn.pressed.connect(_on_open_enum_pressed)
	open_json_folder_btn.pressed.connect(_on_open_json_folder_pressed)
	open_excel_folder_btn.pressed.connect(_on_open_excel_folder_pressed)
	new_excel_btn.pressed.connect(_on_new_excel_pressed)
	config_btn.pressed.connect(_on_config_pressed)
	
	# 文件树信号连接
	file_tree.item_selected.connect(_on_file_tree_item_selected)
	file_tree.item_activated.connect(_on_file_tree_item_activated)  # 双击
	file_tree.item_mouse_selected.connect(_on_file_tree_item_mouse_selected)  # 右键
	# 添加GUI输入处理来捕获右键点击
	file_tree.gui_input.connect(_on_file_tree_gui_input)
	
	# 表结构相关按钮
	copy_structure_btn.pressed.connect(_on_copy_structure_pressed)
	add_field_btn.pressed.connect(_on_add_field_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	export_selected_excel_btn.pressed.connect(_on_export_selected_excel_pressed)
	copy_used_enum_define_btn.pressed.connect(_on_copy_used_enum_define_pressed)
	open_selectec_excel_btn.pressed.connect(_on_open_selected_excel_pressed)
	
	# 枚举管理相关按钮
	new_enum_btn.pressed.connect(_on_new_enum_pressed)
	refresh_enum.pressed.connect(_on_refresh_enum_pressed)
	add_enum_value_btn.pressed.connect(_on_add_enum_value_pressed)
	save_enum_btn.pressed.connect(_on_save_enum_pressed)
	is_flag_checkbox.toggled.connect(_on_is_flag_toggled)
	del_enum.pressed.connect(_on_del_enum_pressed)
	
	# 枚举树信号连接
	enum_tree.item_selected.connect(_on_enum_tree_item_selected)
	
	# 右键菜单信号
	file_context_menu.id_pressed.connect(_on_context_menu_selected)
	
	# 设置快捷键处理
	set_process_unhandled_key_input(true)

func _load_settings():
	# 从项目设置加载配置
	if ProjectSettings.has_setting("config_manager/excel_root_path"):
		excel_root_path = ProjectSettings.get_setting("config_manager/excel_root_path", "res://Configs/")
	if ProjectSettings.has_setting("config_manager/class_definitions_path"):
		class_definitions_path = ProjectSettings.get_setting("config_manager/class_definitions_path", "res://Scripts/ConfigClasses/")
	if ProjectSettings.has_setting("config_manager/json_export_path"):
		json_export_path = ProjectSettings.get_setting("config_manager/json_export_path", "res://Configs/Json/")
	if ProjectSettings.has_setting("config_manager/enum_path"):
		enum_path = ProjectSettings.get_setting("config_manager/enum_path", "res://Scripts/Enums/")

func _save_settings():
	# 保存配置到项目设置
	ProjectSettings.set_setting("config_manager/excel_root_path", excel_root_path)
	ProjectSettings.set_setting("config_manager/class_definitions_path", class_definitions_path)
	ProjectSettings.set_setting("config_manager/json_export_path", json_export_path)
	ProjectSettings.set_setting("config_manager/enum_path", enum_path)
	ProjectSettings.save()

func _refresh_file_tree():
	file_tree.clear()
	var root = file_tree.create_item()
	root.set_text(0, "配置文件")
	root.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
	
	# 如果目录不存在，创建它
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(excel_root_path):
		dir.make_dir_recursive(excel_root_path)
	
	_populate_tree_item(root, excel_root_path)
	root.set_collapsed(false)

func _populate_tree_item(parent_item: TreeItem, dir_path: String):
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	var folders = []
	var files = []
	
	# 分别收集文件夹和文件
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			folders.append(file_name)
		elif file_name.ends_with(".xlsx") or file_name.ends_with(".xls"):
			files.append(file_name)
		file_name = dir.get_next()
	
	# 先添加文件夹
	folders.sort()
	for folder in folders:
		var folder_item = file_tree.create_item(parent_item)
		folder_item.set_text(0, folder)
		folder_item.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
		folder_item.set_metadata(0, {"type": "folder", "path": dir_path.path_join(folder)})
		_populate_tree_item(folder_item, dir_path.path_join(folder))
	
	# 再添加文件
	files.sort()
	for file in files:
		var file_item = file_tree.create_item(parent_item)
		file_item.set_text(0, file)
		file_item.set_icon(0, get_theme_icon("FileList", "EditorIcons"))
		file_item.set_metadata(0, {"type": "excel", "path": dir_path.path_join(file)})

func _update_property_panel():
	match selected_item_type:
		"none":
			property_view_switcher.current_tab=0
			_show_general_info()
		"folder":
			property_view_switcher.current_tab=0
			_show_folder_info()
		"excel":
			property_view_switcher.current_tab=1
			_show_excel_info()

func _show_general_info():
	info_label.show()
	table_properties.hide()
	
	var excel_count = _count_excel_files(excel_root_path)
	info_label.text = "总Excel文件数: %d" % excel_count

func _show_folder_info():
	info_label.show()
	table_properties.hide()
	
	var excel_count = _count_excel_files(selected_item_path)
	info_label.text = "目录下Excel文件数: %d" % excel_count

func _show_excel_info():
	info_label.hide()
	table_properties.show()
	
	# 解析并显示Excel文件的表结构
	current_excel_structure = ExcelParser.parse_excel_structure(selected_item_path)
	_populate_structure_list()

func _count_excel_files(path: String) -> int:
	var count = 0
	var dir = DirAccess.open(path)
	if dir == null:
		return 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			count += _count_excel_files(path.path_join(file_name))
		elif file_name.ends_with(".xlsx") or file_name.ends_with(".xls"):
			count += 1
		file_name = dir.get_next()
	
	return count

func _setup_dialogs():
	config_dialog = ConfigDialog.instantiate()
	add_child(config_dialog)
	config_dialog.settings_changed.connect(_on_settings_changed)
	
	# 设置右键菜单
	_setup_context_menu()

func _setup_context_menu():
	file_context_menu.clear()
	file_context_menu.add_item("打开", 0)
	file_context_menu.add_item("打开所在文件夹", 1)
	file_context_menu.add_item("重命名", 2)
	file_context_menu.set_item_accelerator(2, KEY_F2)
	file_context_menu.add_separator()
	file_context_menu.add_item("删除", 3)

func _populate_structure_list():
	# 清空现有字段行
	for child in field_list.get_children():
		child.queue_free()
	
	# 等待下一帧再添加新内容
	await get_tree().process_frame
	
	# 添加字段行
	for i in range(current_excel_structure.fields.size()):
		var field = current_excel_structure.fields[i]
		_add_field_row(field.name, current_excel_structure.get_field_type_name_with_enum(field), field.default_value)

# 信号处理函数
func _on_search_text_changed(text: String):
	# 简单的文件名搜索过滤
	_refresh_file_tree()

func _on_regenerate_pressed():
	if CodeGenerator.generate_all_classes(excel_root_path, class_definitions_path):
		print("所有类定义已重新生成完成")
		# 刷新编辑器文件系统
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
	else:
		print("类定义生成失败")

func _on_export_json_pressed():
	if CodeGenerator.export_all_to_json(excel_root_path, json_export_path):
		print("JSON导出完成")
		# 刷新编辑器文件系统
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
	else:
		print("JSON导出失败")

func _on_new_folder_pressed():
	var folder_name = await _prompt_input("新建文件夹", "请输入文件夹名称:")
	if folder_name:
		var new_folder_path = excel_root_path.path_join(folder_name)
		var dir = DirAccess.open("res://")
		if dir.make_dir_recursive(new_folder_path) == OK:
			_refresh_file_tree()
			print("文件夹创建成功: %s" % new_folder_path)
		else:
			print("文件夹创建失败")

func _on_new_excel_pressed():
	# 获取当前选中的目录，如果没有选中则使用根目录
	var target_dir = excel_root_path
	var selected_item = file_tree.get_selected()
	
	if selected_item:
		var metadata = selected_item.get_metadata(0)
		if metadata and metadata.type == "folder":
			target_dir = metadata.path
		elif metadata and metadata.type == "excel":
			# 如果选中的是文件，使用其父目录
			target_dir = metadata.path.get_base_dir()
	
	var file_name = await _prompt_input("新建Excel文件", "请输入文件名称（不含扩展名）:")
	if file_name:
		var new_file_path = target_dir.path_join(file_name + ".xlsx")
		if _create_excel_from_template(new_file_path):
			_refresh_file_tree()
			print("Excel文件创建成功: %s" % new_file_path)
		else:
			push_error("Excel文件创建失败: %s" % new_file_path)

func _on_config_pressed():
	config_dialog.setup(self, excel_root_path, class_definitions_path, json_export_path, enum_path)
	config_dialog.popup_centered()

# 新增按钮处理函数
func _on_open_table_classes_pressed():
	var table_classes_path = class_definitions_path + "table_classes.gd"
	_open_file_in_editor(table_classes_path)

func _on_open_enum_pressed():
	var enum_file_path = enum_path + "enums.gd"
	_open_file_in_editor(enum_file_path)

func _on_open_json_folder_pressed():
	_open_folder_in_explorer(json_export_path)

func _on_open_excel_folder_pressed():
	_open_folder_in_explorer(excel_root_path)

func _on_settings_changed(new_excel_root: String, new_classes_root: String, new_json_export: String, new_enum_path: String):
	excel_root_path = new_excel_root
	class_definitions_path = new_classes_root
	json_export_path = new_json_export
	enum_path = new_enum_path
	_save_settings()
	_refresh_file_tree()
	_refresh_enum_tree()

func _on_copy_structure_pressed():
	if current_excel_structure == null:
		return
	
	# 从列表中更新结构
	_update_structure_from_list()
	
	# 生成Excel格式的表结构数据
	var clipboard_data = _generate_excel_clipboard_data()
	
	# 复制到剪贴板
	DisplayServer.clipboard_set(clipboard_data)
	
	print("表结构已复制到剪贴板，可以在Excel中粘贴")

func _on_export_selected_excel_pressed():
	# 检查是否有选中的Excel文件
	if selected_item_path.is_empty() or selected_item_type != "excel":
		push_error("请先选择一个Excel文件")
		return
	
	# 确保输出目录存在
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(json_export_path):
		dir.make_dir_recursive(json_export_path)
	
	# 导出选中的Excel文件
	var excel_file_path = selected_item_path
	print("开始导出Excel文件: %s" % excel_file_path)
	
	if CodeGenerator.export_single_json(excel_file_path, json_export_path):
		print("Excel文件导出成功: %s" % excel_file_path.get_file())
		# 刷新编辑器文件系统
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
	else:
		push_error("Excel文件导出失败: %s" % excel_file_path.get_file())

func _on_copy_used_enum_define_pressed():
	if current_excel_structure == null:
		push_error("请先选择一个Excel文件")
		return
	
	# 从列表中更新结构
	_update_structure_from_list()
	
	# 收集当前表使用的所有枚举类型
	var used_enums = _collect_used_enums()
	
	if used_enums.size() == 0:
		print("当前表未使用任何枚举类型")
		return
	
	# 生成枚举定义表格数据
	var clipboard_data = _generate_enum_definition_table(used_enums)
	
	# 复制到剪贴板
	DisplayServer.clipboard_set(clipboard_data)
	print("枚举定义已复制到剪贴板，包含 %d 个枚举类型" % used_enums.size())

func _on_open_selected_excel_pressed():
	_open_file_with_system(selected_item_path)

func _update_structure_from_list():
	if current_excel_structure == null:
		return
	
	current_excel_structure.fields.clear()
	current_excel_structure.primary_keys.clear()
	
	for child in field_list.get_children():
		if child.has_method("get_field_name"):
			var field_name = child.get_field_name()
			var type_name = child.get_field_type()
			var default_val = child.get_default_value()
			
			if field_name.is_empty():
				continue
			
			var field_type = ExcelStructure.get_field_type_from_string(type_name)
			var enum_name = ""
			
			# 如果是枚举类型，提取枚举名称
			if field_type == ExcelStructure.FieldType.ENUM:
				enum_name = ExcelStructure.get_enum_name_from_string(type_name)
			
			current_excel_structure.add_field(field_name, field_type, default_val, enum_name)

func _generate_excel_clipboard_data() -> String:
	if current_excel_structure == null or current_excel_structure.fields.is_empty():
		return ""
	
	var lines = []
	var field_names = []
	var field_types = []
	var default_values = []
	
	# 收集字段信息
	for field in current_excel_structure.fields:
		field_names.append(field.name)
		field_types.append(current_excel_structure.get_field_type_name_with_enum(field))
		default_values.append(field.default_value if field.default_value else "")
	
	# 生成三行数据：字段名、字段类型、默认值
	lines.append("\t".join(field_names))      # 第一行：字段名
	lines.append("\t".join(field_types))      # 第二行：字段类型
	lines.append("\t".join(default_values))   # 第三行：默认值
	
#	# 添加一行示例数据
#	var example_data = []
#	for i in range(field_names.size()):
#		var field = current_excel_structure.fields[i]
#		match field.type:
#			ExcelStructure.FieldType.KEY:
#				example_data.append("1")
#			ExcelStructure.FieldType.STRING, ExcelStructure.FieldType.STRING_NAME:
#				example_data.append("示例文本")
#			ExcelStructure.FieldType.INT:
#				example_data.append("100")
#			ExcelStructure.FieldType.FLOAT:
#				example_data.append("1.5")
#			ExcelStructure.FieldType.BOOL:
#				example_data.append("true")
#			ExcelStructure.FieldType.VECTOR2:
#				example_data.append("10,20")
#			ExcelStructure.FieldType.VECTOR2I:
#				example_data.append("10,20")
#			ExcelStructure.FieldType.VECTOR3:
#				example_data.append("10,20,30")
#			ExcelStructure.FieldType.VECTOR3I:
#				example_data.append("10,20,30")
#			ExcelStructure.FieldType.ARRAY_INT:
#				example_data.append("1,2,3")
#			ExcelStructure.FieldType.ARRAY_FLOAT:
#				example_data.append("1.1,2.2,3.3")
#			ExcelStructure.FieldType.ARRAY_STRING:
#				example_data.append("项目1,项目2,项目3")
#			_:
#				example_data.append("示例值")
#	
#	lines.append("\t".join(example_data))     # 第四行：示例数据
	
	# 使用换行符连接所有行
	return "\n".join(lines)

func _prompt_input(title: String, message: String, default_text: String = "") -> String:
	# 简单的输入对话框实现
	var dialog = AcceptDialog.new()
	var vbox = VBoxContainer.new()
	var label = Label.new()
	var line_edit = LineEdit.new()
	
	dialog.title = title
	label.text = message
	line_edit.text = default_text
	line_edit.select_all()
	
	vbox.add_child(label)
	vbox.add_child(line_edit)
	dialog.add_child(vbox)
	
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()
	
	await dialog.confirmed
	var result = line_edit.text
	dialog.queue_free()
	
	return result

# 从模板创建Excel文件
func _create_excel_from_template(file_path: String) -> bool:
	var template_path = get_script().resource_path.get_base_dir() + "/../excel_template/default.xlsx"
	
	# 检查模板文件是否存在
	if not FileAccess.file_exists(template_path):
		push_error("Excel模板文件不存在: " + template_path)
		return false
	
	# 检查目标文件是否已存在
	if FileAccess.file_exists(file_path):
		push_error("文件已存在: " + file_path)
		return false
	
	# 复制模板文件到目标位置
	var template_file = FileAccess.open(template_path, FileAccess.READ)
	if not template_file:
		push_error("无法打开模板文件: " + template_path)
		return false
	
	var content = template_file.get_buffer(template_file.get_length())
	template_file.close()
	
	var target_file = FileAccess.open(file_path, FileAccess.WRITE)
	if not target_file:
		push_error("无法创建目标文件: " + file_path)
		return false
	
	target_file.store_buffer(content)
	target_file.close()
	
	print("Excel文件已从模板创建: %s" % file_path)
	return true

# 文件树相关信号处理
func _on_file_tree_item_selected():
	var selected = file_tree.get_selected()
	if selected == null:
		selected_item_type = "none"
		selected_item_path = ""
	else:
		var metadata = selected.get_metadata(0)
		if metadata == null:
			selected_item_type = "none"
			selected_item_path = ""
			property_view_switcher.current_tab=0
		else:
			selected_item_type = metadata.type
			selected_item_path = metadata.path
	
	_update_property_panel()

func _on_file_tree_item_activated():
	# 双击打开文件
	var selected = file_tree.get_selected()
	if selected == null:
		return
	
	var metadata = selected.get_metadata(0)
	if metadata == null:
		return
	
	if metadata.type == "excel":
		_open_file_with_system(metadata.path)
	elif metadata.type == "folder":
		_open_folder_with_system(metadata.path)

func _on_file_tree_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int):
	# 右键菜单
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var selected = file_tree.get_selected()
		if selected != null:
			# 转换为全局坐标
			var global_pos = file_tree.global_position + mouse_position
			file_context_menu.position = global_pos
			file_context_menu.popup()

func _on_file_tree_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			var selected = file_tree.get_selected()
			if selected != null:
				var global_pos = file_tree.global_position + mouse_event.position
				file_context_menu.position = global_pos
				file_context_menu.popup()

func _on_context_menu_selected(id: int):
	var selected = file_tree.get_selected()
	if selected == null:
		return
	
	var metadata = selected.get_metadata(0)
	if metadata == null:
		return
	
	match id:
		0:  # 打开
			if metadata.type == "excel":
				_open_file_with_system(metadata.path)
			elif metadata.type == "folder":
				_open_folder_with_system(metadata.path)
		1:  # 打开所在文件夹
			var folder_path = metadata.path.get_base_dir()
			_open_folder_with_system(folder_path)
		2:  # 重命名
			_rename_file_or_folder(metadata.path, metadata.type)
		3:  # 删除
			_delete_file_or_folder(metadata.path, metadata.type)

# 界面操作相关
func _on_refresh_pressed():
	print("手动刷新文件列表...")
	_refresh_file_tree()
	print("文件列表刷新完成")

# 字段管理相关
func _on_add_field_pressed():
	_add_field_row("新字段", "String", "")

func _add_field_row(field_name: String, field_type: String, default_value: String) -> Control:
	const FieldRowScene = preload("res://addons/config_manager/ui/field_row.tscn")
	var field_row = FieldRowScene.instantiate()
	field_list.add_child(field_row)
	
	# 设置可用的枚举列表
	field_row.set_available_enums(all_enums)
	
	# 设置字段数据
	field_row.setup_field(field_name, field_type, default_value)
	
	# 连接信号
	field_row.field_moved_up.connect(_on_field_moved_up)
	field_row.field_moved_down.connect(_on_field_moved_down)
	field_row.field_deleted.connect(_on_field_deleted)
	field_row.field_changed.connect(_on_field_changed)
	
	# 更新移动按钮状态
	_update_move_buttons()
	
	return field_row

# 更新所有字段行的枚举列表
func _update_field_rows_enum_list():
	for child in field_list.get_children():
		if child.has_method("set_available_enums"):
			child.set_available_enums(all_enums)

func _on_field_moved_up(field_row: Control):
	var index = field_row.get_index()
	if index > 0:
		field_list.move_child(field_row, index - 1)
		_update_move_buttons()

func _on_field_moved_down(field_row: Control):
	var index = field_row.get_index()
	if index < field_list.get_child_count() - 1:
		field_list.move_child(field_row, index + 1)
		_update_move_buttons()

func _on_field_deleted(field_row: Control):
	field_row.queue_free()
	_update_move_buttons()

func _on_field_changed(field_row: Control):
	# 字段内容改变时的处理
	pass

func _update_move_buttons():
	var child_count = field_list.get_child_count()
	for i in range(child_count):
		var field_row = field_list.get_child(i)
		if field_row.has_method("set_move_buttons_enabled"):
			field_row.set_move_buttons_enabled(i > 0, i < child_count - 1)

# 系统文件操作
func _open_file_with_system(file_path: String):
	var global_path = ProjectSettings.globalize_path(file_path)
	print("打开文件: " + global_path)
	OS.shell_open(global_path)

func _open_folder_with_system(folder_path: String):
	var global_path = ProjectSettings.globalize_path(folder_path)
	print("打开文件夹: " + global_path)
	OS.shell_open(global_path)

func _rename_file_or_folder(path: String, type: String):
	var current_name = path.get_file()
	var new_name = await _prompt_input("重命名", "请输入新名称:", current_name)
	
	if new_name.is_empty() or new_name == current_name:
		return
	
	var parent_dir = path.get_base_dir()
	var new_path = parent_dir.path_join(new_name)
	
	# 检查新路径是否已存在
	if FileAccess.file_exists(new_path) or DirAccess.dir_exists_absolute(new_path):
		push_error("文件或文件夹已存在: " + new_name)
		return
	
	# 执行重命名
	var success = DirAccess.rename_absolute(path, new_path) == OK
	
	if success:
		print("重命名成功: %s -> %s" % [current_name, new_name])
		_refresh_file_tree()
	else:
		push_error("重命名失败: " + current_name)

func _delete_file_or_folder(path: String, type: String):
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "确定要删除 '%s' 吗？" % path.get_file()
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	
	var success = false
	if type == "excel":
		success = DirAccess.remove_absolute(path) == OK
	elif type == "folder":
		var dir = DirAccess.open(path.get_base_dir())
		success = dir.remove(path.get_file()) == OK
	
	if success:
		print("删除成功: " + path)
		_refresh_file_tree()
	else:
		print("删除失败: " + path)
	
	dialog.queue_free()

func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F2:
			var selected = file_tree.get_selected()
			if selected:
				var metadata = selected.get_metadata(0)
				if metadata:
					_rename_file_or_folder(metadata.path, metadata.type)
					get_viewport().set_input_as_handled()

# ================== 枚举管理功能 ==================

# 刷新枚举树
func _refresh_enum_tree():
	enum_tree.clear()
	all_enums.clear()
	
	var root = enum_tree.create_item()
	root.set_text(0, "枚举定义")
	root.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
	
	# 确保目录存在
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(enum_path):
		dir.make_dir_recursive(enum_path)
	
	# 设置固定的枚举文件路径
	enum_file_path = enum_path.path_join("enums.gd")
	
	# 如果文件不存在，创建空文件
	if not FileAccess.file_exists(enum_file_path):
		EnumParser.save_enum_file(enum_file_path, [])
	
	# 解析枚举文件
	all_enums = EnumParser.parse_enum_file(enum_file_path)
	
	# 为每个枚举创建节点
	for enum_def in all_enums:
		var enum_item = enum_tree.create_item(root)
		enum_item.set_text(0, enum_def.name)
		enum_item.set_icon(0, get_theme_icon("Enum", "EditorIcons"))
		
		# 添加标识符
		var flags_text = " [Flag]" if enum_def.is_flag else ""
		enum_item.set_text(0, enum_def.name + flags_text)
		
		enum_item.set_metadata(0, {
			"type": "enum",
			"enum_name": enum_def.name,
			"is_flag": enum_def.is_flag
		})
	
	root.set_collapsed(false)

# 枚举树选择处理
func _on_enum_tree_item_selected():
	var selected = enum_tree.get_selected()
	if selected == null:
		return
	
	var metadata = selected.get_metadata(0)
	if metadata == null or metadata.type != "enum":
		property_view_switcher.current_tab=0
		return
	selected_enum_name = metadata.enum_name
	_update_enum_roperties()
	pass
	
func _update_enum_roperties():
	# 从所有枚举中找到对应的枚举定义
	current_enum_structure = null
	for enum_def in all_enums:
		if enum_def.name == selected_enum_name:
			current_enum_structure = enum_def
			break
	
	if current_enum_structure:
		_show_enum_properties()

# 显示枚举属性面板
func _show_enum_properties():
	if current_enum_structure == null:
		return
	
	# 切换到枚举属性面板
	property_view_switcher.current_tab = 2
	info_label.hide()
	
	# 设置is_flag复选框
	is_flag_checkbox.set_pressed_no_signal(current_enum_structure.is_flag)
	
	# 清空现有枚举值行
	for child in enum_value_list.get_children():
		child.queue_free()
	
	# 等待两帧确保清理完成
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 添加枚举值行
	for i in range(current_enum_structure.values.size()):
		var value = current_enum_structure.values[i]
		_add_enum_value_row_safe(value.name, value.value, value.comment)

# 新建枚举
func _on_new_enum_pressed():
	var enum_name = await _prompt_input("新建枚举", "请输入枚举名称:")
	if enum_name.is_empty():
		return
	
	# 检查枚举名是否已存在
	for enum_def in all_enums:
		if enum_def.name == enum_name:
			push_error("枚举名已存在: " + enum_name)
			return
	
	# 创建新枚举定义，添加一个默认值
	var new_enum = EnumStructure.new(enum_name, false, "")
	new_enum.add_value("VALUE_0", 0, "默认值")
	
	# 添加到现有枚举列表
	all_enums.append(new_enum)
	
	# 保存所有枚举到固定文件
	if EnumParser.save_enum_file(enum_file_path, all_enums):
		_refresh_enum_tree()
		_update_field_rows_enum_list()  # 更新字段行的枚举列表
		print("枚举创建成功: " + enum_name)
		
		# 自动选中新创建的枚举
		_select_enum_by_name(enum_name)
	else:
		push_error("枚举创建失败: " + enum_name)

# 刷新枚举列表
func _on_refresh_enum_pressed():
	_refresh_enum_tree()
	_update_field_rows_enum_list()

# 根据名称选中枚举
func _select_enum_by_name(enum_name: String):
	var root = enum_tree.get_root()
	if root == null:
		return
	
	# 遍历所有枚举项
	var child = root.get_first_child()
	while child != null:
		var metadata = child.get_metadata(0)
		if metadata != null and metadata.type == "enum" and metadata.enum_name == enum_name:
			child.select(0)
			enum_tree.item_selected.emit()
			break
		child = child.get_next()

# 添加枚举值
func _on_add_enum_value_pressed():
	if current_enum_structure == null:
		return
	
	# 计算下一个值
	var next_value = 0
	if current_enum_structure.is_flag:
		next_value = current_enum_structure.get_next_flag_value()
	else:
		next_value = current_enum_structure.get_next_sequential_value()
	
	_add_enum_value_row("新值", next_value, "")
	
	# 刷新所有枚举值的序号
	_refresh_enum_values()

# 安全地添加枚举值行
func _add_enum_value_row_safe(value_name: String, value_int: int, comment: String) -> Control:
	
	var value_row = EnumValueRowScene.instantiate()
	
	if value_row == null:
		push_error("无法创建枚举值行实例")
		return null
	
	enum_value_list.add_child(value_row)
	
#	# 等待节点准备就绪
#	await value_row.ready
	
	# 验证节点是否正确创建
	if not value_row.has_method("setup_value"):
		push_error("枚举值行缺少setup_value方法")
		value_row.queue_free()
		return null
	
	# 设置值数据
	value_row.setup_value(value_name, value_int, comment)
	
	# 连接信号
	value_row.value_moved_up.connect(_on_enum_value_moved_up)
	value_row.value_moved_down.connect(_on_enum_value_moved_down)
	value_row.value_deleted.connect(_on_enum_value_deleted)
	value_row.value_changed.connect(_on_enum_value_changed)
	
	# 更新移动按钮状态
	_update_enum_move_buttons()
	
	return value_row

# 添加枚举值行（同步版本，用于按钮点击）
func _add_enum_value_row(value_name: String, value_int: int, comment: String) -> Control:
	const EnumValueRowScene = preload("res://addons/config_manager/ui/enum_value_row.tscn")
	var value_row = EnumValueRowScene.instantiate()
	
	if value_row == null:
		push_error("无法创建枚举值行实例")
		return null
	
	enum_value_list.add_child(value_row)
	
	# 延迟设置以确保节点准备就绪
	call_deferred("_setup_enum_value_row", value_row, value_name, value_int, comment)
	
	return value_row

func _setup_enum_value_row(value_row: Control, value_name: String, value_int: int, comment: String):
	if value_row == null or not is_instance_valid(value_row):
		return
	
	# 确保节点已准备就绪
	if not value_row.is_node_ready():
		await value_row.ready
	
	# 验证节点是否正确创建
	if not value_row.has_method("setup_value"):
		push_error("枚举值行缺少setup_value方法")
		value_row.queue_free()
		return
	
	# 设置值数据
	value_row.setup_value(value_name, value_int, comment)
	
	# 连接信号
	if not value_row.value_moved_up.is_connected(_on_enum_value_moved_up):
		value_row.value_moved_up.connect(_on_enum_value_moved_up)
	if not value_row.value_moved_down.is_connected(_on_enum_value_moved_down):
		value_row.value_moved_down.connect(_on_enum_value_moved_down)
	if not value_row.value_deleted.is_connected(_on_enum_value_deleted):
		value_row.value_deleted.connect(_on_enum_value_deleted)
	if not value_row.value_changed.is_connected(_on_enum_value_changed):
		value_row.value_changed.connect(_on_enum_value_changed)
	
	# 更新移动按钮状态
	_update_enum_move_buttons()

# 枚举值移动处理
func _on_enum_value_moved_up(value_row: Control):
	var index = value_row.get_index()
	if index > 0:
		enum_value_list.move_child(value_row, index - 1)
		_update_enum_move_buttons()
		# 刷新所有枚举值的序号
		_refresh_enum_values()

func _on_enum_value_moved_down(value_row: Control):
	var index = value_row.get_index()
	if index < enum_value_list.get_child_count() - 1:
		enum_value_list.move_child(value_row, index + 1)
		_update_enum_move_buttons()
		# 刷新所有枚举值的序号
		_refresh_enum_values()

func _on_enum_value_deleted(value_row: Control):
	value_row.queue_free()
	_update_enum_move_buttons()
	# 延迟刷新，等待节点删除完成
	call_deferred("_refresh_enum_values")

func _on_enum_value_changed(value_row: Control):
	# 枚举值内容改变时的处理
	pass

# 更新枚举移动按钮状态
func _update_enum_move_buttons():
	var child_count = enum_value_list.get_child_count()
	for i in range(child_count):
		var value_row = enum_value_list.get_child(i)
		if value_row.has_method("set_move_buttons_enabled"):
			value_row.set_move_buttons_enabled(i > 0, i < child_count - 1)

# Flag模式切换
func _on_is_flag_toggled(pressed: bool):
	if current_enum_structure == null:
		return
	
	current_enum_structure.is_flag = pressed
	
	# 重新计算所有值
	_refresh_enum_values()

# 刷新枚举值序号
func _refresh_enum_values():
	if current_enum_structure == null:
		return
	
	# 等待一帧确保UI更新完成
	await get_tree().process_frame
	
	for i in range(enum_value_list.get_child_count()):
		var value_row = enum_value_list.get_child(i)
		if value_row == null or not is_instance_valid(value_row):
			continue
			
		if value_row.has_method("set_value_int"):
			var new_value = 0
			if current_enum_structure.is_flag:
				new_value = 1 << i  # 2的幂次方: 1, 2, 4, 8, 16...
			else:
				new_value = i  # 连续整数: 0, 1, 2, 3, 4...
			value_row.set_value_int(new_value)

# 保存枚举
func _on_save_enum_pressed():
	if current_enum_structure == null or enum_file_path.is_empty():
		return
	
	# 从UI更新枚举结构
	_update_enum_from_list()
	
	# 保存所有枚举到固定文件
	if EnumParser.save_enum_file(enum_file_path, all_enums):
		print("枚举保存成功: " + current_enum_structure.name)
		_refresh_enum_tree()
		_update_field_rows_enum_list()  # 更新字段行的枚举列表
		# 刷新编辑器文件系统
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
	else:
		push_error("枚举保存失败: " + current_enum_structure.name)

# 从UI列表更新枚举结构
func _update_enum_from_list():
	if current_enum_structure == null:
		return
	
	current_enum_structure.values.clear()
	
	for child in enum_value_list.get_children():
		if child.has_method("get_value_name"):
			var value_name = child.get_value_name()
			var value_int = child.get_value_int()
			var comment = child.get_comment()
			
			if not value_name.is_empty():
				current_enum_structure.values.append(
					EnumStructure.EnumValue.new(value_name, value_int, comment)
				)

# 删除枚举
func _on_del_enum_pressed():
	if current_enum_structure == null or selected_enum_name.is_empty():
		push_error("请先选择要删除的枚举")
		return
	
	# 检查枚举是否被使用
	var usage_files = _check_enum_usage(selected_enum_name)
	if usage_files.size() > 0:
		var usage_message = "枚举 '%s' 正在被以下文件使用，无法删除：\n" % selected_enum_name
		for file_info in usage_files:
			usage_message += "• %s (字段: %s)\n" % [file_info.file_name, file_info.field_name]
		
		var dialog = AcceptDialog.new()
		dialog.dialog_text = usage_message
		dialog.title = "无法删除枚举"
		add_child(dialog)
		dialog.popup_centered()
		await dialog.confirmed
		dialog.queue_free()
		return
	
	# 显示确认对话框
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "确定要删除枚举 '%s' 吗？\n此操作无法撤销。" % selected_enum_name
	confirm_dialog.title = "确认删除"
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()
	
	await confirm_dialog.confirmed
	
	# 从 all_enums 数组中移除枚举
	for i in range(all_enums.size()):
		if all_enums[i].name == selected_enum_name:
			all_enums.remove_at(i)
			break
	
	# 保存更新后的枚举文件
	if EnumParser.save_enum_file(enum_file_path, all_enums):
		print("枚举删除成功: " + selected_enum_name)
		
		# 清除当前选择
		selected_enum_name = ""
		current_enum_structure = null
		
		# 刷新枚举树和相关UI
		_refresh_enum_tree()
		_update_field_rows_enum_list()  # 更新字段行的枚举列表
		
		# 切换回主面板
		property_view_switcher.current_tab = 0
		
		# 刷新编辑器文件系统
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
	else:
		push_error("枚举删除失败: " + selected_enum_name)
	
	confirm_dialog.queue_free()

# 检查枚举使用情况
func _check_enum_usage(enum_name: String) -> Array[Dictionary]:
	var usage_files: Array[Dictionary] = []
	
	# 检查所有Excel文件中是否使用了该枚举
	_scan_excel_files_for_enum_usage(excel_root_path, enum_name, usage_files)
	
	return usage_files

# 递归扫描Excel文件中的枚举使用情况
func _scan_excel_files_for_enum_usage(dir_path: String, enum_name: String, usage_files: Array[Dictionary]):
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# 递归检查子目录
			_scan_excel_files_for_enum_usage(full_path, enum_name, usage_files)
		elif file_name.ends_with(".xlsx") or file_name.ends_with(".xls"):
			# 检查Excel文件
			var excel_structure = ExcelParser.parse_excel_structure(full_path)
			if excel_structure != null:
				for field in excel_structure.fields:
					if field.type == ExcelStructure.FieldType.ENUM and field.enum_name == enum_name:
						usage_files.append({
							"file_path": full_path,
							"file_name": file_name,
							"field_name": field.name
						})
		
		file_name = dir.get_next()


func _on_tab_container_tab_changed(tab: int) -> void:
	if tab==0:
		_update_property_panel()
	elif tab==1:
		_update_enum_roperties()
	pass # Replace with function body.

# 辅助函数：在编辑器中打开文件
func _open_file_in_editor(file_path: String):
	# 检查文件是否存在
	if not FileAccess.file_exists(file_path):
		push_error("文件不存在: %s" % file_path)
		return
	
	# 使用EditorInterface打开脚本文件
	if editor_interface:
		# 对于.gd文件，直接加载并在脚本编辑器中打开
		if file_path.ends_with(".gd"):
			var script_resource = load(file_path)
			if script_resource:
				editor_interface.edit_script(script_resource)
				editor_interface.set_main_screen_editor("Script")
				print("在脚本编辑器中打开文件: %s" % file_path)
			else:
				push_error("无法加载脚本资源: %s" % file_path)
		else:
			# 对于其他文件类型，尝试用默认编辑器打开
			editor_interface.open_scene_from_path(file_path)
			print("在编辑器中打开文件: %s" % file_path)
	else:
		push_error("编辑器接口不可用")

# 辅助函数：在资源管理器中打开文件夹
func _open_folder_in_explorer(folder_path: String):
	# 转换为绝对路径
	var absolute_path = ProjectSettings.globalize_path(folder_path)
	
	# 检查文件夹是否存在
	if not DirAccess.dir_exists_absolute(absolute_path):
		push_error("文件夹不存在: %s" % absolute_path)
		return
	
	# 根据操作系统打开文件夹
	var os_name = OS.get_name()
	var command: String
	var args: PackedStringArray
	
	match os_name:
		"Windows":
			command = "explorer"
			args = [absolute_path.replace("/", "\\")]
		"macOS":
			command = "open"
			args = [absolute_path]
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			command = "xdg-open"
			args = [absolute_path]
		_:
			push_error("不支持的操作系统: %s" % os_name)
			return
	
	# 执行命令
	var result = OS.create_process(command, args)
	if result > 0:
		print("在资源管理器中打开文件夹: %s" % absolute_path)
	else:
		push_error("无法打开文件夹: %s" % absolute_path)

# 收集当前表使用的枚举类型
func _collect_used_enums() -> Array[String]:
	var used_enum_names: Array[String] = []
	
	if current_excel_structure == null:
		return used_enum_names
	
	# 遍历所有字段，查找枚举类型
	for field in current_excel_structure.fields:
		if field.type == ExcelStructure.FieldType.ENUM and not field.enum_name.is_empty():
			if not used_enum_names.has(field.enum_name):
				used_enum_names.append(field.enum_name)
	
	return used_enum_names

# 生成枚举定义表格数据
func _generate_enum_definition_table(used_enum_names: Array[String]) -> String:
	var result_lines: Array[String] = []
	
	# 第一行：枚举名称
	result_lines.append("\t".join(used_enum_names))
	
	# 获取每个枚举的定义
	var enum_definitions: Array[Array] = []
	var max_values = 0
	
	for enum_name in used_enum_names:
		var enum_values = _get_enum_values(enum_name)
		enum_definitions.append(enum_values)
		max_values = max(max_values, enum_values.size())
	
	# 生成数据行
	for row in range(max_values):
		var row_data: Array[String] = []
		
		for col in range(used_enum_names.size()):
			var enum_values = enum_definitions[col]
			if row < enum_values.size():
				row_data.append(str(enum_values[row]))
			else:
				row_data.append("")  # 空单元格
		
		result_lines.append("\t".join(row_data))
	
	return "\n".join(result_lines)

# 获取指定枚举的所有值定义
func _get_enum_values(enum_name: String) -> Array[String]:
	var values: Array[String] = []
	
	# 在all_enums中查找对应的枚举
	for enum_struct in all_enums:
		if enum_struct.name == enum_name:
			for enum_value in enum_struct.values:
				values.append(enum_value.name)
			break
	
	return values
