extends Node2D
class_name StateIndicator

enum StateType {
	NONE,           ## 无
	STUN,           ## 眩晕
	SILENCE,        ## 沉默
	DEFENSE,        ## 防御
	BLEED,			## 流血
}

@onready var label : Label = $Label
@onready var state_text : Dictionary[StateType, String] = {
	StateType.STUN: "💫",
	StateType.SILENCE: "🔇",
	StateType.DEFENSE: "🛡️",
	StateType.BLEED: "🩸",
}

func _ready() -> void:
	label.pivot_offset = label.size / 2
	hide()

## 显示指示器
func show_indicator(state: StateType = StateType.NONE) -> void:
	show()
	label.text = state_text[state]
	# 添加简单的小动画效果
	label.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## 隐藏指示器
func hide_indicator() -> void:
	if not visible:
		return
		
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_hide_completed)

func _on_hide_completed() -> void:
	hide()
