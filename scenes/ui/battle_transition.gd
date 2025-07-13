# scenes/ui/battle_transition.gd
extends CanvasLayer
class_name BattleTransition

var animation_player: AnimationPlayer
var color_rect: ColorRect

signal fade_in_finished
signal fade_out_finished

func _ready():
	# 获取节点引用
	animation_player = $AnimationPlayer
	color_rect = $ColorRect
	
	# 确保动画播放器在需要时才可见
	#hide() 
	if animation_player and animation_player.has_animation("fade_in"):
		animation_player.get_animation("fade_in").loop_mode = Animation.LOOP_NONE
	if animation_player and animation_player.has_animation("fade_out"):
		animation_player.get_animation("fade_out").loop_mode = Animation.LOOP_NONE
	# 连接动画完成信号到自定义信号
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)

func play_fade_in(): # 从不透明到透明（显示场景）	
	show()
	animation_player.play("fade_in")
	return fade_in_finished # 返回信号供await

func play_fade_out(): # 从透明到不透明（隐藏场景）	
	show()
	animation_player.play("fade_out")
	return fade_out_finished # 返回信号供await

func _on_animation_player_animation_finished(anim_name: StringName):
	if anim_name == &"fade_in":
		fade_in_finished.emit()
		hide() # 淡入完成后通常隐藏自身
	elif anim_name == &"fade_out":
		fade_out_finished.emit()
		# 淡出完成后通常不隐藏，等待场景切换
