extends Resource
class_name SkillEffectData

# 基本属性
@export var disable : bool = false			## 是否禁用
@export var visual_effect: String = ""  		## 视觉效果标识符
@export var sound_effect: String = ""   		## 音效标识符
@export_enum("none", "self_only", "all_allies", "all_enemies", "main_target_and_adjacent") var target_override: String = "none" 		## 目标覆盖类型
## 元素属性
@export_enum("none", "fire", "water", "earth", "light") var element: int = 0 # ElementTypes.Element.NONE 

@export_group("执行条件")
@export var conditions: Array[SkillCondition] = []

## 供外部调用的、完整的描述方法
func get_description() -> String:
	#if disable : return ""
	var base_desc = _get_base_description() # 获取效果自身的基础描述
	if conditions.is_empty():
		return base_desc

	var condition_descs: Array[String] = []
	for condition in conditions:
		if is_instance_valid(condition):
			condition_descs.append(condition.get_description())
			
	# 将效果描述和条件描述组合起来
	return "%s [%s]" % [base_desc, ", ".join(condition_descs)]

## 内部方法，供子类重写，只负责描述效果本身
func _get_base_description() -> String:
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
