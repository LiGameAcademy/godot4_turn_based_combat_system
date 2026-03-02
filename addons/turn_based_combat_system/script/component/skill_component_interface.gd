@abstract
extends Node
class_name SkillComponentInterface

## 技能组件接口

signal status_applied(status_id: StringName)																	## 当状态效果被应用到角色身上时发出
signal status_removed(status_id: StringName, status_instance_data_before_removal: Resource)						    ## 当状态效果从角色身上移除时发出
signal status_updated(status_id: StringName)								## 当状态效果更新时发出 (例如 stacks 或 duration 变化)
signal attribute_base_value_changed(attribute_id: StringName, old_value: float, new_value: float)				    ## 属性基础值改变
signal attribute_current_value_changed(attribute_id: StringName, old_value: float, new_value: float)			    ## 属性当前值改变
signal action_tags_changed(restricted_tags: Array[String])														    ## 角色限制动作标签改变																	## 当角色被限制执行某个动作类型时发出
signal skill_execution_started(skill_data: Resource, skill_context: Dictionary)				## 当技能执行开始时发出
signal skill_execution_completed(skill_data: Resource, result: Dictionary)					## 当技能执行完成时发出
signal skill_execution_failed(skill_data: Resource, result: Dictionary)						## 当技能执行失败时发出

signal current_health_changed(new_value: float)
signal current_mana_changed(new_value: float)

#region --- 属性管理 ---

## 获取属性当前值
@abstract func get_attribute_current_value(attribute_id: StringName) -> float
## 获取属性基础值
@abstract func get_attribute_base_value(attribute_id: StringName) -> float
## 设置属性基础值
@abstract func set_attribute_base_value(attribute_id: StringName, value: float) -> void
## 添加属性修改器
@abstract func add_attribute_modifier(attribute_id: StringName, magnitude: float, operation: int, source_id: StringName) -> void
## 移除属性修改器
@abstract func remove_attribute_modifier(attribute_id: StringName, modifier: Resource) -> void
## 获取属性修改器
@abstract func get_attribute_modifiers(attribute_id: StringName) -> Array[Resource]
## 获取属性配置
@abstract func get_attribute(attribute_id: StringName) -> Resource
## 消耗hp
@abstract func consume_hp(amount: float) -> bool
## 恢复hp
@abstract func restore_hp(amount: float) -> float
## 消耗mp
@abstract func consume_mp(amount: float) -> bool
## 恢复mp
@abstract func restore_mp(amount: float) -> float
## 获取当前mp
@abstract func get_current_mp() -> float
## 获取当前hp
@abstract func get_current_hp() -> float
## 获取属性名称
@abstract func get_attribute_name(attribute_id: StringName) -> StringName
#endregion

#region --- 技能管理 ---
## 添加技能
@abstract func add_skill(skill_id: StringName, skill: Resource) -> void
## 移除技能
@abstract func remove_skill(skill_id: StringName) -> void
## 检查是否有足够的MP释放技能, 如果skill_id为空, 则检查是否有足够的MP释放任意技能
@abstract func has_enough_mp_for_skill(skill_id: StringName = "") -> bool
## 获取所有技能
@abstract func get_skills() -> Dictionary[StringName, Resource]
## 获取技能
@abstract func get_skill(skill_id: StringName) -> Resource
## 获取技能数量
@abstract func get_skill_count() -> int
## 检查是否有指定技能
@abstract func has_skill(skill_id: StringName) -> bool
## 获取可用技能列表
@abstract func get_available_skills() -> Array[StringName]
## 检查技能是否为近战技能
@abstract func is_skill_melee(skill_id: StringName) -> bool
## 获取技能显示名称
@abstract func get_skill_display_name(skill_id: StringName) -> String
## 获取技能描述
@abstract func get_skill_description(skill_id: StringName) -> String
## 获取技能的MP消耗
@abstract func get_skill_mp_cost(skill_id: StringName) -> int
## 执行技能
@abstract func execute_skill(skill_id: StringName, targets: Array[Node], skill_context: Dictionary) -> Dictionary
## 获取技能目标
@abstract func get_skill_targets(skill_id: StringName, context: Dictionary) -> Array[Node]
#endregion

#region --- 状态管理 ---
## 获取所有激活状态
@abstract func get_active_statuses() -> Dictionary[StringName, Resource]
## 应用状态
@abstract func apply_status(status_template: Resource, p_source: Node, effect_data_from_skill: Resource) -> Dictionary
## 移除状态
@abstract func remove_status(status_id: StringName, trigger_removal: bool = false) -> bool
## 更新状态持续时间
@abstract func update_status_durations() -> void
## 处理激活状态
@abstract func process_active_statuses(battle_manager: BattleManager) -> void
## 获取状态
@abstract func get_status(status_id: StringName) -> Resource
## 检查是否有指定状态
@abstract func has_status(status_id: StringName) -> bool
## 获取状态层数
@abstract func get_status_stacks(status_id: StringName) -> int
## 获取触发状态
@abstract func get_triggerable_status(event_type: StringName) -> Array[Resource]
## 更新状态触发次数
@abstract func update_status_trigger_counts(status: Resource) -> void

@abstract func status_is_hidden_from_ui(status_id : StringName) -> bool
## 获取状态图标
@abstract func get_status_icon(status_id: StringName) -> Texture2D
## 获取状态类型
@abstract func get_status_type(status_id: StringName) -> int
## 获取状态最大层数
@abstract func get_status_max_stacks(status_id: StringName) -> int
## 获取状态当前堆叠层数
@abstract func get_status_current_stacks(status_id: StringName) -> int
## 获取状态剩余持续时间
@abstract func get_status_remaining_duration(status_id: StringName) -> int
#endregion

#region --- 标签管理 ---
## 获取技能限制动作标签
@abstract func get_restricted_action_tags() -> Array[String]
## 检查是否可以执行指定动作类型
@abstract func can_perform_action_category(action_category: StringName) -> bool
## 检查技能是否可用
@abstract func is_skill_available(skill_id: StringName) -> bool
#endregion
