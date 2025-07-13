extends Control
class_name CharacterDetailPanel

# UI组件引用
@onready var character_name_label: Label = %CharacterNameLabel
@onready var character_sprite: TextureRect = %CharacterSprite
@onready var close_button: Button = %CloseButton
@onready var health_bar: AttributeStatusBar = %HealthBar
@onready var mana_bar: AttributeStatusBar = %ManaBar
@onready var skills_container: VBoxContainer = %SkillsContainer
@onready var status_container: GridContainer = %StatusContainer
@onready var other_attributes_grid: GridContainer = %OtherAttributesGrid

# 当前显示的角色引用
var _character: Character = null

# 状态图标字典，用于快速查找和更新
# Key: status_id (StringName), Value: SkillStatusIcon
var _status_icons: Dictionary = {}

# 技能按钮字典，用于快速查找和更新
# Key: skill_id (StringName), Value: SkillButton
var _skill_buttons: Dictionary = {}

# 预加载场景
@export var skill_status_icon_scene: PackedScene = preload("res://scenes/ui/skill_status_icon.tscn")
# @export var skill_button_scene: PackedScene = preload("res://scenes/ui/skill_button.tscn")

# 信号
signal closed

func _ready() -> void:
	# 初始状态为隐藏
	visible = false
	
	# 连接关闭按钮信号
	close_button.pressed.connect(_on_close_button_pressed)

	# 清除预设的技能和状态容器内容
	_clear_skills_container()
	_clear_status_container()

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

## 隐藏面板
func hide_panel() -> void:
	visible = false
	closed.emit()

## 更新角色信息显示
func _update_character_info() -> void:
	if not _character:
		return
	
	# 更新基本信息
	character_name_label.text = _character.character_name
	
	# 显示角色图标
	character_sprite.texture = _character.character_data.icon
	var skill_component: CharacterSkillComponent = _character.skill_component
	
	health_bar.setup(skill_component.get_attribute("CurrentHealth"), skill_component.get_attribute("MaxHealth"))
	mana_bar.setup(skill_component.get_attribute("CurrentMana"), skill_component.get_attribute("MaxMana"))

	# 更新其他属性标签
	for child : AttributeLabel in other_attributes_grid.get_children():
		child.setup(skill_component.get_attribute_set())
	
	# 更新技能和状态显示
	_update_skills_display()
	_update_status_display()

## 清除技能容器内容
func _clear_skills_container() -> void:
	# 清除所有技能按钮
	for skill_id in _skill_buttons.keys():
		var skill_button = _skill_buttons[skill_id]
		skill_button.queue_free()
	
	# 清空字典
	_skill_buttons.clear()
	
	# 清除容器中的其他子节点
	for child in skills_container.get_children():
		child.queue_free()

## 清除状态容器内容
func _clear_status_container() -> void:
	# 清除所有状态图标
	for status_id in _status_icons.keys():
		var status_icon = _status_icons[status_id]
		status_icon.queue_free()
	
	# 清空字典
	_status_icons.clear()
	
	# 清除容器中的其他子节点
	for child in status_container.get_children():
		child.queue_free()

## 更新技能显示
func _update_skills_display() -> void:
	if not _character or not _character.skill_component:
		return
	
	# 清除现有的技能按钮
	_clear_skills_container()
	
	# 获取角色的所有技能
	var available_skills = _character.skill_component.get_available_skills()
	if available_skills.is_empty():
		# 如果没有技能，添加一个提示标签
		var label = Label.new()
		label.text = "没有可用的技能"
		skills_container.add_child(label)
		return
	
	# 添加每个技能的按钮
	for skill in available_skills:
		_add_skill_button(skill)

## 添加技能按钮
func _add_skill_button(skill_data: SkillData) -> void:
	var skill_button : Button = Button.new()
	skill_button.text = skill_data.skill_name
	skills_container.add_child(skill_button)
	_skill_buttons[skill_data.skill_id] = skill_button
	skill_button.tooltip_text = skill_data.get_full_description()

## 更新状态显示
func _update_status_display() -> void:
	if not _character or not _character.skill_component:
		return
	
	# 清除现有的状态图标
	_clear_status_container()
	
	# 获取当前所有状态
	var active_statuses = _character.skill_component.get_active_statuses()
	if active_statuses.is_empty():
		# 如果没有状态，添加一个提示标签
		var label = Label.new()
		label.text = "没有活动的状态效果"
		status_container.add_child(label)
		return
	
	# 添加每个状态的图标
	for status in active_statuses:
		_add_status_icon(status)

## 添加状态图标
func _add_status_icon(status_data: SkillStatusData) -> void:
	if not status_data or not skill_status_icon_scene:
		return
	
	# 检查是否已存在该状态的图标
	if _status_icons.has(status_data.status_id):
		# 如果已存在，更新它
		_status_icons[status_data.status_id].update_status(status_data)
		return
	
	# 创建新的状态图标
	var status_icon = skill_status_icon_scene.instantiate()
	if not status_icon is SkillStatusIcon:
		push_error("CharacterDetailPanel: 实例化的状态图标不是SkillStatusIcon类型")
		return
	
	# 添加到容器
	status_container.add_child(status_icon)
	
	# 设置状态数据
	status_icon.setup(status_data)
	
	# 保存到字典中
	_status_icons[status_data.status_id] = status_icon

## 关闭按钮点击处理
func _on_close_button_pressed() -> void:
	hide_panel()
