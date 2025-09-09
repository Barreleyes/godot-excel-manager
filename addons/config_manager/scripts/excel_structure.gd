@tool
extends RefCounted
class_name ExcelStructure

# Excel字段类型枚举
enum FieldType {
	KEY,
	BOOL,
	FLOAT, 
	INT,
	NODE_PATH,
	ARRAY_INT,
	ARRAY_FLOAT, 
	ARRAY_STRING,
	STRING,
	STRING_NAME,
	VECTOR2,
	VECTOR2I,
	VECTOR3,
	VECTOR3I,
	ENUM
}
static var enum_prefix="E_"
# 字段信息类
class FieldInfo:
	var name: String
	var type: FieldType
	var default_value: String
	var enum_name: String = ""  # 当type为ENUM时存储枚举名称
	
	func _init(field_name: String = "", field_type: FieldType = FieldType.STRING, def_value: String = "", enum_type_name: String = ""):
		name = field_name
		type = field_type
		default_value = def_value
		enum_name = enum_type_name

# Excel表结构信息
var file_path: String
var table_name: String
var fields: Array[FieldInfo] = []
var primary_keys: Array[int] = [] # 存储主键字段的索引

func _init(path: String = ""):
	file_path = path
	if path:
		table_name = path.get_file().get_basename()

# 添加字段
func add_field(name: String, type: FieldType, default_value: String = "", enum_name: String = "") -> void:
	var field = FieldInfo.new(name, type, default_value, enum_name)
	fields.append(field)
	
	# 如果是KEY类型，添加到主键列表
	if type == FieldType.KEY:
		primary_keys.append(fields.size() - 1)

# 获取字段类型名称
static func get_field_type_name(type: FieldType) -> String:
	match type:
		FieldType.KEY: return "Key"
		FieldType.BOOL: return "bool"
		FieldType.FLOAT: return "float"
		FieldType.INT: return "int"
		FieldType.NODE_PATH: return "NodePath"
		FieldType.ARRAY_INT: return "ArrayInt"
		FieldType.ARRAY_FLOAT: return "ArrayFloat"
		FieldType.ARRAY_STRING: return "ArrayString"
		FieldType.STRING: return "String"
		FieldType.STRING_NAME: return "StringName"
		FieldType.VECTOR2: return "Vector2"
		FieldType.VECTOR2I: return "Vector2i"
		FieldType.VECTOR3: return "Vector3"
		FieldType.VECTOR3I: return "Vector3i"
		FieldType.ENUM: return "Enum"
		_: return "String"

# 获取字段类型名称（支持枚举）
func get_field_type_name_with_enum(field: FieldInfo) -> String:
	if field.type == FieldType.ENUM and not field.enum_name.is_empty():
		return "E_" + field.enum_name
	return get_field_type_name(field.type)

# 从字符串获取字段类型
static func get_field_type_from_string(type_str: String) -> FieldType:
	if type_str.begins_with(enum_prefix):
		return FieldType.ENUM
	
	match type_str.to_lower():
		"key": return FieldType.KEY
		"bool": return FieldType.BOOL
		"float": return FieldType.FLOAT
		"int": return FieldType.INT
		"nodepath": return FieldType.NODE_PATH
		"arrayint": return FieldType.ARRAY_INT
		"arrayfloat": return FieldType.ARRAY_FLOAT
		"arraystring": return FieldType.ARRAY_STRING
		"string": return FieldType.STRING
		"stringname": return FieldType.STRING_NAME
		"vector2": return FieldType.VECTOR2
		"vector2i": return FieldType.VECTOR2I
		"vector3": return FieldType.VECTOR3
		"vector3i": return FieldType.VECTOR3I
		"enum": return FieldType.ENUM
		_: return FieldType.STRING

# 从字符串解析枚举名称
static func get_enum_name_from_string(type_str: String) -> String:
	if type_str.begins_with("E_"):
		return type_str.substr(2)
	return ""

# 获取Godot类型字符串
func get_godot_type_string(type: FieldType) -> String:
	match type:
		FieldType.KEY: return "String"
		FieldType.BOOL: return "bool"
		FieldType.FLOAT: return "float"
		FieldType.INT: return "int"
		FieldType.NODE_PATH: return "NodePath"
		FieldType.ARRAY_INT: return "Array[int]"
		FieldType.ARRAY_FLOAT: return "Array[float]"
		FieldType.ARRAY_STRING: return "Array[String]"
		FieldType.STRING: return "String"
		FieldType.STRING_NAME: return "StringName"
		FieldType.VECTOR2: return "Vector2"
		FieldType.VECTOR2I: return "Vector2i"
		FieldType.VECTOR3: return "Vector3"
		FieldType.VECTOR3I: return "Vector3i"
		FieldType.ENUM: return "int"  # 枚举类型在代码中使用int
		_: return "String"

# 获取带枚举名称的Godot类型字符串
func get_godot_type_string_with_enum(field: FieldInfo) -> String:
	if field.type == FieldType.ENUM and not field.enum_name.is_empty():
		return "Enums."+ field.enum_name
	return get_godot_type_string(field.type)

# 生成类定义代码
func generate_class_definition() -> String:
	var code = "@tool\nclass_name %s\nextends RefCounted\n\n" % table_name
	
	# 添加字段定义
	for field in fields:
		if field.type != FieldType.KEY:
			code += "var %s: %s\n" % [field.name, get_godot_type_string(field.type)]
	
	code += "\n"
	
	# 添加构造函数
	code += "func _init():\n"
	for field in fields:
		if field.type != FieldType.KEY and field.default_value:
			code += "\t%s = %s\n" % [field.name, _format_default_value(field)]
	
	return code

func _format_default_value(field: FieldInfo) -> String:
	match field.type:
		FieldType.STRING, FieldType.STRING_NAME:
			return '"%s"' % field.default_value
		FieldType.BOOL:
			return field.default_value.to_lower()
		FieldType.ARRAY_INT, FieldType.ARRAY_FLOAT, FieldType.ARRAY_STRING:
			return "[]"
		_:
			return field.default_value if field.default_value else "null"
