@tool
extends HBoxContainer

@onready var value_label: Label = $ValueLabel
@onready var name_edit: LineEdit = $NameEdit
@onready var comment_edit: LineEdit = $CommentEdit
@onready var move_up_btn: Button = $MoveUpBtn
@onready var move_down_btn: Button = $MoveDownBtn
@onready var delete_btn: Button = $DeleteBtn

signal value_moved_up(row: Control)
signal value_moved_down(row: Control)
signal value_deleted(row: Control)
signal value_changed(row: Control)

func _ready():
	_connect_signals()

func _connect_signals():
	move_up_btn.pressed.connect(_on_move_up_pressed)
	move_down_btn.pressed.connect(_on_move_down_pressed)
	delete_btn.pressed.connect(_on_delete_pressed)
	name_edit.text_changed.connect(_on_value_changed)
	comment_edit.text_changed.connect(_on_value_changed)

func setup_value(value_name: String, value_int: int, comment: String):
	if not is_node_ready():
		await ready
	
	name_edit.text = value_name
	value_label.text = str(value_int)
	comment_edit.text = comment

func get_value_name() -> String:
	return name_edit.text

func get_value_int() -> int:
	return int(value_label.text)

func get_comment() -> String:
	return comment_edit.text

func set_value_int(value: int):
	value_label.text = str(value)

func set_move_buttons_enabled(can_move_up: bool, can_move_down: bool):
	move_up_btn.disabled = not can_move_up
	move_down_btn.disabled = not can_move_down

func _on_move_up_pressed():
	value_moved_up.emit(self)

func _on_move_down_pressed():
	value_moved_down.emit(self)

func _on_delete_pressed():
	value_deleted.emit(self)

func _on_value_changed(_text: String):
	value_changed.emit(self)
