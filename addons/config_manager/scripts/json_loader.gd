@tool
class_name JsonLoader
extends RefCounted

# 简化的JSON加载器
static  var table_classes_script = load("res://Scripts/ConfigClasses/table_classes.gd")
# 加载所有JSON文件到DataManager
static func load_all_json_data(json_directory_path: String) -> bool:
	print("开始加载JSON数据从目录: %s" % json_directory_path)
	
	# 检查目录是否存在
	var dir = DirAccess.open(json_directory_path)
	if dir == null:
		push_error("无法打开JSON目录: %s" % json_directory_path)
		return false
	
	var success_count = 0
	var total_count = 0
	
	# 遍历目录中的所有JSON文件
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			total_count += 1
			var table_name = file_name.get_basename()  # 去掉.json扩展名
			
			if _load_single_table_data(json_directory_path, table_name):
				success_count += 1
			else:
				push_error("加载表数据失败: %s" % table_name)
		
		file_name = dir.get_next()
	
	print("JSON数据加载完成: 成功 %d/%d 个表" % [success_count, total_count])
	return success_count == total_count

# 加载单个表的数据
static func _load_single_table_data(json_directory_path: String, table_name: String) -> bool:
	# 构建JSON文件路径
	var json_file_path = json_directory_path.path_join(table_name + ".json")
	
	# 检查文件是否存在
	if not FileAccess.file_exists(json_file_path):
		print("JSON文件不存在: %s" % json_file_path)
		return false
	
	# 读取JSON文件
	var file = FileAccess.open(json_file_path, FileAccess.READ)
	if file == null:
		push_error("无法打开JSON文件: %s" % json_file_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("JSON解析失败: %s" % json_file_path)
		return false
	
	var table_data = json.data
	if typeof(table_data) != TYPE_DICTIONARY:
		push_error("JSON数据格式错误: %s" % json_file_path)
		return false
	
	# 通用加载表数据
	if _load_table_data_generic(table_name, table_data):
		print("成功加载表数据: %s (%d 条记录)" % [table_name, table_data.size()])
		return true
	else:
		print("加载表数据失败: %s" % table_name)
		return false

# 通用表数据加载方法
static func _load_table_data_generic(table_name: String, table_data: Dictionary) -> bool:
	# 1. 获取主表类
	var main_class = _get_table_class(table_name)
	if main_class == null:
		push_error("无法找到表类: Dt_%s" % table_name)
		return false
	
	# 2. 清空DataManager中对应的字典
	_clear_data_manager_table(table_name)
	
	# 3. 遍历JSON数据，创建对象实例
	for key in table_data.keys():
		var row_data = table_data[key]
		var item = main_class.new()
		
		# 4. 设置主表对象的属性
		_set_object_properties(item, row_data, table_name)
		
		# 5. 将对象存入DataManager
		_set_data_manager_item(table_name, str(key), item)
	
	return true

# 获取主表类
static func _get_table_class(table_name: String):
	var class_name_str = "Dt_" + table_name
	return _get_class_from_table_classes(class_name_str)

# 获取子表类
static func _get_sub_table_class(table_name: String):
	var class_name_str = "DtSub_" + table_name
	return _get_class_from_table_classes(class_name_str)

# 从TableClasses中获取类
static func _get_class_from_table_classes(class_name_str: String):
	
	if table_classes_script == null:
		push_error("无法加载table_classes.gd")
		return null
	
	# 通过脚本获取嵌套类
	var nested_class = table_classes_script.get(class_name_str)
	return nested_class

# 设置对象属性（通用方法）
static func _set_object_properties(obj: Object, data: Dictionary, table_name: String):
	var property_list = obj.get_property_list()
	
	for property in property_list:
		var prop_name = property.name
		
		# 跳过内置属性和非脚本变量
		if prop_name.begins_with("_") or not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		
		if data.has(prop_name):
			var value = data[prop_name]
			
			# 检查是否是Dictionary类型（可能是子键数据）
			if typeof(value) == TYPE_DICTIONARY and _is_dictionary_property(property):
				# 处理子键数据 - 根据表名获取对应的子类
				var sub_class = _get_sub_table_class(table_name)
				_set_sub_key_data(obj, prop_name, value, sub_class)
			else:
				# 设置普通属性
				_set_property_value(obj, prop_name, value, property.type)

# 判断属性是否是Dictionary类型
static func _is_dictionary_property(property: Dictionary) -> bool:
	var type_str = property.get("class_name", "")
	return type_str.contains("Dictionary") or property.type == TYPE_DICTIONARY

# 设置子键数据
static func _set_sub_key_data(obj: Object, prop_name: String, sub_data: Dictionary, sub_class):
	if sub_class == null:
		# 如果没有子类，直接设置为原始字典
		obj.set(prop_name, sub_data)
		return
	
	var sub_dict = obj.get(prop_name)
	
	for sub_key in sub_data.keys():
		var sub_row_data = sub_data[sub_key]
		var sub_item = sub_class.new()
		
		# 递归设置子对象属性（子对象不再有嵌套子键）
		_set_object_properties(sub_item, sub_row_data, "")
		sub_dict[str(sub_key)] = sub_item
	
	#obj.set(prop_name, sub_dict)
	pass

# 设置属性值（带类型转换）
static func _set_property_value(obj: Object, prop_name: String, value, expected_type: int):
	var converted_value = _convert_value_to_type(value, expected_type)
	obj.set(prop_name, converted_value)

# 类型转换
static func _convert_value_to_type(value, target_type: int):
	match target_type:
		TYPE_STRING:
			return str(value)
		TYPE_INT:
			if typeof(value) == TYPE_STRING:
				return value.to_int()
			return int(value)
		TYPE_FLOAT:
			if typeof(value) == TYPE_STRING:
				return value.to_float()
			return float(value)
		TYPE_BOOL:
			if typeof(value) == TYPE_STRING:
				return value.to_lower() == "true"
			return bool(value)
		TYPE_VECTOR2:
			if typeof(value) == TYPE_STRING:
				var parts = value.split(",")
				if parts.size() >= 2:
					return Vector2(parts[0].to_float(), parts[1].to_float())
			return Vector2.ZERO
		TYPE_VECTOR2I:
			if typeof(value) == TYPE_STRING:
				var parts = value.split(",")
				if parts.size() >= 2:
					return Vector2i(parts[0].to_int(), parts[1].to_int())
			return Vector2i.ZERO
		TYPE_VECTOR3:
			if typeof(value) == TYPE_STRING:
				var parts = value.split(",")
				if parts.size() >= 3:
					return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
			return Vector3.ZERO
		TYPE_VECTOR3I:
			if typeof(value) == TYPE_STRING:
				var parts = value.split(",")
				if parts.size() >= 3:
					return Vector3i(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
			return Vector3i.ZERO
		TYPE_ARRAY:
			if typeof(value) == TYPE_STRING:
				return value.split(",")
			return []
		_:
			return value

# 清空DataManager中的表数据
static func _clear_data_manager_table(table_name: String):
	var table_dict = _get_data_manager_table(table_name)
	if table_dict != null:
		table_dict.clear()

# 获取DataManager中的表字典
static func _get_data_manager_table(table_name: String):
	# 使用DataManager的get_table_data方法
	return DataManager.get(table_name)

# 设置DataManager中的表项
static func _set_data_manager_item(table_name: String, key: String, item):
	var table_dict = _get_data_manager_table(table_name)
	if table_dict != null:
		table_dict[key] = item
