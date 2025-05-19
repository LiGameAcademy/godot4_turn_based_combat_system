extends RefCounted
class_name EffectProcessor

## 效果处理器基类
## 所有具体效果处理器都应继承此类，并实现相应的方法

# 系统引用
var skill_system : SkillSystem = null 					## 技能系统引用
var visual_effects : BattleVisualEffects = null 		## 视觉效果处理器引用

# 构造函数
func _init(skill_sys = null, visual_fx = null):
	skill_system = skill_sys
	visual_effects = visual_fx

## 处理效果 - 主要接口方法
## [return] 处理结果的字典
func process_effect(_effect: SkillEffectData, _source: Character, _target: Character) -> Dictionary:
	push_error("EffectProcessor.process_effect() 必须被子类重写")
	return {}

## 获取效果处理器ID
## [return] 处理器ID
func get_processor_id() -> StringName:
	push_error("EffectProcessor.get_processor_id() 必须被子类重写")
	return "base"

## 检查是否可以处理指定效果类型
## [param effect] 要检查的效果
## [return] 是否可以处理
func can_process_effect(_effect: SkillEffectData) -> bool:
	# 默认实现，子类应该根据需要重写
	return false

## 通用辅助方法
## [param effect_type] 视觉效果类型
## [param target] 目标角色
## [param params] 视觉效果参数
## 发送视觉效果请求
func _request_visual_effect(effect_type: StringName, target, params: Dictionary = {}):
	if skill_system and skill_system.has_signal("visual_effect_requested"):
		skill_system.visual_effect_requested.emit(effect_type, target, params)

## 获取战斗管理器
## [return] 战斗管理器
func _get_battle_manager() -> BattleManager:
	if skill_system and skill_system.has_method("_get_battle_manager"):
		return skill_system.get_battle_manager()
	return null

func _get_target_combat_component(target: Character) -> CombatComponent:
	var combat_comp = target.get_node_or_null("CombatComponent")
	if not combat_comp:
		push_error("目标角色 %s 没有 CombatComponent" % target.name)
		return null
	return combat_comp
