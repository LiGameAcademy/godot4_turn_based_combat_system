extends Node2D
class_name DefenseIndicator

@onready var label : Label = $Label

## 显示指示器
func show_indicator() -> void:
	visible = true
	# 添加简单的小动画效果
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## 隐藏指示器
func hide_indicator() -> void:
	if not visible:
		return
		
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(set_visible.bind(false))
