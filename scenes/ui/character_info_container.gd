extends VBoxContainer
class_name CharacterInfoContainer

@onready var name_label: Label = %NameLabel
@onready var hp_bar: AttributeStatusBar = %HPBar
@onready var mp_bar: AttributeStatusBar = %MPBar
@onready var skill_status_container: HBoxContainer = %SkillStatusContainer

var _display_name: String = ""

# 状态图标字典，用于快速查找和更新
# Key: status_id (StringName), Value: SkillStatusIcon
var _status_icons: Dictionary = {}

# 状态图标场景
@export var skill_status_icon_scene: PackedScene = preload("res://scenes/ui/skill_status_icon.tscn")


func _ready() -> void:
	for child in skill_status_container.get_children():
		child.queue_free()

## 一次性初始化显示（由外部角色调用）
func initialize(display_name: String, hp_current: float, hp_max: float, mp_current: float, mp_max: float) -> void:
	clear_status_icons()
	set_name_text(display_name)
	set_hp_values(hp_current, hp_max)
	set_mp_values(mp_current, mp_max)

## 简单名称设置（适用于任意角色实现）
func set_name_text(display_name: String) -> void:
	_display_name = display_name
	_update_name_display()

## 直接用数值设置 HP（适用于非 SkillAttribute 系统，例如 GAS Vital）
func set_hp_values(current_hp: float, max_hp: float) -> void:
	if hp_bar:
		hp_bar.set_values(current_hp, max_hp)

## 直接用数值设置 MP（适用于非 SkillAttribute 系统，例如 GAS Vital）
func set_mp_values(current_mp: float, max_mp: float) -> void:
	if mp_bar:
		mp_bar.set_values(current_mp, max_mp)

## 更新名称显示
func _update_name_display() -> void:
	name_label.text = _display_name

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
		push_error("CharacterInfoContainer: 实例化的状态图标不是SkillStatusIcon类型")
		return
	
	# 添加到容器
	skill_status_container.add_child(status_icon)
	
	# 设置状态数据
	status_icon.setup(status_data)
	
	# 保存到字典中
	_status_icons[status_data.status_id] = status_icon

## 移除状态图标
func _remove_status_icon(status_id: StringName) -> void:
	if not _status_icons.has(status_id):
		return
	
	# 获取图标
	var status_icon = _status_icons[status_id]
	
	# 从字典中移除
	_status_icons.erase(status_id)
	
	# 从容器中移除并释放
	status_icon.queue_free()

## 清除所有状态图标
func clear_status_icons() -> void:
	# 清除所有状态图标
	for status_id in _status_icons.keys():
		var status_icon = _status_icons[status_id]
		status_icon.queue_free()
	
	# 清空字典
	_status_icons.clear()

## 状态应用（由外部角色/组件调用）
func on_status_applied(status_instance: SkillStatusData) -> void:
	_add_status_icon(status_instance)

## 状态移除（由外部角色/组件调用）
func on_status_removed(status_id: StringName, _status_instance_data_before_removal: SkillStatusData) -> void:
	_remove_status_icon(status_id)

## 状态更新（由外部角色/组件调用）
func on_status_updated(status_instance: SkillStatusData, _old_stacks: int, _old_duration: int) -> void:
	# 更新状态图标
	if _status_icons.has(status_instance.status_id):
		_status_icons[status_instance.status_id].update_status(status_instance)
