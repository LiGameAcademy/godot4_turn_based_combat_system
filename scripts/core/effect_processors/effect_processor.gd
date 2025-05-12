extends RefCounted
class_name EffectProcessor

## 效果处理器基类
## 所有具体效果处理器都应继承此类，并实现相应的方法

## 处理器引用
var skill_system = null ## 技能系统引用
var visual_effects = null ## 视觉效果处理器引用

## 构造函数
func _init(skill_sys = null, visual_fx = null):
	skill_system = skill_sys
	visual_effects = visual_fx

## 处理效果 - 主要接口方法
## 返回格式: 处理结果的字典
func process_effect(_effect: SkillEffectData, _source: Character, _target: Character) -> Dictionary:
	push_error("EffectProcessor.process_effect() 必须被子类重写")
	return {}

## 批量处理效果
## 默认实现为对每个目标分别处理每个效果
func process_effects(effects: Array, source: Character, targets: Array) -> Dictionary:
	var results = {}
	
	for target in targets:
		if !is_instance_valid(target) or target.current_hp <= 0:
			continue
			
		results[target] = {}
		
		for effect in effects:
			var result = process_effect(effect, source, target)
			
			# 合并结果
			for key in result:
				results[target][key] = result[key]
	
	return results

## 获取效果处理器ID
func get_processor_id() -> String:
	push_error("EffectProcessor.get_processor_id() 必须被子类重写")
	return "base"

## 获取效果描述 (用于UI显示)
func get_effect_description(_effect: SkillEffectData) -> String:
	push_error("EffectProcessor.get_effect_description() 必须被子类重写")
	return "未知效果"

## 检查是否可以处理指定效果类型
func can_process_effect(_effect: SkillEffectData) -> bool:
	# 默认实现，子类应该根据需要重写
	return false

## 计算效果结果 (供子类使用的辅助方法)
func calculate_effect_result(_effect: SkillEffectData, _source: Character, _target: Character) -> Dictionary:
	# 由子类实现具体计算
	return {}

## 应用效果结果 (供子类使用的辅助方法)
func apply_effect_result(_result: Dictionary, _target: Character) -> void:
	# 由子类实现具体应用
	pass

## 通用辅助方法
## 发送视觉效果请求
func request_visual_effect(effect_type: String, target, params: Dictionary = {}):
	if skill_system and skill_system.has_signal("visual_effect_requested"):
		skill_system.visual_effect_requested.emit(effect_type, target, params)
	
## 生成伤害数字
func spawn_damage_number(position: Vector2, amount: int, color: Color = Color.RED):
	if visual_effects and visual_effects.has_method("spawn_damage_number"):
		visual_effects.spawn_damage_number(position, amount, color)

## 获取战斗管理器
func get_battle_manager():
	if skill_system and skill_system.has_method("get_battle_manager"):
		return skill_system.get_battle_manager()
	return null
