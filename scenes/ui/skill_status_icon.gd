extends Control
class_name SkillStatusIcon

# 状态类型对应的颜色
const TYPE_COLORS = {
	SkillStatusData.StatusType.BUFF: Color(0.2, 0.8, 0.2),    # 绿色
	SkillStatusData.StatusType.DEBUFF: Color(0.8, 0.2, 0.2),  # 红色
	SkillStatusData.StatusType.NEUTRAL: Color(0.8, 0.8, 0.2)  # 黄色
}

# 持续时间类型对应的显示文本
const DURATION_TEXT = {
	SkillStatusData.DurationType.INFINITE: "∞",     # 无限
	SkillStatusData.DurationType.COMBAT_LONG: "战"  # 战斗
}

@onready var texture_rect: TextureRect = %TextureRect
@onready var texture_label: Label = %TextureLabel
@onready var info_label: Label = %InfoLabel

@export var glow_material : ShaderMaterial = preload("res://resources/materials/glow_material.tres")
@export var darken_material : ShaderMaterial = preload("res://resources/materials/darken_material.tres")

var _status_data: SkillStatusData

## 设置状态数据并初始化显示
func setup(status_data: SkillStatusData) -> void:
	_status_data = status_data
	_update_display()
	
	# 添加工具提示
	tooltip_text = status_data.get_full_description()

## 更新状态图标的显示
func _update_display() -> void:
	if not _status_data:
		hide()
		return
	
	# 显示图标
	texture_rect.texture = _status_data.icon
	
	# 设置状态类型对应的颜色
	var status_color = TYPE_COLORS.get(_status_data.status_type, Color.WHITE)
	texture_rect.modulate = status_color
	
	# 显示层数（如果大于1）
	if _status_data.max_stacks > 1 and _status_data.stacks > 1:
		texture_label.text = str(_status_data.stacks)
		texture_label.show()
	else:
		texture_label.hide()
	
	# 显示持续时间
	if _status_data.duration_type == SkillStatusData.DurationType.TURNS:
		info_label.text = str(_status_data.remaining_duration)
	else:
		info_label.text = DURATION_TEXT.get(_status_data.duration_type, "")
	
	# 应用一些视觉效果
	_apply_visual_effects()
	
	# 确保控件可见
	show()

## 应用视觉效果
func _apply_visual_effects() -> void:
	# 根据状态类型应用不同的视觉效果
	if _status_data.status_type == SkillStatusData.StatusType.BUFF:
		# 增益效果可以有轻微的发光效果
		texture_rect.material =  glow_material
	elif _status_data.status_type == SkillStatusData.StatusType.DEBUFF:
		# 减益效果可以有轻微的暗色效果
		texture_rect.material = darken_material
	else:
		texture_rect.material = null

## 更新状态数据
func update_status(status_data: SkillStatusData) -> void:
	_status_data = status_data
	_update_display()

## 清除状态图标
func clear() -> void:
	_status_data = null
	hide()

## 检查是否显示相同的状态
func is_showing_status(status_id: StringName) -> bool:
	return _status_data != null and _status_data.status_id == status_id

## 获取当前显示的状态数据
func get_status_data() -> SkillStatusData:
	return _status_data
