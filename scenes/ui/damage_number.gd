extends Node2D

@onready var label : Label = $Label

## 向上浮动速度
var float_speed : float = 50.0
## 显示持续时间
var float_duration : float = 1.0
var time_elapsed: float = 0.0


func _process(delta: float) -> void:
	if time_elapsed < float_duration:
		# 向上漂浮并渐变淡出
		position.y -= float_speed * delta
		label.modulate.a = lerp(1.0, 0.0, time_elapsed / float_duration)
		time_elapsed += delta
	else:
		# 动画完成后自动销毁
		queue_free()

func show_number(text: String, color: Color = Color.WHITE) -> void:
	label.text = text
	label.modulate = color
	time_elapsed = 0.0
