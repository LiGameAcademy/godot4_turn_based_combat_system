extends Node2D
class_name DamageNumber

## 伤害文本显示

## 漂字类型枚举
enum TextType {
	DAMAGE,    # 伤害数字
	HEAL,      # 治疗数字
	STATUS,    # 状态文本
	MISS,      # 闪避文本
	CRITICAL,  # 暴击文本
	CUSTOM     # 自定义文本
}

## 配置参数
var float_speed : float = 50.0      # 上升速度
var float_duration : float = 1.0    # 持续时间
var time_elapsed: float = 0.0       # 已经过时间
var text_type: TextType = TextType.DAMAGE  # 文本类型
var scale_effect: bool = true       # 是否有缩放效果
var shake_effect: bool = false      # 是否有抖动效果
var shake_intensity: float = 5.0    # 抖动强度

@onready var label : Label = $Label

## 动画更新
func _process(delta: float) -> void:
	if time_elapsed < float_duration:
		# 向上漂浮
		position.y -= float_speed * delta
		
		# 缩放效果
		if scale_effect:
			var scale_factor = 1.0 - time_elapsed / float_duration * 0.5
			scale = Vector2(scale_factor, scale_factor)
		
		# 渐变淡出
		var alpha = 1.0 - (time_elapsed / float_duration)
		modulate.a = alpha
		
		time_elapsed += delta
	else:
		# 动画完成后自动销毁
		queue_free()

## 初始化漂字
## [param text] 显示的文本
## [param color] 文本颜色
## [param type] 文本类型，使用TextType枚举
func setup(
		text: String, 
		color: Color = Color.WHITE, 
		type: TextType = TextType.DAMAGE) -> void:
	label.text = text
	label.modulate = color
	text_type = type
	time_elapsed = 0.0
	
	# 根据类型设置不同的动画参数
	match type:
		TextType.DAMAGE:
			float_speed = 50.0
			scale_effect = true
			shake_effect = false
		TextType.HEAL:
			float_speed = 40.0
			scale_effect = true
			shake_effect = false
			if color == Color.WHITE:  # 如果没有指定颜色，使用默认治疗颜色
				label.modulate = Color(0.2, 1.0, 0.2)
		TextType.CRITICAL:
			float_speed = 60.0
			float_duration = 1.2
			scale_effect = true
			shake_effect = true
			if color == Color.WHITE:  # 如果没有指定颜色，使用默认暴击颜色
				label.modulate = Color(1.0, 0.5, 0.0)
		TextType.STATUS:
			float_speed = 30.0
			scale_effect = false
			shake_effect = false
		TextType.MISS:
			float_speed = 45.0
			scale_effect = false
			shake_effect = false
			if color == Color.WHITE:
				label.modulate = Color(0.7, 0.7, 0.7)
	
	# 初始缩放效果
	if scale_effect:
		scale = Vector2(1.5, 1.5)
	
	# 开始抖动效果
	if shake_effect:
		_apply_shake()

func show_number(amount: String, color : Color, type: TextType = TextType.DAMAGE) -> void:
	setup(amount, color, type)

## 显示伤害数字
func show_damage(amount: float, is_critical: bool = false) -> void:
	var text = str(roundi(amount))
	var type = TextType.CRITICAL if is_critical else TextType.DAMAGE
	var color = Color(1.0, 0.5, 0.0) if is_critical else Color(1.0, 0.3, 0.3)
	setup(text, color, type)

## 显示治疗数字
func show_heal(amount: float) -> void:
	var text = str(roundi(amount))
	setup(text, Color(0.2, 1.0, 0.2), TextType.HEAL)

## 显示状态文本
func show_status(status_name: String, is_positive: bool = true) -> void:
	var color = Color(0.2, 1.0, 0.2) if is_positive else Color(1.0, 0.3, 0.3)
	setup(status_name, color, TextType.STATUS)

## 显示闪避文本
func show_miss() -> void:
	setup("闪避!", Color(0.7, 0.7, 0.7), TextType.MISS)

## 显示自定义文本
func show_text(text: String, color: Color = Color.WHITE) -> void:
	setup(text, color, TextType.CUSTOM)

## 应用抖动效果
func _apply_shake() -> void:
	var tween = create_tween()
	var original_pos = position
	
	# 创建一系列随机抖动
	for i in range(4):
		var offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		tween.tween_property(self, "position", original_pos + offset, 0.05)
		tween.tween_property(self, "position", original_pos, 0.05)
	
