@tool
class_name EnumStructure
extends RefCounted

# 枚举值结构
class EnumValue:
	var name: String
	var value: int
	var comment: String
	
	func _init(p_name: String = "", p_value: int = 0, p_comment: String = ""):
		name = p_name
		value = p_value
		comment = p_comment

# 枚举定义结构
var name: String
var is_flag: bool
var comment: String
var values: Array[EnumValue]

func _init(p_name: String = "", p_is_flag: bool = false, p_comment: String = ""):
	name = p_name
	is_flag = p_is_flag
	comment = p_comment
	values = []

func add_value(value_name: String, value_int: int = -1, value_comment: String = "") -> EnumValue:
	var enum_value = EnumValue.new(value_name, value_int, value_comment)
	
	# 如果没有指定值，自动分配
	if value_int == -1:
		if is_flag:
			# Flag模式：使用2的幂次方
			var power = 0
			while (1 << power) in get_used_values():
				power += 1
			enum_value.value = 1 << power
		else:
			# 普通模式：递增
			var max_value = -1
			for v in values:
				if v.value > max_value:
					max_value = v.value
			enum_value.value = max_value + 1
	
	values.append(enum_value)
	return enum_value

func remove_value(index: int):
	if index >= 0 and index < values.size():
		values.remove_at(index)

func move_value_up(index: int):
	if index > 0 and index < values.size():
		var temp = values[index]
		values[index] = values[index - 1]
		values[index - 1] = temp

func move_value_down(index: int):
	if index >= 0 and index < values.size() - 1:
		var temp = values[index]
		values[index] = values[index + 1]
		values[index + 1] = temp

func get_used_values() -> Array[int]:
	var used: Array[int] = []
	for v in values:
		used.append(v.value)
	return used

func get_next_flag_value() -> int:
	var power = 0
	var used_values = get_used_values()
	while (1 << power) in used_values:
		power += 1
	return 1 << power

func get_next_sequential_value() -> int:
	var max_value = -1
	for v in values:
		if v.value > max_value:
			max_value = v.value
	return max_value + 1
