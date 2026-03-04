extends SkillComponentInterface
class_name GAS_SkillComponentAdapter

## GAS技能系统组件适配器

const TAG_IS_HIDDEN_FORM_UI : StringName = "is_hidden_form_ui"
const TAG_IS_MELEE_SKILL : StringName = "ability.is_melee"
const TAG_IS_BUFF : StringName = "status.buff"
const TAG_IS_DEBUFF : StringName = "status.debuff"

@export var vital_attribute_component: GameplayVitalAttributeComponent
@export var status_component : GameplayStatusComponent
@export var ability_component : GameplayAbilityComponent

func _ready() -> void:
	status_component.status_applied.connect(
		func(status_id: StringName, _instance: GameplayStatusInstance) -> void:
			status_applied.emit(status_id)
	)
	status_component.status_removed.connect(
		func(status_id: StringName) -> void:
			var status_instance : GameplayStatusInstance = status_component.get_status(status_id)
			status_removed.emit(status_id, status_instance.status_data)
	)
	status_component.status_stacked.connect(
		func(status_id: StringName, _new_stacks: int) -> void:
			status_updated.emit(status_id)
	)
	vital_attribute_component.attribute_value_changed.connect(
		func(attribute_id: StringName, new_value: float) -> void:
			attribute_current_value_changed.emit(attribute_id, new_value)
	)
	vital_attribute_component.attribute_base_value_changed.connect(
		func(attribute_id: StringName, old_value: float, new_value: float) -> void:
			attribute_base_value_changed.emit(attribute_id, old_value, new_value)
	)
	ability_component.ability_completed.connect(
		func(ability: GameplayAbilityInstance, success: bool) -> void:
			if success:
				skill_execution_completed.emit(ability.get_definition(), {"success": true})
			else:
				skill_execution_failed.emit(ability.get_definition(), {"success": false})
	)
	ability_component.ability_activated.connect(
		func(ability: GameplayAbilityInstance, context: Dictionary) -> void:
			skill_execution_started.emit(ability.get_definition(), context)
	)
	vital_attribute_component.vital_value_changed.connect(
		func(vital_id: StringName, current: float, _max: float, _percent: float, _is_regen: bool) -> void:
			if vital_id == &"health":
				current_health_changed.emit(current)
			elif vital_id == &"mana":
				current_mana_changed.emit(current)
	)

func initialize(
		atr_sets: Array[GameplayAttributeSet], 
		vitals : Array[GameplayVital], 
		initial_abilities : Array[GameplayAbilityDefinition]) -> void:
	if not is_instance_valid(vital_attribute_component):
		push_error("生命值组件未初始化！")
		return
	if not is_instance_valid(ability_component):
		push_error("能力组件未初始化！")
		return
	vital_attribute_component.initialize(atr_sets, vitals)
	ability_component.initialize(initial_abilities)

#region --- 属性管理 ---
## 获取属性当前值
func get_attribute_current_value(attribute_id: StringName) -> float:
	if not is_instance_valid(vital_attribute_component):
		return 0.0
	var attribute : GameplayAttributeInstance = vital_attribute_component.get_attribute(attribute_id)
	return attribute.get_value()

## 获取属性基础值
func get_attribute_base_value(attribute_id: StringName) -> float:
	if not is_instance_valid(vital_attribute_component):
		return 0.0
	var attribute : GameplayAttributeInstance = vital_attribute_component.get_attribute(attribute_id)
	return attribute.base_value

## 设置属性基础值
func set_attribute_base_value(attribute_id: StringName, _value: float) -> void:
	push_error("不允许设置属性基础值！ %s" % attribute_id)

## 添加属性修改器
func add_attribute_modifier(attribute_id: StringName, magnitude: float, operation: int, source_id: StringName) -> void:
	if not is_instance_valid(vital_attribute_component):
		return
	var mod : GameplayAttributeModifier = GameplayAttributeModifier.new(
		attribute_id,
		magnitude,
		operation,
		source_id
	)
	vital_attribute_component.add_modifier(mod)

## 移除属性修改器
func remove_attribute_modifier(attribute_id: StringName, modifier: Resource) -> void:
	if not is_instance_valid(vital_attribute_component):
		return	
	vital_attribute_component.remove_modifier(modifier as GameplayAttributeModifier)

## 获取属性修改器
func get_attribute_modifiers(attribute_id: StringName) -> Array[Resource]:
	var modifiers : Array[Resource] = []
	if not is_instance_valid(vital_attribute_component):
		return modifiers
	modifiers = vital_attribute_component.get_modifiers(attribute_id)
	return modifiers

## 获取属性配置
func get_attribute(attribute_id: StringName) -> Resource:
	if not is_instance_valid(vital_attribute_component):
		return null
	var attribute = vital_attribute_component.get_attribute(attribute_id)
	return attribute.attribute_def

## 消耗hp
func consume_hp(amount: float) -> bool:
	if not is_instance_valid(vital_attribute_component):
		return false
	var health_vital : HealthVital = vital_attribute_component.get_vital("health")
	health_vital.modify_value(-amount)
	return true

## 恢复hp
func restore_hp(amount: float) -> float:
	if not is_instance_valid(vital_attribute_component):
		return false
	var health_vital : HealthVital = vital_attribute_component.get_vital("health")
	health_vital.modify_value(amount)
	return amount

## 消耗mp
func consume_mp(amount: float) -> bool:
	if not is_instance_valid(vital_attribute_component):
		return false
	var mana_vital : ManaVital = vital_attribute_component.get_vital("mana")
	mana_vital.modify_value(-amount)
	return true
	
## 恢复mp
func restore_mp(amount: float) -> float:
	if not is_instance_valid(vital_attribute_component):
		return false
	var mana_vital : ManaVital = vital_attribute_component.get_vital("mana")
	mana_vital.modify_value(amount)
	return amount

## 获取当前mp
func get_current_mp() -> float:
	if not is_instance_valid(vital_attribute_component):
		return false
	var mana_vital : ManaVital = vital_attribute_component.get_vital("mana")
	return mana_vital.current_value

## 获取当前hp
func get_current_hp() -> float:
	if not is_instance_valid(vital_attribute_component):
		return false
	var health_vital : HealthVital = vital_attribute_component.get_vital("health")
	return health_vital.current_value

## 获取属性名称
func get_attribute_name(attribute_id: StringName) -> StringName:
	if not is_instance_valid(vital_attribute_component):
		return ""
	var attribute = vital_attribute_component.get_attribute(attribute_id)
	return attribute.attribute_def.attribute_display_name
#endregion

#region --- 技能管理 ---
## 添加技能
func add_skill(skill_id: StringName, skill: Resource) -> void:
	if not skill is GameplayAbilityDefinition:
		push_error("技能 %s 不是 GameplayAbilityDefinition 类型！" % skill_id)
		return
	ability_component.learn_ability(skill)

## 移除技能
func remove_skill(skill_id: StringName) -> void:
	var ok := ability_component.forget_ability(skill_id)
	if not ok:
		push_error("技能 %s 移除失败！" % skill_id)

## 检查是否有足够的MP释放技能, 如果skill_id为空, 则检查是否有足够的MP释放任意技能
func has_enough_mp_for_skill(skill_id: StringName = "") -> bool:
	if skill_id.is_empty():
		var abilities := ability_component.get_all_ability_instances()
		for ability_instance in abilities.values():
			var can_activate := ability_component.can_activate_ability(ability_instance.get_definition().ability_id, {})
			if can_activate:
				return true
		return false
	else:
		var ability_instance := ability_component.get_ability_instance(skill_id)
		# var current_mana := get_current_mp()
		var ability_definition := ability_instance.get_definition()
		if not ability_definition is ActiveAbilityDefinition:
			return false
		for cost in ability_definition.costs:
			if not cost.can_pay(ability_instance, get_parent()):
				return false
		return true

## 获取所有技能配置
func get_skills() -> Dictionary[StringName, Resource]:
	var skills : Dictionary[StringName, Resource] = {}
	var abilities : Dictionary[StringName, GameplayAbilityInstance] = ability_component.get_all_ability_instances()
	for ability_id : StringName in abilities:
		var ability_instance : GameplayAbilityInstance = abilities[ability_id]
		skills[ability_id] = ability_instance.get_definition()
	return skills

## 获取技能配置
func get_skill(skill_id: StringName) -> Resource:
	var ability_instance := ability_component.get_ability_instance(skill_id)
	if not is_instance_valid(ability_instance):
		return null
	return ability_instance.get_definition()

## 获取技能数量
func get_skill_count() -> int:
	var abilities : Dictionary[StringName, GameplayAbilityInstance] = ability_component.get_all_ability_instances()
	return abilities.size()

## 检查是否有指定技能
func has_skill(skill_id: StringName) -> bool:
	var ability_instance := ability_component.get_ability_instance(skill_id)
	if not is_instance_valid(ability_instance):
		return false
	return true

## 获取可用技能列表
func get_available_skills() -> Array[StringName]:
	var abilities : Dictionary[StringName, GameplayAbilityInstance] = ability_component.get_all_ability_instances()
	var available_skills : Array[StringName] = []
	for ability_id : StringName in abilities:
		var ability_instance : GameplayAbilityInstance = abilities[ability_id]
		if not ability_instance.disabled:
			available_skills.append(ability_id)
	return available_skills

## 检查技能是否为近战技能
func is_skill_melee(skill_id: StringName) -> bool:
	var ability_instance := ability_component.get_ability_instance(skill_id)
	var ability_definition := ability_instance.get_definition()
	return ability_definition.tags.has(TAG_IS_MELEE_SKILL)

## 获取技能的MP消耗
func get_skill_mp_cost(skill_id: StringName) -> int:
	var ability_instance := ability_component.get_ability_instance(skill_id)
	if not is_instance_valid(ability_instance):
		return 0
	var ability_definition := ability_instance.get_definition()
	var cost_feature : CostFeature = ability_instance.get_feature("CostFeature")
	if not is_instance_valid(cost_feature):
		return 0
	var mana_cost : int = 0
	for cost in cost_feature.costs:
		if cost is VitalCost and cost.vital_id == &"mana":
			mana_cost += cost.amount
	return mana_cost

## 获取技能目标
func get_skill_targets(skill_id: StringName, context: Dictionary) -> Array[Node]:
	var ability_instance := ability_component.request_ability_preview(skill_id)
	var targeting_context : Dictionary = ability_component.confirm_targeting()
	var targets : Array[Node] = targeting_context.get("targets", [])
	return targets

## 获取技能显示名称
func get_skill_display_name(skill_id: StringName) -> String:
	var ability_instance := ability_component.get_ability_instance(skill_id)
	if not is_instance_valid(ability_instance):
		return ""
	var ability_definition : GameplayAbilityDefinition = ability_instance.get_definition()
	return ability_definition.ability_name

## 获取技能描述
func get_skill_description(skill_id: StringName) -> String:
	var ability_instance := ability_component.get_ability_instance(skill_id)
	if not is_instance_valid(ability_instance):
		return ""
	var ability_definition : GameplayAbilityDefinition = ability_instance.get_definition()
	return ability_definition.description

## 执行技能
func execute_skill(skill_id: StringName, targets: Array[Node], skill_context: Dictionary) -> Dictionary:
	var final_context := skill_context.duplicate()
	final_context.targets = targets
	var ability_instance := ability_component.get_ability_instance(skill_id)
	var ok := ability_component.try_activate_ability(skill_id, final_context)
	await ability_instance.ability_completed
	return {"success": ok}
#endregion

#region --- 状态管理 ---
## 获取所有激活状态配置
func get_active_statuses() -> Dictionary[StringName, Resource]:
	var statuses : Dictionary[StringName, Resource] = {}
	var status_instances : Array[GameplayStatusInstance] = status_component.get_active_statuses()
	for status_instance in status_instances:
		var status_data : GameplayStatusData = status_instance.status_data
		if not is_instance_valid(status_data):
			continue
		var status_id : StringName = status_instance.status_data.status_id
		statuses[status_id] = status_data
	return statuses

## 应用状态
func apply_status(status_template: Resource, p_source: Node, _effect_data_from_skill: Resource) -> Dictionary:
	var result = {"applied_successfully": false, "status_instance": null, "reason": "unknown"}
	if not is_instance_valid(status_template) or not status_template is GameplayStatusData:
		result.reason = "invalid_status_template"
		return result
	if not is_instance_valid(p_source):
		result.reason = "invalid_source"
		return result
	var status_instance : GameplayStatusInstance = status_component.apply_status(status_template, p_source)
	return result

## 移除状态
func remove_status(status_id: StringName, trigger_removal: bool = false) -> bool:
	return status_component.remove_status(status_id)

## 更新状态持续时间
func update_status_durations() -> void:
	AbilityEventBus.trigger_game_event(&"turn_started")

## 处理激活状态
func process_active_statuses(_battle_manager: BattleManager) -> void:
	pass

## 获取状态配置
func get_status(status_id: StringName) -> Resource:
	var status_instance : GameplayStatusInstance = status_component.get_status(status_id)
	if not is_instance_valid(status_instance):
		return null
	var status_data : GameplayStatusData = status_instance.status_data
	if not is_instance_valid(status_data):
		return null
	return status_data

## 检查是否有指定状态
func has_status(status_id: StringName) -> bool:
	return status_component.has_status(status_id)

## 获取状态层数
func get_status_stacks(status_id: StringName) -> int:
	var status_instance : GameplayStatusInstance = status_component.get_status(status_id)
	if not is_instance_valid(status_instance):
		return 0
	return status_instance.stacks

func status_is_hidden_from_ui(status_id : StringName) -> bool:
	var status : GameplayStatusInstance = status_component.get_status(status_id)
	if not is_instance_valid(status):
		return false
	var status_data : GameplayStatusData = status.status_data
	if not is_instance_valid(status_data):
		return false
	return status_data.tags.has(TAG_IS_HIDDEN_FORM_UI)

## 获取状态图标
func get_status_icon(status_id: StringName) -> Texture2D:
	var status_instance : GameplayStatusInstance = status_component.get_status(status_id)
	if not is_instance_valid(status_instance):
		return null
	var status_data : GameplayStatusData = status_instance.status_data
	if not is_instance_valid(status_data):
		return null
	return status_data.icon

## 获取状态类型
func get_status_type(status_id: StringName) -> int:
	var status_instance : GameplayStatusInstance = status_component.get_status(status_id)
	if not is_instance_valid(status_instance):
		return 2
	var status_data : GameplayStatusData = status_instance.status_data
	if not is_instance_valid(status_data):
		return 2
	
	if status_data.tags.has(TAG_IS_BUFF):
		return 0
	elif status_data.tags.has(TAG_IS_DEBUFF):
		return 1
	return 2

## 获取状态最大层数
func get_status_max_stacks(status_id: StringName) -> int:
	var status_instance : GameplayStatusInstance = status_component.get_status(status_id)
	if not is_instance_valid(status_instance):
		return 0
	var status_data : GameplayStatusData = status_instance.status_data
	if not is_instance_valid(status_data):
		return 0
	return status_data.max_stacks

## 获取状态当前堆叠层数
func get_status_current_stacks(status_id: StringName) -> int:
	var status_instance : GameplayStatusInstance = status_component.get_status(status_id)
	if not is_instance_valid(status_instance):
		return 0
	var status_data : GameplayStatusData = status_instance.status_data
	if not is_instance_valid(status_data):
		return 0
	return status_instance.stacks

## 获取状态剩余持续时间	
func get_status_remaining_duration(status_id: StringName) -> int:
	var status_instance : GameplayStatusInstance = status_component.get_status(status_id)
	if not is_instance_valid(status_instance):
		return 0
	var status_data : GameplayStatusData = status_instance.status_data
	if not is_instance_valid(status_data):
		return 0
	return status_instance.remaining_duration
#endregion

#region --- 标签管理 ---
## 获取技能限制动作标签
func get_restricted_action_tags() -> Array[String]:
	return []

## 检查是否可以执行指定动作类型
func can_perform_action_category(action_category: StringName) -> bool:
	return true

## 检查技能是否可用
func is_skill_available(skill_id: StringName) -> bool:
	var ability_instance := ability_component.get_ability_instance(skill_id)
	return not ability_instance.get_definition().disabled
#endregion
