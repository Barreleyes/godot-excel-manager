@tool
extends Tree
class_name DraggableTree

# 拖拽功能的自定义Tree控件

signal item_dropped(dropped_item: TreeItem, target_item: TreeItem, drop_section: int)

var config_manager: Control
var is_dragging: bool = false
var drag_item: TreeItem
var drag_preview: Control

func setup(manager: Control):
	config_manager = manager
	set_drag_forwarding(_get_drag_data_forwarded, _can_drop_data_forwarded, _drop_data_forwarded)

func _get_drag_data_forwarded(position: Vector2):
	return _get_drag_data(position)

func _can_drop_data_forwarded(position: Vector2, data):
	return _can_drop_data(position, data)

func _drop_data_forwarded(position: Vector2, data):
	_drop_data(position, data)

func _can_drop_data(position: Vector2, data) -> bool:
	if not data.has("type") or data.type != "file_tree_item":
		return false
	
	var item = get_item_at_position(position)
	if item == null:
		return false
	
	var metadata = item.get_metadata(0)
	if metadata == null:
		return false
	
	# 只能拖拽到文件夹上
	return metadata.type == "folder"

func _drop_data(position: Vector2, data) -> void:
	if not data.has("type") or data.type != "file_tree_item":
		return
	
	var target_item = get_item_at_position(position)
	if target_item == null:
		return
	
	var target_metadata = target_item.get_metadata(0)
	if target_metadata == null or target_metadata.type != "folder":
		return
	
	var source_item = data.item
	var source_metadata = source_item.get_metadata(0)
	if source_metadata == null:
		return
	
	# 执行文件移动
	_move_file_or_folder(source_metadata.path, target_metadata.path, source_metadata.type)

func _get_drag_data(position: Vector2):
	var item = get_item_at_position(position)
	if item == null:
		return null
	
	var metadata = item.get_metadata(0)
	if metadata == null:
		return null
	
	# 创建拖拽预览
	var preview = Label.new()
	preview.text = item.get_text(0)
	preview.add_theme_color_override("font_color", Color.WHITE)
	preview.add_theme_color_override("font_shadow_color", Color.BLACK)
	set_drag_preview(preview)
	
	is_dragging = true
	drag_item = item
	
	return {
		"type": "file_tree_item",
		"item": item,
		"path": metadata.path,
		"item_type": metadata.type
	}

func _move_file_or_folder(source_path: String, target_folder: String, item_type: String):
	var file_name = source_path.get_file()
	var new_path = target_folder.path_join(file_name)
	
	if source_path == new_path:
		print("源路径和目标路径相同，跳过移动")
		return
	
	var success = false
	
	if item_type == "excel":
		# 移动文件
		var source_file = FileAccess.open(source_path, FileAccess.READ)
		if source_file:
			var content = source_file.get_buffer(source_file.get_length())
			source_file.close()
			
			var target_file = FileAccess.open(new_path, FileAccess.WRITE)
			if target_file:
				target_file.store_buffer(content)
				target_file.close()
				
				# 删除源文件
				if DirAccess.remove_absolute(source_path) == OK:
					success = true
					print("文件移动成功: %s -> %s" % [source_path, new_path])
				else:
					print("删除源文件失败: " + source_path)
					DirAccess.remove_absolute(new_path)  # 清理目标文件
			else:
				print("创建目标文件失败: " + new_path)
		else:
			print("打开源文件失败: " + source_path)
	
	elif item_type == "folder":
		# 移动文件夹
		success = _move_directory(source_path, new_path)
	
	if success and config_manager:
		config_manager.refresh_file_tree()

func _move_directory(source_dir: String, target_dir: String) -> bool:
	var dir = DirAccess.open("res://")
	if dir == null:
		return false
	
	# 创建目标目录
	if not dir.dir_exists(target_dir):
		if dir.make_dir_recursive(target_dir) != OK:
			print("创建目标目录失败: " + target_dir)
			return false
	
	# 复制所有文件和子目录
	if not _copy_directory_contents(source_dir, target_dir):
		return false
	
	# 删除源目录
	if _remove_directory_recursive(source_dir):
		print("文件夹移动成功: %s -> %s" % [source_dir, target_dir])
		return true
	else:
		print("删除源目录失败: " + source_dir)
		return false

func _copy_directory_contents(source_dir: String, target_dir: String) -> bool:
	var dir = DirAccess.open(source_dir)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var source_path = source_dir.path_join(file_name)
		var target_path = target_dir.path_join(file_name)
		
		if dir.current_is_dir():
			# 递归复制子目录
			var sub_dir = DirAccess.open("res://")
			if sub_dir.make_dir_recursive(target_path) != OK:
				return false
			if not _copy_directory_contents(source_path, target_path):
				return false
		else:
			# 复制文件
			if dir.copy(source_path, target_path) != OK:
				print("复制文件失败: %s -> %s" % [source_path, target_path])
				return false
		
		file_name = dir.get_next()
	
	return true

func _remove_directory_recursive(dir_path: String) -> bool:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	# 先删除所有内容
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		
		if dir.current_is_dir():
			if not _remove_directory_recursive(full_path):
				return false
		else:
			if DirAccess.remove_absolute(full_path) != OK:
				return false
		
		file_name = dir.get_next()
	
	# 删除空目录
	var parent_dir = DirAccess.open(dir_path.get_base_dir())
	return parent_dir.remove(dir_path.get_file()) == OK
