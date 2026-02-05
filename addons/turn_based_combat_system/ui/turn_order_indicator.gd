extends MarginContainer
class_name TurnOrderIndicator

## 预览的角色数量
const MAX_PREVIEW_CHARACTERS = 5

## UI组件引用
@onready var title_label: Label = %TitleLabel
@onready var icons_container: HBoxContainer = %IconsContainer
@onready var current_turn_marker: ColorRect = %CurrentTurnMarker

## 角色图标场景
@export var CHARACTER_ICON : PackedScene = preload("res://addons/turn_based_combat_system/ui/character_icon.tscn")

## 当前角色图标列表
var _character_icons: Array[CharacterIcon] = []

func _ready() -> void:
	# 初始化
	_clear_icons()
	
	current_turn_marker.visible = false
	
	for c in icons_container.get_children():
		c.queue_free()

## 更新回合顺序显示
func update_turn_order(characters: Array, current_character_index: int) -> void:
	# 清除现有图标
	_clear_icons()

	# 创建并添加角色图标
	for character in characters:
		# 创建角色图标
		var icon_instance = _create_character_icon(character)
		if not is_instance_valid(icon_instance):
			continue
		
		# 添加到容器
		icons_container.add_child(icon_instance)
		_character_icons.append(icon_instance)

## 设置标题
func set_title(title: String) -> void:
	title_label.text = title
	
## 创建角色图标
func _create_character_icon(character: Node) -> CharacterIcon:
	var icon : Texture2D = character.get_icon() if character.has_method("get_icon") else null
	if not is_instance_valid(icon):
		push_error("角色图标不能为空！")
		return null
	var icon_instance = CHARACTER_ICON.instantiate()
	if not is_instance_valid(icon_instance):
		push_error("角色图标实例化失败！")
		return null
	icon_instance.setup(icon)
	return icon_instance

## 清除所有图标
func _clear_icons() -> void:
	# 移除现有的所有图标
	for icon_instance in _character_icons:
		if is_instance_valid(icon_instance):
			icon_instance.queue_free()
	
	# 清空列表
	_character_icons.clear()
