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
	# 如果已经有连接的状态数据，断开连接
	if _status_data:
		_disconnect_signals()
	
	_status_data = status_data
	
	# 连接信号
	_connect_signals()
	
	# 更新显示
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
	# 如果已经有连接的状态数据，断开连接
	if _status_data:
		_disconnect_signals()
	
	_status_data = status_data
	
	# 连接信号
	_connect_signals()
	
	# 更新显示
	_update_display()

## 清除状态图标
func clear() -> void:
	# 如果有连接的状态数据，断开连接
	if _status_data:
		_disconnect_signals()
	
	_status_data = null
	hide()

## 检查是否显示相同的状态
func is_showing_status(status_id: StringName) -> bool:
	return _status_data != null and _status_data.status_id == status_id

## 获取当前显示的状态数据
func get_status_data() -> SkillStatusData:
	return _status_data

## 连接状态数据的信号
func _connect_signals() -> void:
	if _status_data:
		# 连接层数变化信号
		if not _status_data.stacks_changed.is_connected(_on_stacks_changed):
			_status_data.stacks_changed.connect(_on_stacks_changed)
		
		# 连接持续时间变化信号
		if not _status_data.duration_changed.is_connected(_on_duration_changed):
			_status_data.duration_changed.connect(_on_duration_changed)

## 断开状态数据的信号连接
func _disconnect_signals() -> void:
	if _status_data:
		# 断开层数变化信号
		if _status_data.stacks_changed.is_connected(_on_stacks_changed):
			_status_data.stacks_changed.disconnect(_on_stacks_changed)
		
		# 断开持续时间变化信号
		if _status_data.duration_changed.is_connected(_on_duration_changed):
			_status_data.duration_changed.disconnect(_on_duration_changed)

## 当状态层数变化时调用
func _on_stacks_changed(_new_stacks: int) -> void:
	_update_display()

## 当状态持续时间变化时调用
func _on_duration_changed(_new_duration: int) -> void:
	_update_display()
