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

enum StatusType {
	BUFF,                                   ## 增益
	DEBUFF,                                 ## 减益
	NEUTRAL                                 ## 中性
}

@onready var texture_rect: TextureRect = %TextureRect
@onready var texture_label: Label = %TextureLabel
@onready var info_label: Label = %InfoLabel

@export var glow_material : ShaderMaterial = preload("res://assets/materials/glow_material.tres")
@export var darken_material : ShaderMaterial = preload("res://assets/materials/darken_material.tres")

## 清除状态图标
func clear() -> void:
	hide()

## 更新状态图标的显示
func update_display(icon: Texture2D, status_type: StatusType, max_stacks: int, stacks: int, remaining_duration: int) -> void:
	# 显示图标
	texture_rect.texture = icon
	
	# 设置状态类型对应的颜色
	var status_color = TYPE_COLORS.get(status_type, Color.WHITE)
	texture_rect.modulate = status_color
	
	# 显示层数（如果大于1）
	if max_stacks > 1 and stacks > 1:
		texture_label.text = str(stacks)
		texture_label.show()
	else:
		texture_label.hide()
	
	info_label.text = str(remaining_duration)
	if remaining_duration > 0:
		info_label.show()
	else:
		info_label.hide()

	# 应用一些视觉效果
	_apply_visual_effects(status_type)
	
	# 确保控件可见
	show()

## 应用视觉效果
func _apply_visual_effects(status_type: StatusType) -> void:
	# 根据状态类型应用不同的视觉效果
	if status_type == StatusType.BUFF:
		# 增益效果可以有轻微的发光效果
		texture_rect.material =  glow_material
	elif status_type == StatusType.DEBUFF:
		# 减益效果可以有轻微的暗色效果
		texture_rect.material = darken_material
	else:
		texture_rect.material = null
