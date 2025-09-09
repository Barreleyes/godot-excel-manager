@tool
class_name EnumParser
extends RefCounted

const EnumStructure = preload("res://addons/config_manager/scripts/enum_structure.gd")

# 从GDScript文件解析所有枚举定义
static func parse_enum_file(file_path: String) -> Array[EnumStructure]:
	var enums: Array[EnumStructure] = []
	
	if not FileAccess.file_exists(file_path):
		return enums
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("无法打开文件: " + file_path)
		return enums
	
	var content = file.get_as_text()
	file.close()
	
	return _parse_enum_content(content)

# 解析文件内容中的枚举定义
static func _parse_enum_content(content: String) -> Array[EnumStructure]:
	var enums: Array[EnumStructure] = []
	var lines = content.split("\n")
	
	var current_enum: EnumStructure = null
	var in_enum_block = false
	var brace_count = 0
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		# 跳过空行和注释行
		if line.is_empty() or line.begins_with("#"):
			continue
		
		# 检测枚举定义开始
		var enum_match = _match_enum_declaration(line)
		if enum_match:
			current_enum = EnumStructure.new()
			current_enum.name = enum_match.name
			current_enum.is_flag = enum_match.is_flag
			current_enum.comment = enum_match.comment
			in_enum_block = true
			brace_count = 0
			continue
		
		if in_enum_block and current_enum:
			# 计算大括号数量
			brace_count += line.count("{") - line.count("}")
			
			# 解析枚举值
			var value_match = _match_enum_value(line)
			if value_match:
				current_enum.values.append(EnumStructure.EnumValue.new(
					value_match.name, 
					value_match.value, 
					value_match.comment
				))
			
			# 检测枚举结束
			if brace_count <= 0 and (line.contains("}") or i == lines.size() - 1):
				enums.append(current_enum)
				current_enum = null
				in_enum_block = false
	
	return enums

# 匹配枚举声明行
static func _match_enum_declaration(line: String) -> Dictionary:
	var result = {}
	
	# 匹配 enum Name { # comment
	var regex = RegEx.new()
	regex.compile(r"^\s*enum\s+(\w+)\s*\{?\s*(#.*)?$")
	var regex_result = regex.search(line)
	
	if regex_result:
		result.name = regex_result.get_string(1)
		var comment = regex_result.get_string(2).strip_edges().trim_prefix("#").strip_edges()
		result.comment = comment
		
		# 检查注释是否包含[flags]标记
		result.is_flag = comment.begins_with("[flags]")
		if result.is_flag:
			# 移除[flags]标记，保留剩余描述
			result.comment = comment.trim_prefix("[flags]").strip_edges()
		
		return result
	
	return {}

# 匹配枚举值行
static func _match_enum_value(line: String) -> Dictionary:
	var result = {}
	
	# 匹配 NAME = VALUE, # comment 或 NAME, # comment
	var regex = RegEx.new()
	regex.compile(r"^\s*(\w+)\s*(?:=\s*(\d+))?\s*,?\s*(#.*)?$")
	var regex_result = regex.search(line)
	
	if regex_result:
		result.name = regex_result.get_string(1)
		var value_str = regex_result.get_string(2)
		result.value = int(value_str) if not value_str.is_empty() else -1
		result.comment = regex_result.get_string(3).strip_edges().trim_prefix("#").strip_edges()
		return result
	
	return {}

# 生成单个枚举的GDScript代码
static func generate_enum_code(enum_def: EnumStructure) -> String:
	var lines: Array[String] = []
	
	# 添加枚举声明，如果是flag类型则在注释中标记
	var declaration = "enum " + enum_def.name + " {"
	if enum_def.is_flag:
		# Flag类型在注释中标记
		var comment_text = "[flags]"
		if not enum_def.comment.is_empty():
			comment_text += " " + enum_def.comment
		declaration += " # " + comment_text
	elif not enum_def.comment.is_empty():
		# 普通枚举只添加描述注释
		declaration += " # " + enum_def.comment
	
	lines.append(declaration)
	
	# 添加枚举值
	for i in range(enum_def.values.size()):
		var value = enum_def.values[i]
		var value_line = "\t" + value.name + " = " + str(value.value)
		
		# 添加逗号（除了最后一项）
		if i < enum_def.values.size() - 1:
			value_line += ","
		
		# 添加注释
		if not value.comment.is_empty():
			value_line += " # " + value.comment
		
		lines.append(value_line)
	
	lines.append("}")
	lines.append("") # 空行分隔
	
	return "\n".join(lines)

# 生成完整的GDScript文件内容
static func generate_enum_file_content(enums: Array[EnumStructure]) -> String:
	var lines: Array[String] = []
	
	# 添加文件头部
	lines.append("@tool")
	lines.append("# 项目枚举定义文件")
	lines.append("# 所有枚举定义都在此文件中统一管理")
	lines.append("# 使用配置管理器进行编辑")
	lines.append("")
	
	# 生成所有枚举
	for enum_def in enums:
		lines.append(generate_enum_code(enum_def))
	
	return "\n".join(lines)

# 保存枚举定义到文件
static func save_enum_file(file_path: String, enums: Array[EnumStructure]) -> bool:
	# 确保目录存在
	var dir = DirAccess.open("res://")
	var dir_path = file_path.get_base_dir()
	if not dir.dir_exists(dir_path):
		if dir.make_dir_recursive(dir_path) != OK:
			push_error("无法创建目录: " + dir_path)
			return false
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("无法创建文件: " + file_path)
		return false
	
	var content = generate_enum_file_content(enums)
	file.store_string(content)
	file.close()
	
	print("枚举文件已保存: " + file_path)
	return true

# 获取固定的枚举文件路径
static func get_enum_file_path(enum_dir: String) -> String:
	return enum_dir.path_join("enums.gd")
