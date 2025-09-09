@tool
extends HBoxContainer
class_name FieldRow

# 字段行控件

signal field_moved_up(field_row: FieldRow)
signal field_moved_down(field_row: FieldRow)
signal field_deleted(field_row: FieldRow)
signal field_changed(field_row: FieldRow)

@onready var field_name_edit: LineEdit = $FieldNameEdit
@onready var field_type_option: OptionButton = $FieldTypeOption
@onready var enum_type_option: OptionButton = $HBoxContainer/EnumTypeOption
@onready var default_value_edit: LineEdit = $HBoxContainer/DefaultValueEdit
@onready var move_up_btn: Button = $MoveUpBtn
@onready var move_down_btn: Button = $MoveDownBtn
@onready var delete_btn: Button = $DeleteBtn

var field_data: Dictionary = {}
var available_enums: Array = []

func _ready():
	_setup_field_types()
	_connect_signals()

func _setup_field_types():
	field_type_option.clear()
	var field_types = [
		"Key", "String", "StringName", "int", "float", "bool",
		"Vector2", "Vector2i", "Vector3", "Vector3i", "NodePath",
		"ArrayInt", "ArrayFloat", "ArrayString", "Enum"
	]
	for type_name in field_types:
		field_type_option.add_item(type_name)

func _connect_signals():
	field_name_edit.text_changed.connect(_on_field_changed)
	field_type_option.item_selected.connect(_on_type_changed)
	enum_type_option.item_selected.connect(_on_enum_type_changed)
	default_value_edit.text_changed.connect(_on_field_changed)
	move_up_btn.pressed.connect(_on_move_up_pressed)
	move_down_btn.pressed.connect(_on_move_down_pressed)
	delete_btn.pressed.connect(_on_delete_pressed)

func setup_field(field_name: String, field_type: String, default_value: String = ""):
	field_name_edit.text = field_name
	default_value_edit.text = default_value
	
	# 检查是否是枚举类型 (E_开头)
	if field_type.begins_with("E_"):
		# 设置为枚举类型
		for i in field_type_option.get_item_count():
			if field_type_option.get_item_text(i) == "Enum":
				field_type_option.selected = i
				break
		
		# 显示枚举选择器并设置选中的枚举
		_show_enum_selector(true)
		var enum_name = field_type.substr(2)  # 去掉 "E_" 前缀
		_select_enum_type(enum_name)
	else:
		# 设置普通字段类型
		for i in field_type_option.get_item_count():
			if field_type_option.get_item_text(i) == field_type:
				field_type_option.selected = i
				break
		_show_enum_selector(false)
	
	_update_field_data()

func get_field_name() -> String:
	return field_name_edit.text.strip_edges()

func get_field_type() -> String:
	var base_type = field_type_option.get_item_text(field_type_option.selected)
	if base_type == "Enum" and enum_type_option.visible and enum_type_option.selected >= 0:
		var enum_name = enum_type_option.get_item_text(enum_type_option.selected)
		return "E_" + enum_name
	return base_type

func get_default_value() -> String:
	return default_value_edit.text.strip_edges()

func set_move_buttons_enabled(up_enabled: bool, down_enabled: bool):
	move_up_btn.disabled = not up_enabled
	move_down_btn.disabled = not down_enabled

func _update_field_data():
	field_data = {
		"name": get_field_name(),
		"type": get_field_type(),
		"default_value": get_default_value()
	}

func _on_field_changed(text: String = ""):
	_update_field_data()
	field_changed.emit(self)

func _on_type_changed(index: int):
	var selected_type = field_type_option.get_item_text(index)
	
	# 如果选择了枚举类型，显示枚举选择器
	if selected_type == "Enum":
		_show_enum_selector(true)
		if enum_type_option.get_item_count() > 0 and enum_type_option.selected < 0:
			enum_type_option.selected = 0  # 默认选择第一个枚举
	else:
		_show_enum_selector(false)
	
	_update_field_data()
	field_changed.emit(self)

func _on_move_up_pressed():
	field_moved_up.emit(self)

func _on_move_down_pressed():
	field_moved_down.emit(self)

func _on_delete_pressed():
	field_deleted.emit(self)

# 设置可用的枚举列表
func set_available_enums(enums: Array):
	available_enums = enums
	_update_enum_options()

# 更新枚举选择器的选项
func _update_enum_options():
	enum_type_option.clear()
	for enum_def in available_enums:
		enum_type_option.add_item(enum_def.name)

# 显示或隐藏枚举选择器
func _show_enum_selector(show: bool):
	enum_type_option.visible = show
#	default_value_edit.visible= !show

# 选择特定的枚举类型
func _select_enum_type(enum_name: String):
	for i in enum_type_option.get_item_count():
		if enum_type_option.get_item_text(i) == enum_name:
			enum_type_option.selected = i
			break

# 当枚举类型改变时
func _on_enum_type_changed(index: int):
	_update_field_data()
	field_changed.emit(self)
