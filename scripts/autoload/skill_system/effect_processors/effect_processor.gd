extends RefCounted
class_name EffectProcessor

## 效果处理器基类
## 所有具体效果处理器都应继承此类，并实现相应的方法

## 处理效果的核心方法
## effect_data: 要处理的 SkillEffectData 实例
## _execution_context: 包含执行所需所有信息的字典，例如：
##   - "source_character": Character (执行者)
##   - "primary_target": Character (主要目标)
##   - "skill_data": SkillData (可选, 如果来自技能)
##   - "status_data": SkillStatusData (可选, 如果来自状态)
##   - "damage_info": DamageInfo (可选, 用于伤害修改事件)
##   - "original_event_context": Dictionary (可选, 原始触发事件上下文)
## 返回一个字典，包含处理结果，例如 {"success": true, "damage_dealt": 50}
func process_effect(effect_data: SkillEffectData, _execution_context: Dictionary) -> Dictionary:
	# 基类方法，应由子类覆盖
	# 默认实现可以返回一个表示未处理或失败的字典
	push_warning("EffectProcessor.process_effect() was called but not overridden in a subclass for effect type: %s" % SkillEffectData.EffectType.find_key(effect_data.effect_type))
	return {"success": false, "message": "Effect not processed by base class."}

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
func _request_visual_effect(effect_type: StringName, target, params: Dictionary = {}) -> void:
	SkillSystem.request_visual_effect(effect_type, target, params)
