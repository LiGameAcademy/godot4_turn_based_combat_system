extends Control
class_name CharacterDetailPanel

# UI组件引用
@onready var character_name_label: Label = %CharacterNameLabel
@onready var character_sprite: TextureRect = %CharacterSprite
@onready var close_button: Button = %CloseButton

# 当前显示的角色引用
var _character: Character = null

# 信号
signal closed

func _ready() -> void:
	# 初始状态为隐藏
	visible = false
	
	# 连接关闭按钮信号
	close_button.pressed.connect(_on_close_button_pressed)

## 显示指定角色的详细信息
func show_character_details(character: Character) -> void:
	if not character:
		push_error("CharacterDetailPanel: 无法显示角色详情，角色为空")
		return
	
	# 保存角色引用
	_character = character
	
	# 更新UI显示
	_update_character_info()
	
	# 显示面板
	visible = true

## 更新角色信息显示
func _update_character_info() -> void:
	if not _character:
		return
	
	# 更新基本信息
	character_name_label.text = _character.character_name
	
	# 如果角色有精灵图像，则显示
	if _character.sprite_2d and _character.sprite_2d.texture:
		character_sprite.texture = _character.sprite_2d.texture

## 关闭按钮点击处理
func _on_close_button_pressed() -> void:
	hide_panel()

## 隐藏面板
func hide_panel() -> void:
	visible = false
	emit_signal("closed")
