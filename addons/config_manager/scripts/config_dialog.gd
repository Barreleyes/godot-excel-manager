@tool
extends AcceptDialog

@onready var excel_root_edit: LineEdit = $VBoxContainer/ExcelRootContainer/ExcelRootEdit
@onready var excel_root_browse_btn: Button = $VBoxContainer/ExcelRootContainer/ExcelRootBrowseBtn
@onready var classes_root_edit: LineEdit = $VBoxContainer/ClassesRootContainer/ClassesRootEdit
@onready var classes_root_browse_btn: Button = $VBoxContainer/ClassesRootContainer/ClassesRootBrowseBtn
@onready var json_export_edit: LineEdit = $VBoxContainer/JsonExportContainer/JsonExportEdit
@onready var json_export_browse_btn: Button = $VBoxContainer/JsonExportContainer/JsonExportBrowseBtn
@onready var enum_path_edit: LineEdit = $VBoxContainer/EnumPathContainer/EnumPathEdit
@onready var enum_path_browse_btn: Button = $VBoxContainer/EnumPathContainer/EnumPathBrowseBtn
@onready var cancel_btn: Button = $VBoxContainer/ButtonContainer/CancelBtn
@onready var save_btn: Button = $VBoxContainer/ButtonContainer/SaveBtn
@onready var dir_dialog: FileDialog = $DirDialog

var config_manager: Control
var current_browse_target: LineEdit

signal settings_changed(excel_root: String, classes_root: String, json_export: String, enum_path: String)

func _ready():
	_connect_signals()

func _connect_signals():
	excel_root_browse_btn.pressed.connect(_on_excel_root_browse_pressed)
	classes_root_browse_btn.pressed.connect(_on_classes_root_browse_pressed)
	json_export_browse_btn.pressed.connect(_on_json_export_browse_pressed)
	enum_path_browse_btn.pressed.connect(_on_enum_path_browse_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	save_btn.pressed.connect(_on_save_pressed)
	dir_dialog.dir_selected.connect(_on_dir_selected)

func setup(manager: Control, excel_root: String, classes_root: String, json_export: String = "res://Configs/Json/", enum_path: String = "res://Scripts/Enums/"):
	config_manager = manager
	excel_root_edit.text = excel_root
	classes_root_edit.text = classes_root
	json_export_edit.text = json_export
	enum_path_edit.text = enum_path

func _on_excel_root_browse_pressed():
	current_browse_target = excel_root_edit
	dir_dialog.current_dir = excel_root_edit.text
	dir_dialog.popup_centered(Vector2i(600, 400))

func _on_classes_root_browse_pressed():
	current_browse_target = classes_root_edit
	dir_dialog.current_dir = classes_root_edit.text
	dir_dialog.popup_centered(Vector2i(600, 400))

func _on_json_export_browse_pressed():
	current_browse_target = json_export_edit
	dir_dialog.current_dir = json_export_edit.text
	dir_dialog.popup_centered(Vector2i(600, 400))

func _on_enum_path_browse_pressed():
	current_browse_target = enum_path_edit
	dir_dialog.current_dir = enum_path_edit.text
	dir_dialog.popup_centered(Vector2i(600, 400))

func _on_dir_selected(path: String):
	if current_browse_target:
		current_browse_target.text = path

func _on_cancel_pressed():
	hide()

func _on_save_pressed():
	settings_changed.emit(excel_root_edit.text, classes_root_edit.text, json_export_edit.text, enum_path_edit.text)
	hide()
