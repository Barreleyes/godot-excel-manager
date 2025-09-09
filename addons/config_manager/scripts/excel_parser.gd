@tool
extends RefCounted
class_name ExcelParser

const ExcelStructure = preload("res://addons/config_manager/scripts/excel_structure.gd")
const ExcelFile = preload("res://addons/excel_reader/src/excel_file.gd")

# Excel解析器，使用excel_reader插件
static var enums_script = load("res://Scripts/Enums/enums.gd")
static var enum_cache: Dictionary = {}

static func parse_excel_structure(file_path: String) -> ExcelStructure:
	var structure = ExcelStructure.new(file_path)
	
	if not FileAccess.file_exists(file_path):
		push_error("文件不存在: " + file_path)
		return structure
	
	# 使用excel_reader插件解析Excel文件
	if file_path.ends_with(".xlsx") or file_path.ends_with(".xls"):
		return _parse_excel_structure(file_path)
	
	push_warning("不支持的文件格式: " + file_path)
	return structure

static func _parse_excel_structure(file_path: String) -> ExcelStructure:
	var structure = ExcelStructure.new(file_path)
	
	# 使用excel_reader插件打开Excel文件
	var excel_file = ExcelFile.open_file(file_path)
	if excel_file == null:
		push_error("无法打开Excel文件: " + file_path)
		return structure
	
	var workbook = excel_file.get_workbook()
	if workbook == null:
		push_error("无法获取工作簿: " + file_path)
		excel_file.close()
		return structure
	
	# 获取第一个工作表
	var sheet = workbook.get_sheet(0)
	if sheet == null:
		push_error("无法获取工作表: " + file_path)
		excel_file.close()
		return structure
	
	# 获取表格数据
	var table_data = sheet.get_table_data()
	excel_file.close()
	
	if table_data.is_empty():
		push_warning("Excel文件为空: " + file_path)
		return structure
	
	# 获取行号列表并排序
	var row_numbers = table_data.keys()
	row_numbers.sort()
	
	if row_numbers.size() < 2:
		push_error("Excel文件格式错误，至少需要2行（字段名和类型）")
		return structure
	
	# 解析字段名（第一行）
	var first_row = table_data[row_numbers[0]]
	var field_names = _get_row_values(first_row)
	
	# 解析字段类型（第二行）
	var second_row = table_data[row_numbers[1]]
	var field_types = _get_row_values(second_row)
	
	# 解析默认值（第三行，如果存在）
	var default_values = []
	if row_numbers.size() > 2:
		var third_row = table_data[row_numbers[2]]
		default_values = _get_row_values(third_row)
	
	# 确保字段名和类型数量匹配
	var field_count = min(field_names.size(), field_types.size())
	

	
	for i in field_count:
		var field_name = field_names[i] if i < field_names.size() else ""
		var type_str = field_types[i] if i < field_types.size() else "String"
		var default_val = default_values[i] if i < default_values.size() else ""
		
		if field_name.is_empty():
	
			continue
		
		var field_type = ExcelStructure.get_field_type_from_string(type_str)
		var enum_type=""
		if field_type==ExcelStructure.FieldType.ENUM:
			enum_type=type_str.split(ExcelStructure.enum_prefix)[1]
			pass
		structure.add_field(field_name, field_type, default_val,enum_type)

	

	return structure

# 从行数据中获取值数组
static func _get_row_values(row_data: Dictionary) -> Array[String]:
	var values: Array[String] = []
	var column_numbers = row_data.keys()
	column_numbers.sort()
	
	if column_numbers.size() == 0:
		return values
	
	# 确保从第一列到最后一列都有值，空列用空字符串填充
	var max_col = column_numbers[-1]  # 最大列号
	for col in range(1, max_col + 1):  # Excel列从1开始
		var value = ""
		if col in row_data and row_data[col] != null:
			value = str(row_data[col])
		values.append(value)
	
	return values

# 导出Excel数据为JSON
static func export_to_json(file_path: String, structure: ExcelStructure) -> Dictionary:
	var data = {}
	
	if not FileAccess.file_exists(file_path):
		return data
	
	# 使用excel_reader插件处理Excel文件
	if file_path.ends_with(".xlsx") or file_path.ends_with(".xls") or file_path.ends_with(".xlsm"):
		return _export_excel_to_json(file_path, structure)
	
	return data

static func _export_excel_to_json(file_path: String, structure: ExcelStructure) -> Dictionary:
	var data = {}
	
	# 使用excel_reader插件打开Excel文件
	var excel_file = ExcelFile.open_file(file_path)
	if excel_file == null:
		push_error("无法打开Excel文件: " + file_path)
		return data
	
	var workbook = excel_file.get_workbook()
	if workbook == null:
		push_error("无法获取工作簿: " + file_path)
		excel_file.close()
		return data
	
	# 获取第一个工作表
	var sheet = workbook.get_sheet(0)
	if sheet == null:
		push_error("无法获取工作表: " + file_path)
		excel_file.close()
		return data
	
	# 获取表格数据
	var table_data = sheet.get_table_data()
	excel_file.close()
	
	if table_data.is_empty():
		return data
	
	# 获取行号列表并排序
	var row_numbers = table_data.keys()
	row_numbers.sort()
	
	if row_numbers.size() < 3:  # 至少需要字段名、类型、数据行
		return data
	

	
	# 跳过前两行（字段名和类型），从第三行开始是数据
	var processed_main_keys = {}  # 记录已处理的主Key和它们的主数据
	
	for i in range(2, row_numbers.size()):
		var row_num = row_numbers[i]
		var row_data = table_data[row_num]
		var values = _get_row_values(row_data)
		
		if values.size() == 0:
			continue
		
		# 获取主Key值
		var first_key_idx = structure.primary_keys[0]
		if first_key_idx >= values.size() or values[first_key_idx].is_empty():
			continue
		
		var main_key = _convert_key_to_appropriate_type(values[first_key_idx])
		
		# 检查是否是第一次遇到这个主Key
		var is_first_occurrence = main_key not in processed_main_keys
		if is_first_occurrence:
			processed_main_keys[main_key] = true
		
		_process_data_row_with_context(data, values, structure, main_key, is_first_occurrence)
	
	return data

static func _process_data_row_with_context(data: Dictionary, values: Array, structure: ExcelStructure, current_main_key, is_first_occurrence: bool) -> void:
	if structure.primary_keys.size() == 0:
		return
	
	if current_main_key == null:
		return
	
	var first_key = current_main_key
	
	if structure.primary_keys.size() == 1:
		# 只有一个主键
		var record = {}
		for i in range(structure.fields.size()):
			if i < values.size() and structure.fields[i].type != ExcelStructure.FieldType.KEY:
				record[structure.fields[i].name] = _convert_value(values[i], structure.fields[i].type, structure.fields[i].enum_name)
		data[first_key] = record
	else:
		# 有两个主键，嵌套结构
		var second_key_idx = structure.primary_keys[1]
		if second_key_idx >= values.size():
			return
		
		var second_key_raw = values[second_key_idx] if second_key_idx < values.size() else ""
		if second_key_raw.is_empty():
			return
		
		var second_key = _convert_key_to_appropriate_type(second_key_raw)
		var second_key_field_name = structure.fields[second_key_idx].name
		
		# 如果主key还不存在，初始化主记录
		if first_key not in data:
			data[first_key] = {}
			# 初始化第二个key字段的子对象
			data[first_key][second_key_field_name] = {}
		
		# 只在第一次遇到主key时读取主key数据（第一个key到第二个key之间的字段）
		if is_first_occurrence:
			for i in range(structure.fields.size()):
				if i < values.size() and i != structure.primary_keys[0] and i < second_key_idx:
					var field = structure.fields[i]
					if field.type != ExcelStructure.FieldType.KEY:
						data[first_key][field.name] = _convert_value(values[i], field.type, field.enum_name)

		
		# 确保子对象存在（防止主记录已存在但子对象未初始化的情况）
		if second_key_field_name not in data[first_key]:
			data[first_key][second_key_field_name] = {}
		
		# 总是创建子记录，包含第二个key之后的字段（即使主key区域为空）
		var sub_record = {}
		for i in range(second_key_idx + 1, structure.fields.size()):
			if i < values.size():
				var field = structure.fields[i]
				if field.type != ExcelStructure.FieldType.KEY:
					sub_record[field.name] = _convert_value(values[i], field.type, field.enum_name)
		
		data[first_key][second_key_field_name][second_key] = sub_record

static func _convert_value(value_str: String, type: ExcelStructure.FieldType, enum_type: String = ""):
	match type:
		ExcelStructure.FieldType.BOOL:
			return value_str.to_lower() in ["true", "1", "yes"]
		ExcelStructure.FieldType.INT:
			return int(value_str) if value_str.is_valid_int() else 0
		ExcelStructure.FieldType.FLOAT:
			return float(value_str) if value_str.is_valid_float() else 0.0
		ExcelStructure.FieldType.VECTOR2:
			var parts = value_str.split(",")
			if parts.size() >= 2:
				return Vector2(float(parts[0]), float(parts[1]))
			return Vector2.ZERO
		ExcelStructure.FieldType.VECTOR2I:
			var parts = value_str.split(",")
			if parts.size() >= 2:
				return Vector2i(int(parts[0]), int(parts[1]))
			return Vector2i.ZERO
		ExcelStructure.FieldType.VECTOR3:
			var parts = value_str.split(",")
			if parts.size() >= 3:
				return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
			return Vector3.ZERO
		ExcelStructure.FieldType.VECTOR3I:
			var parts = value_str.split(",")
			if parts.size() >= 3:
				return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
			return Vector3i.ZERO
		ExcelStructure.FieldType.ARRAY_INT:
			var parts = value_str.split(",")
			var result: Array[int] = []
			for part in parts:
				if part.strip_edges().is_valid_int():
					result.append(int(part.strip_edges()))
			return result
		ExcelStructure.FieldType.ARRAY_FLOAT:
			var parts = value_str.split(",")
			var result: Array[float] = []
			for part in parts:
				if part.strip_edges().is_valid_float():
					result.append(float(part.strip_edges()))
			return result
		ExcelStructure.FieldType.ARRAY_STRING:
			return value_str.split(",")
		ExcelStructure.FieldType.ENUM:
			return _convert_enum_value(value_str, enum_type)
		_:
			return value_str

# 将key转换为合适的类型（如果是数字则转为整数，否则保持字符串）
static func _convert_key_to_appropriate_type(key_str: String):
	# 先去除前后空格
	key_str = key_str.strip_edges()
	
	# 检查是否为空
	if key_str.is_empty():
		return ""
	
	# 检查是否是整数
	if key_str.is_valid_int():
		return int(key_str)
		# 检查是否是浮点数，如果是且没有小数部分，转为整数
	elif key_str.is_valid_float():
		var float_val = float(key_str)
		if float_val == floor(float_val):  # 没有小数部分
			return int(float_val)
		else:
			return float_val
	else:
		return key_str

# 初始化枚举缓存
static func _init_enum_cache():
	if enum_cache.size() > 0:
		return  # 已经初始化过了
	
	if enums_script == null:
		push_error("无法加载enums.gd")
		return
	
	# 通过反射获取枚举定义
	var enums_class = enums_script
	
	# 获取所有枚举类型
	var script_constants = enums_class.get_script_constant_map()
	
	for enum_name in script_constants.keys():
		var enum_dict = script_constants[enum_name]
		if typeof(enum_dict) == TYPE_DICTIONARY:
			enum_cache[enum_name] = enum_dict
			print("Excel导出: 缓存枚举 %s -> %s" % [enum_name, enum_dict])

# 转换枚举值
static func _convert_enum_value(value_str: String, enum_type: String) -> int:
	# 确保枚举缓存已初始化
	_init_enum_cache()
	
	if enum_type.is_empty():
		push_error("枚举类型名称为空")
		return 0
	
	if not enum_cache.has(enum_type):
		push_error("未找到枚举类型: %s" % enum_type)
		return 0
	
	var enum_dict = enum_cache[enum_type]
	
	# 处理组合值 (例如: "READ|WRITE")
	if "|" in value_str:
		return _convert_flag_enum_value(value_str, enum_dict)
	else:
		return _convert_single_enum_value(value_str, enum_dict)

# 转换单个枚举值
static func _convert_single_enum_value(value_str: String, enum_dict: Dictionary) -> int:
	var clean_value = value_str.strip_edges()
	
	if enum_dict.has(clean_value):
		var result = enum_dict[clean_value]
		print("Excel导出: 枚举转换 %s -> %d" % [clean_value, result])
		return result
	else:
		push_error("未找到枚举值: %s" % clean_value)
		return 0

# 转换标志枚举组合值
static func _convert_flag_enum_value(value_str: String, enum_dict: Dictionary) -> int:
	var parts = value_str.split("|")
	var result = 0
	
	for part in parts:
		var clean_part = part.strip_edges()
		if enum_dict.has(clean_part):
			result |= enum_dict[clean_part]
		else:
			push_error("未找到枚举值: %s" % clean_part)
	
	print("Excel导出: 组合枚举转换 %s -> %d" % [value_str, result])
	return result
