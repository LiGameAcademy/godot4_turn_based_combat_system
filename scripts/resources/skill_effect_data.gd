extends Resource
class_name SkillEffectData

# 基本属性
@export var visual_effect: String = ""  		## 视觉效果标识符
@export var sound_effect: String = ""   		## 音效标识符
@export_enum("none", "self_only", "all_allies", "all_enemies", "main_target_and_adjacent") var target_override: String = "none" 		## 目标覆盖类型
## 元素属性
@export_enum("none", "fire", "water", "earth", "light") var element: int = 0 # ElementTypes.Element.NONE 

## 获取效果描述
func get_description() -> String:
	return "未知效果"

## 处理效果 - 主要接口方法
## [return] 处理结果的字典
func process_effect(source: Character, _target: Character, _context : SkillExecutionContext) -> Dictionary:
	await source.get_tree().create_timer(0.1).timeout
	push_error("EffectProcessor.process_effect() 必须被子类重写", self)
	return {}

## 通用辅助方法
## [param effect_type] 视觉效果类型
## [param target] 目标角色
## [param params] 视觉效果参数
## 发送视觉效果请求
func _request_visual_effect(effect_type: StringName, target: Character, params: Dictionary = {}) -> void:
	if not SkillSystem or not is_instance_valid(target):
		return
		
	# 分发到适当的视觉效果方法
	var method_name : String = "_play_" + effect_type + "_effect"
	if SkillSystem.battle_manager.has_method(method_name):
		SkillSystem.battle_manager.call(method_name, target, params)
	else:
		push_warning("未找到视觉效果方法 " + method_name)
