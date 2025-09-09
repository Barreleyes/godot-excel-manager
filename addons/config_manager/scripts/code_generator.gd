@tool
extends RefCounted
class_name CodeGenerator

const ExcelStructure = preload("res://addons/config_manager/scripts/excel_structure.gd")
const ExcelParser = preload("res://addons/config_manager/scripts/excel_parser.gd")

static func generate_all_classes(excel_root_path: String, output_path: String) -> bool:
	var excel_files = _find_excel_files(excel_root_path)
	var table_structures = []
	var success_count = 0
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(output_path):
		dir.make_dir_recursive(output_path)
	
	# 收集所有有效的Excel文件结构
	for excel_file in excel_files:
		var structure = ExcelParser.parse_excel_structure(excel_file)
		if structure != null and structure.fields.size() > 0:
			table_structures.append(structure)
		else:
			print("跳过无效Excel文件: %s" % excel_file)
	
	# 生成统一的表类文件（包含所有表）
	if table_structures.size() > 0:
		_generate_table_classes_file(table_structures, output_path)
		
		# 生成统一的数据管理器文件（包含所有表）
		_generate_data_manager_file(table_structures, output_path)
		
		success_count = table_structures.size()
	
	print("类生成完成: 成功处理 %d 个表" % success_count)
	return success_count > 0

# 导出单个Excel文件的表类
static func export_single_table_class(excel_file_path: String, output_path: String) -> bool:
	var structure = ExcelParser.parse_excel_structure(excel_file_path)
	if structure == null or structure.fields.size() == 0:
		push_error("无效的Excel文件: %s" % excel_file_path)
		return false
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(output_path):
		dir.make_dir_recursive(output_path)
	
	# 生成单个表的类代码
	var classes_code = "@tool\nclass_name TableClasses\n# 自动生成的表类定义文件\n\n"
	
	# 生成主表类
	classes_code += _generate_main_table_class(structure)
	classes_code += "\n"
	
	# 如果有子键，生成子表类
	if _has_sub_key(structure):
		classes_code += _generate_sub_table_class(structure)
		classes_code += "\n"
	
	var classes_file_path = output_path.path_join("table_classes.gd")
	
	# 如果文件已存在，先删除旧文件
	if FileAccess.file_exists(classes_file_path):
		var delete_dir = DirAccess.open(output_path)
		if delete_dir:
			delete_dir.remove("table_classes.gd")
			print("删除旧的表类文件: %s" % classes_file_path)
		
		# 刷新编辑器文件系统
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(classes_file_path)
			EditorInterface.get_resource_filesystem().scan_sources()
	
	# 创建新文件
	var file = FileAccess.open(classes_file_path, FileAccess.WRITE)
	if file:
		file.store_string(classes_code)
		file.close()
		print("生成表类文件: %s" % classes_file_path)
		
		# 再次刷新编辑器文件系统以确保新文件被识别
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(classes_file_path)
			EditorInterface.get_resource_filesystem().scan_sources()
		
		return true
	else:
		push_error("无法创建表类文件: %s" % classes_file_path)
		return false

# 导出单个Excel文件的JSON
static func export_single_json(excel_file_path: String, output_path: String) -> bool:
	var structure = ExcelParser.parse_excel_structure(excel_file_path)
	if structure == null or structure.fields.size() == 0:
		push_error("无效的Excel文件: %s" % excel_file_path)
		return false
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(output_path):
		dir.make_dir_recursive(output_path)
	
	var data = ExcelParser.export_to_json(excel_file_path, structure)
	var json_string = JSON.stringify(data, "\t")
	var json_file_path = output_path.path_join(structure.table_name + ".json")
	
	var file = FileAccess.open(json_file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("导出JSON文件: %s" % json_file_path)
		return true
	else:
		push_error("无法创建JSON文件: %s" % json_file_path)
		return false

# 为单个Excel文件生成DataManager（简化版）
static func export_single_data_manager_method(excel_file_path: String, output_path: String) -> bool:
	var structure = ExcelParser.parse_excel_structure(excel_file_path)
	if structure == null or structure.fields.size() == 0:
		push_error("无效的Excel文件: %s" % excel_file_path)
		return false
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(output_path):
		dir.make_dir_recursive(output_path)
	
	var table_name = structure.table_name
	var class_name_str = "TableClasses.Dt_" + table_name
	
	# 生成简化的DataManager代码
	var manager_code = "@tool\n\n"
	manager_code += "# 自动生成的数据管理器（单表）\n\n"
	
	# 生成Dictionary属性
	var line_text = "static var %s: Dictionary[String, %s] = {}\n" % [table_name, class_name_str]
	manager_code += line_text
	manager_code += "\n"
	
	# 生成读取方法
	var method_name = "get_" + table_name
	manager_code += "# 获取%s表中指定key的数据\n" % table_name
	manager_code += "static func %s(key) -> %s:\n" % [method_name, class_name_str]
	manager_code += "\tvar _key = str(key)\n"
	manager_code += "\tif %s.has(_key):\n" % table_name
	manager_code += "\t\treturn %s[_key]\n" % table_name
	manager_code += "\treturn null\n\n"
	
	# 生成通用加载方法
	manager_code += "# 使用通用加载器加载所有数据\n"
	manager_code += "static func load_all_data() -> bool:\n"
	manager_code += "\treturn JsonLoader.load_all_json_data(ProjectSettings.get_setting(\"config_manager/json_export_path\", \"res://Configs/Json/\"))\n\n"
	
	#生成static func _init()
	manager_code += "func _ready() -> void:\n"
	manager_code += "\tload_all_data()\n"

	# # 生成通用访问方法
	# manager_code += "# 获取指定表的数据\n"
	# manager_code += "static func get_table_data(table_name: String) -> Dictionary:\n"
	# manager_code += "\treturn get(table_name) if has_method(\"get\") else {}\n\n"
	
	# manager_code += "# 获取指定表的指定项\n"
	# manager_code += "static func get_table_item(table_name: String, key: String):\n"
	# manager_code += "\tvar table_dict = get_table_data(table_name)\n"
	# manager_code += "\treturn table_dict.get(key, null)\n"
	
	var manager_file_path = output_path.path_join("data_manager.gd")
	var file = FileAccess.open(manager_file_path, FileAccess.WRITE)
	if file:
		file.store_string(manager_code)
		file.close()
		print("生成数据管理器文件: %s" % manager_file_path)
		return true
	else:
		push_error("无法创建数据管理器文件: %s" % manager_file_path)
		return false

static func _find_excel_files(root_path: String) -> Array[String]:
	var excel_files: Array[String] = []
	var dir = DirAccess.open(root_path)
	
	if dir == null:
		return excel_files
	
	_scan_directory_for_excel(dir, root_path, excel_files)
	return excel_files

static func _scan_directory_for_excel(dir: DirAccess, path: String, excel_files: Array[String]):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path.path_join(file_name)
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_scan_directory_for_excel(sub_dir, full_path, excel_files)
		elif file_name.ends_with(".xlsx") or file_name.ends_with(".xls"):
			excel_files.append(full_path)
		
		file_name = dir.get_next()

# 生成表类文件
static func _generate_table_classes_file(table_structures: Array, output_path: String):
	var classes_code = "@tool\nclass_name TableClasses\n# 自动生成的表类定义文件\n\n"
	
	for structure in table_structures:
		# 生成主表类
		classes_code += _generate_main_table_class(structure)
		classes_code += "\n"
		
		# 如果有子键，生成子表类
		if _has_sub_key(structure):
			classes_code += _generate_sub_table_class(structure)
			classes_code += "\n"
	
	var classes_file_path = output_path.path_join("table_classes.gd")
	
	# 如果文件已存在，先删除旧文件
	if FileAccess.file_exists(classes_file_path):
		var delete_dir = DirAccess.open(output_path)
		if delete_dir:
			delete_dir.remove("table_classes.gd")
			print("删除旧的表类文件: %s" % classes_file_path)
		
		# 刷新编辑器文件系统
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(classes_file_path)
			EditorInterface.get_resource_filesystem().scan_sources()
	
	# 创建新文件
	var file = FileAccess.open(classes_file_path, FileAccess.WRITE)
	if file:
		file.store_string(classes_code)
		file.close()
		print("生成表类文件: %s" % classes_file_path)
		
		# 再次刷新编辑器文件系统以确保新文件被识别
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(classes_file_path)
			EditorInterface.get_resource_filesystem().scan()
	else:
		push_error("无法创建表类文件: %s" % classes_file_path)

# 生成数据管理器文件
static func _generate_data_manager_file(table_structures: Array, output_path: String):
	var manager_code = "@tool\nextends Node\n\n"
	manager_code += "# 自动生成的数据管理器\n\n"
	
	# 为每个表生成Dictionary属性
	for structure in table_structures:
		var table_name = structure.table_name
		var class_name_str = "TableClasses.Dt_" + table_name
		var line_text = "static var %s: Dictionary[String, %s] = {}\n" % [table_name, class_name_str]
		manager_code += line_text
	
	manager_code += "\n"
	
	# 为每个表生成读取方法
	for structure in table_structures:
		var table_name = structure.table_name
		var class_name_str = "TableClasses.Dt_" + table_name
		var method_name = "get_" + table_name
		
		manager_code += "# 获取%s表中指定key的数据\n" % table_name
		manager_code += "static func %s(key) -> %s:\n" % [method_name, class_name_str]
		manager_code += "\tvar _key = str(key)\n"
		manager_code += "\tif %s.has(_key):\n" % table_name
		manager_code += "\t\treturn %s[_key]\n" % table_name
		manager_code += "\treturn null\n\n"
	
	# 生成通用加载方法
	manager_code += "# 使用通用加载器加载所有数据\n"
	manager_code += "static func load_all_data() -> bool:\n"
	manager_code += "\treturn JsonLoader.load_all_json_data(ProjectSettings.get_setting(\"config_manager/json_export_path\", \"res://Configs/Json/\"))\n\n"
	
	#生成 func _ready()
	manager_code += "func _ready() -> void:\n"
	manager_code += "\tload_all_data()\n"
	
	
	var manager_file_path = output_path.path_join("data_manager.gd")
	var file = FileAccess.open(manager_file_path, FileAccess.WRITE)
	if file:
		file.store_string(manager_code)
		file.close()
		print("生成数据管理器文件: %s" % manager_file_path)
	else:
		push_error("无法创建数据管理器文件: %s" % manager_file_path)

static func export_all_to_json(excel_root_path: String, output_path: String) -> bool:
	var excel_files = _find_excel_files(excel_root_path)
	var success_count = 0
	var total_count = 0
	
	# 确保输出目录存在
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(output_path):
		dir.make_dir_recursive(output_path)
	
	for excel_file in excel_files:
		# 检查文件是否有效
		var structure = ExcelParser.parse_excel_structure(excel_file)
		if structure != null and structure.fields.size() > 0:
			total_count += 1
			# 调用单个文件导出方法
			if export_single_json(excel_file, output_path):
				success_count += 1
		else:
			print("跳过无效Excel文件: %s" % excel_file)
	
	print("JSON导出完成: 成功 %d/%d 个文件" % [success_count, total_count])
	return success_count == total_count

# 检查是否有子键
static func _has_sub_key(structure: ExcelStructure) -> bool:
	var key_count = 0
	for field in structure.fields:
		if field.type == ExcelStructure.FieldType.KEY:
			key_count += 1
			if key_count >= 2:
				return true
	return false

# 生成主表类
static func _generate_main_table_class(structure: ExcelStructure) -> String:
	var class_name_str = "Dt_" + structure.table_name
	var code = "class %s:\n" % class_name_str
	
	var key_fields = []
	var main_fields = []
	var sub_key_field = null
	var sub_fields = []
	
	var found_first_key = false
	var found_second_key = false
	
	# 分类字段
	for field in structure.fields:
		if field.type == ExcelStructure.FieldType.KEY:
			if not found_first_key:
				key_fields.append(field)
				found_first_key = true
			elif not found_second_key:
				sub_key_field = field
				found_second_key = true
		elif not found_second_key:
			# 第一个Key到第二个Key之间的字段
			main_fields.append(field)
		else:
			# 第二个Key之后的字段
			sub_fields.append(field)
	
	# 生成主字段属性
	for field in main_fields:
		var field_type = structure.get_godot_type_string_with_enum(field)
		var line_text = "\tvar %s: %s\n" % [field.name, field_type]
		code += line_text
	
	# 如果有子键，生成子数据字典
	if sub_key_field != null:
		var sub_class_name = "DtSub_" + structure.table_name
		var sub_key_field_name = sub_key_field.name
		var line_text = "\tvar %s: Dictionary[String, %s] = {}\n" % [sub_key_field_name, sub_class_name]
		code += line_text
	
	code += "\n"
	
	# 生成构造函数
	code += "\tfunc _init():\n"
	code += "\t\tpass\n"
	
	return code

# 生成子表类
static func _generate_sub_table_class(structure: ExcelStructure) -> String:
	var class_name_str = "DtSub_" + structure.table_name
	var code = "class %s:\n" % class_name_str
	
	var found_first_key = false
	var found_second_key = false
	
	# 生成子字段属性（第二个Key之后的字段）
	for field in structure.fields:
		if field.type == ExcelStructure.FieldType.KEY:
			if not found_first_key:
				found_first_key = true
			elif not found_second_key:
				found_second_key = true
		elif found_second_key:
			# 第二个Key之后的字段
			var field_type = structure.get_godot_type_string_with_enum(field)
			var line_text = "\tvar %s: %s\n" % [field.name, field_type]
			code += line_text
	
	# code += "\n"
	
	# # 生成构造函数
	# code += "\tfunc _init():\n"
	# code += "\t\tpass\n"
	
	return code

# 注意：此方法已废弃，现在使用JsonLoader进行通用加载
# 保留此方法仅为向后兼容，实际不再使用

# 获取字段的默认值
static func _get_default_value_for_field(field: ExcelStructure.FieldInfo) -> String:
	match field.type:
		ExcelStructure.FieldType.STRING, ExcelStructure.FieldType.STRING_NAME:
			return '""'
		ExcelStructure.FieldType.INT, ExcelStructure.FieldType.ENUM:
			return "0"
		ExcelStructure.FieldType.FLOAT:
			return "0.0"
		ExcelStructure.FieldType.BOOL:
			return "false"
		ExcelStructure.FieldType.VECTOR2:
			return "Vector2.ZERO"
		ExcelStructure.FieldType.VECTOR2I:
			return "Vector2i.ZERO"
		ExcelStructure.FieldType.VECTOR3:
			return "Vector3.ZERO"
		ExcelStructure.FieldType.VECTOR3I:
			return "Vector3i.ZERO"
		ExcelStructure.FieldType.ARRAY_INT, ExcelStructure.FieldType.ARRAY_FLOAT, ExcelStructure.FieldType.ARRAY_STRING:
			return "[]"
		_:
			return "null"
