extends RefCounted
class_name EffectProcessor

## 效果处理器引用
var battle_manager = null ## 战斗管理器引用
var visual_effects = null ## 视觉效果处理器引用

## 构造函数
func _init(battle_mgr = null, visual_fx = null):
	battle_manager = battle_mgr
	visual_effects = visual_fx

## 处理效果 - 主要接口方法
## 返回格式: 字典格式的结果 {"target1": {"damage": 50}, "target2": {"damage": 30}}
func process_effect(_effect: SkillEffect, _caster: Character, _targets: Array) -> Dictionary:
	push_error("EffectProcessor.process_effect() 必须被子类重写")
	return {}

## 获取效果处理器ID
func get_processor_id() -> String:
	push_error("EffectProcessor.get_processor_id() 必须被子类重写")
	return "base"

## 获取效果描述 (用于UI显示)
func get_effect_description(_effect: SkillEffect) -> String:
	push_error("EffectProcessor.get_effect_description() 必须被子类重写")
	return "未知效果"

## 通用辅助方法
## 发送视觉效果请求 (如果存在视觉效果处理器)
func request_visual_effect(effect_type: String, target, params: Dictionary = {}):
	if battle_manager and battle_manager.skill_system:
		battle_manager.skill_system.visual_effect_requested.emit(effect_type, target, params)
	
## 生成伤害数字
func spawn_damage_number(position: Vector2, amount: int, color: Color = Color.RED):
	if visual_effects and visual_effects.has_method("spawn_damage_number"):
		visual_effects.spawn_damage_number(position, amount, color)
