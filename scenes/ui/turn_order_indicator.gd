extends MarginContainer
class_name TurnOrderIndicator

## 角色图标场景
const CHARACTER_ICON = preload("res://scenes/ui/character_icon.tscn")

## 预览的角色数量
const MAX_PREVIEW_CHARACTERS = 5

## UI组件引用
@onready var title_label: Label = %TitleLabel
@onready var icons_container: HBoxContainer = %IconsContainer
@onready var current_turn_marker: ColorRect = %CurrentTurnMarker

## 当前角色图标列表
var _character_icons: Array[CharacterIcon] = []

## 当前行动角色索引
var _current_character_index: int = 0

## 当前回合标记的大小
var _marker_size: Vector2 = Vector2(64, 4)

func _ready() -> void:
	# 初始化
	_clear_icons()
	
	# 设置当前回合标记
	current_turn_marker.custom_minimum_size = _marker_size
	current_turn_marker.visible = false
	
	for c in icons_container.get_children():
		c.queue_free()

## 更新回合顺序显示
func update_turn_order(characters: Array, current_character_index: int) -> void:
	# 清除现有图标
	_clear_icons()
	
	# 保存当前角色索引
	_current_character_index = current_character_index
	
	# 限制显示的角色数量
	var display_count = min(characters.size(), MAX_PREVIEW_CHARACTERS)
	
	# 创建并添加角色图标
	for i in range(display_count):
		var character_index = (current_character_index + i) % characters.size()
		var character = characters[character_index]
		
		# 创建角色图标
		var icon = _create_character_icon(character)
		
		# 添加到容器
		icons_container.add_child(icon)
		_character_icons.append(icon)
	
	# 更新当前回合标记
	_update_current_turn_marker()

## 创建角色图标
func _create_character_icon(character: Character) -> CharacterIcon:
	var icon = CHARACTER_ICON.instantiate()
	icon.setup(character)
	return icon

## 清除所有图标
func _clear_icons() -> void:
	# 移除现有的所有图标
	for icon in _character_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	
	# 清空列表
	_character_icons.clear()

## 更新当前回合标记位置
func _update_current_turn_marker() -> void:
	if _character_icons.is_empty():
		current_turn_marker.visible = false
		return
	
	# 获取当前角色图标
	var current_icon = _character_icons[0]
	
	# 设置标记位置
	var icon_global_pos = current_icon.global_position
	var icon_size = current_icon.size
	
	# 调整标记位置到图标下方
	current_turn_marker.global_position = Vector2(
		icon_global_pos.x,
		icon_global_pos.y + icon_size.y
	)
	
	# 显示标记
	current_turn_marker.visible = true

## 设置标题
func set_title(title: String) -> void:
	title_label.text = title
