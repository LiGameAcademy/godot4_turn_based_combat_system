extends SkillComponentInterface
class_name GAS_SkillComponentAdapter

## GAS技能系统组件适配器

@export var vital_attribute_component: GameplayVitalAttributeComponent
@export var status_component : GameplayStatusComponent
@export var ability_component : GameplayAbilityComponent

## 获取属性当前值
func get_attribute_current_value(attribute_id: StringName) -> float:
	return 10.0
## 获取属性基础值
func get_attribute_base_value(attribute_id: StringName) -> float:
	return 0.0
## 设置属性基础值
func set_attribute_base_value(attribute_id: StringName, value: float) -> void:
	pass
## 添加属性修改器
func add_attribute_modifier(attribute_id: StringName, modifier: SkillAttributeModifier) -> void:
	pass
## 移除属性修改器
func remove_attribute_modifier(attribute_id: StringName, modifier: SkillAttributeModifier) -> void:
	pass
## 获取属性修改器
func get_attribute_modifiers(attribute_id: StringName) -> Array[SkillAttributeModifier]:
	return []
## 获取属性实例
func get_attribute(attribute_id: StringName) -> SkillAttribute:
	return null
## 获取属性集
func get_attribute_set() -> SkillAttributeSet:
	return null
## 消耗hp
func consume_hp(amount: float) -> bool:
	return false
## 恢复hp
func restore_hp(amount: float) -> float:
	return 0.0
## 消耗mp
func consume_mp(amount: float) -> bool:
	return false
	
## 恢复mp
func restore_mp(amount: float) -> float:
	return 0.0
	
## 获取当前mp
func get_current_mp() -> float:
	return 0.0
## 获取当前hp
func get_current_hp() -> float:
	return 0.0
#endregion

#region --- 技能管理 ---
## 添加技能
func add_skill(skill_id: StringName, skill: Resource) -> void:
	pass
## 移除技能
func remove_skill(skill_id: StringName) -> void:
	pass
## 检查是否有足够的MP释放技能, 如果skill_id为空, 则检查是否有足够的MP释放任意技能
func has_enough_mp_for_skill(skill_id: StringName = "") -> bool:
	return false
## 获取所有技能
func get_skills() -> Dictionary[StringName, Resource]:
	return {}
## 获取技能
func get_skill(skill_id: StringName) -> Resource:
	return null
## 获取技能数量
func get_skill_count() -> int:
	return 0
## 检查是否有指定技能
func has_skill(skill_id: StringName) -> bool:
	return false
## 获取可用技能列表
func get_available_skills() -> Array[StringName]:
	return []
## 检查技能是否为近战技能
func is_skill_melee(skill_id: StringName) -> bool:
	return false
## 获取技能的MP消耗
func get_skill_mp_cost(skill_id: StringName) -> int:
	return 0
## 获取技能目标
func get_skill_targets(skill_id: StringName, context: Dictionary) -> Array[Node]:
	return []
## 获取技能显示名称
func get_skill_display_name(skill_id: StringName) -> String:
	return ""
## 获取技能描述
func get_skill_description(skill_id: StringName) -> String:
	return ""
## 执行技能
func execute_skill(skill_id: StringName, targets: Array[Node], skill_context: Dictionary) -> Dictionary:
	return {}
#endregion

#region --- 状态管理 ---
## 获取所有激活状态
func get_active_statuses() -> Dictionary[StringName, Resource]:
	return {}
## 应用状态
func apply_status(status_template: Resource, p_source: Node, effect_data_from_skill: Resource) -> Dictionary:
	return {}
## 移除状态
func remove_status(status_id: StringName, trigger_removal: bool = false) -> bool:
	return false
## 更新状态持续时间
func update_status_durations() -> void:
	pass
## 处理激活状态
func process_active_statuses(battle_manager: BattleManager) -> void:
	pass
## 获取状态
func get_status(status_id: StringName) -> Resource:
	return null
## 检查是否有指定状态
func has_status(status_id: StringName) -> bool:
	return false
## 获取状态层数
func get_status_stacks(status_id: StringName) -> int:
	return 0
## 获取触发状态
func get_triggerable_status(event_type: StringName) -> Array[Resource]:
	return []
## 更新状态触发次数
func update_status_trigger_counts(status: Resource) -> void:
	pass
#endregion

#region --- 标签管理 ---
## 获取技能限制动作标签
func get_restricted_action_tags() -> Array[String]:
	return []
## 检查是否可以执行指定动作类型
func can_perform_action_category(action_category: StringName) -> bool:
	return false
## 检查技能是否可用
func is_skill_available(skill_id: StringName) -> bool:
	return false
#endregion
