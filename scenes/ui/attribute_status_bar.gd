@tool
extends ProgressBar
class_name AttributeStatusBar

@onready var attribute_status_label: Label = %AttributeStatusLabel

@export var attribute_name : String = "HP"
@export var attribute_color : Color = Color.GREEN
# 动画相关变量
@export var animation_speed: float = 5.0  # 值越大，动画越快
@export var use_animation: bool = true  # 是否使用动画效果
var _target_value: float = 0.0
var _target_max_value: float = 0.0
var _current_displayed_value: float = 0.0
var _current_displayed_max_value: float = 0.0
var _tween: Tween
var _is_animating: bool = false  # 内部使用，标记动画是否正在进行中

func _ready() -> void:
	self_modulate = attribute_color

## 使用数值直接设置当前值和最大值（不依赖 SkillAttribute）
func set_values(current_value: float, max_attr_value: float) -> void:
	# 如果已经有动画在运行，停止它
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_target_value = current_value
	_target_max_value = max_attr_value
	# 如果不使用动画，直接更新值
	if not use_animation:
		_current_displayed_value = _target_value
		_current_displayed_max_value = _target_max_value
		value = _current_displayed_value
		max_value = _current_displayed_max_value
		_set_attribute_text(_current_displayed_value, _current_displayed_max_value)
		return
	
	# 如果已经有动画在运行，停止它
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# 创建新的动画
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	
	# 计算动画持续时间 - 根据animation_speed调整
	var duration = 1.0 / animation_speed
	_is_animating = true
	
	# 动画当前值和最大值
	_tween.tween_method(_update_animated_values, 
		Vector2(_current_displayed_value, _current_displayed_max_value),
		Vector2(_target_value, _target_max_value),
		duration)
	
	# 添加值变化的视觉反馈
	if _current_displayed_value != _target_value:
		# 如果值减少，闪红色
		if _current_displayed_value > _target_value:
			_tween.parallel().tween_property(self, "modulate", Color(1.5, 0.5, 0.5), duration * 0.4)
			_tween.tween_property(self, "modulate", Color(1, 1, 1), duration * 0.6)
		# 如果值增加，闪绿色
		elif _current_displayed_value < _target_value:
			_tween.parallel().tween_property(self, "modulate", Color(0.5, 1.5, 0.5), duration * 0.4)
			_tween.tween_property(self, "modulate", Color(1, 1, 1), duration * 0.6)
	
	# 动画完成时设置标志
	_tween.finished.connect(func(): _is_animating = false)

func _update_animated_values(current_values: Vector2) -> void:
	# 更新当前显示的值
	_current_displayed_value = current_values.x
	_current_displayed_max_value = current_values.y
	
	# 更新进度条
	value = _current_displayed_value
	max_value = _current_displayed_max_value
	
	# 更新文本标签
	_set_attribute_text(_current_displayed_value, _current_displayed_max_value)

func _set_attribute_text(current_value: float, max_atr_value: float) -> void:
	attribute_status_label.text = attribute_name + ": %d / %d" % [roundi(current_value), roundi(max_atr_value)]
