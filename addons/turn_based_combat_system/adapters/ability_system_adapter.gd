extends Node
class_name AbilitySystemAdapter

## 技能系统适配器
## 将 godot_ability_system 适配到 turn_based_combat_system 的接口
## 使 CharacterCombatComponent 能够通过鸭子类型访问 godot_ability_system

## 引用的 godot_ability_system 组件
@export var ability_component: GameplayAbilityComponent
## Vital组件（继承自GameplayAttributeComponent，包含属性功能）
@export var vital_component: GameplayVitalAttributeComponent
@export var status_component: GameplayStatusComponent

## 动作限制标签（用于控制角色能否行动）
var _restricted_action_tags: Array[String] = []

## 技能ID到GameplayAbilityDefinition的映射（如果需要兼容旧的SkillData）
var _skill_data_map: Dictionary[StringName, GameplayAbilityDefinition] = {}
## SkillData到GameplayAbilityDefinition的映射（用于兼容旧接口）
var _skill_data_to_ability_map: Dictionary = {}

signal attribute_current_value_changed(attribute_instance, old_value: float, new_value: float)
signal action_tags_changed(restricted_tags: Array[String])

func _ready() -> void:
	# 自动查找组件（如果未手动指定）
	if not is_instance_valid(ability_component):
		ability_component = _find_component("GameplayAbilityComponent")
	if not is_instance_valid(vital_component):
		vital_component = _find_component("GameplayVitalAttributeComponent")
	if not is_instance_valid(status_component):
		status_component = _find_component("GameplayStatusComponent")
	
	# 连接信号
	_connect_signals()

## 查找组件
func _find_component(class_name_str: String) -> Node:
	var parent = get_parent()
	if not is_instance_valid(parent):
		return null
	
	# 在子节点中查找
	for child in parent.get_children():
		if child.get_script() and child.get_script().get_global_name() == class_name_str:
			return child
	
	return null

## 连接信号
func _connect_signals() -> void:
	# 连接属性变化信号（通过vital_component，因为它继承自GameplayAttributeComponent）
	if vital_component and vital_component.has_signal("attribute_value_changed"):
		if not vital_component.attribute_value_changed.is_connected(_on_attribute_value_changed):
			vital_component.attribute_value_changed.connect(_on_attribute_value_changed)
	
	# 连接Vital变化信号
	if vital_component and vital_component.has_signal("vital_value_changed"):
		if not vital_component.vital_value_changed.is_connected(_on_vital_value_changed):
			vital_component.vital_value_changed.connect(_on_vital_value_changed)
	
	# 连接状态变化信号（用于更新动作限制）
	if status_component and status_component.has_signal("status_applied"):
		if not status_component.status_applied.is_connected(_on_status_applied):
			status_component.status_applied.connect(_on_status_applied)
	if status_component and status_component.has_signal("status_removed"):
		if not status_component.status_removed.is_connected(_on_status_removed):
			status_component.status_removed.connect(_on_status_removed)

#region ========== 接口实现（适配 turn_based_combat_system） ==========

## 获取动作限制标签
func get_restricted_action_tags() -> Array[String]:
	return _restricted_action_tags.duplicate()

## 检查是否可以执行特定类别的动作
func can_perform_action_category(category: StringName) -> bool:
	# 检查是否有全局限制
	if _restricted_action_tags.has("any_action"):
		return false
	
	# 检查特定类别限制
	if _restricted_action_tags.has(category):
		return false
	
	return true

## 检查技能是否可用（适配旧的SkillData接口）
## 注意：这里需要将SkillData映射到GameplayAbilityDefinition
func is_skill_available(skill: Resource) -> bool:
	if not ability_component:
		return false
	
	var ability_id: StringName = &""
	
	# 如果传入的是GameplayAbilityDefinition，直接使用
	if skill is GameplayAbilityDefinition:
		ability_id = skill.ability_id
	# 如果是旧的SkillData，尝试通过映射查找
	elif skill.has_method("get") and skill.get("skill_id"):
		var skill_id = skill.get("skill_id")
		if skill_id is StringName:
			ability_id = skill_id
			# 如果映射字典中有，使用映射
			if _skill_data_map.has(ability_id):
				ability_id = _skill_data_map[ability_id].ability_id
	# 如果通过对象引用映射
	elif skill in _skill_data_to_ability_map:
		var mapped_ability = _skill_data_to_ability_map[skill]
		if mapped_ability is GameplayAbilityDefinition:
			ability_id = mapped_ability.ability_id
	
	if ability_id.is_empty():
		return false
	
	if not ability_component.has_ability(ability_id):
		return false
	
	# 检查技能实例是否可用（冷却、消耗等）
	var ability_instance = ability_component.get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		return false
	
	# 检查技能是否可以激活
	return ability_instance.can_activate({})

## 检查是否有足够的MP使用技能
func has_enough_mp_for_skill(skill: Resource) -> bool:
	if not ability_component or not vital_component:
		return true  # 如果没有组件，假设总是有足够的MP
	
	var ability_id: StringName = &""
	
	# 获取技能ID
	if skill is GameplayAbilityDefinition:
		ability_id = skill.ability_id
	elif skill.has_method("get") and skill.get("skill_id"):
		var skill_id = skill.get("skill_id")
		if skill_id is StringName:
			ability_id = skill_id
			# 如果映射字典中有，使用映射
			if _skill_data_map.has(ability_id):
				ability_id = _skill_data_map[ability_id].ability_id
	# 如果通过对象引用映射
	elif skill in _skill_data_to_ability_map:
		var mapped_ability = _skill_data_to_ability_map[skill]
		if mapped_ability is GameplayAbilityDefinition:
			ability_id = mapped_ability.ability_id
	
	if ability_id.is_empty() or not ability_component.has_ability(ability_id):
		return true  # 如果找不到技能，假设可以
	
	# 获取技能实例并检查消耗
	var ability_instance = ability_component.get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		return true
	
	# 创建上下文检查消耗（通过CostFeature）
	var context = {
		"ability_component": ability_component,
		"instigator": get_parent(),
		"skip_cost": false
	}
	
	# 检查CostFeature
	var cost_feature = ability_instance.get_feature("CostFeature") as CostFeature
	if not is_instance_valid(cost_feature):
		return true  # 没有消耗，总是可以
	
	# 检查是否可以支付消耗
	return cost_feature.can_activate(ability_instance, context)

## 获取可用技能列表
func get_available_skills() -> Array:
	if not ability_component:
		return []
	
	var available: Array = []
	var ability_ids = ability_component.get_all_ability_ids()
	
	for ability_id in ability_ids:
		var ability_instance = ability_component.get_ability_instance(ability_id)
		if not is_instance_valid(ability_instance):
			continue
		
		# 检查技能是否可用（冷却、消耗等）
		if ability_instance.can_activate({}):
			available.append(ability_instance.get_definition())
	
	return available

## 添加技能（可选，用于兼容旧接口）
func add_skill(skill: Resource) -> void:
	if not ability_component:
		return
	
	# 如果传入的是GameplayAbilityDefinition，直接学习
	if skill is GameplayAbilityDefinition:
		ability_component.learn_ability(skill)
		return
	
	# 如果是旧的SkillData，尝试通过映射查找
	if skill in _skill_data_to_ability_map:
		var mapped_ability = _skill_data_to_ability_map[skill]
		if mapped_ability is GameplayAbilityDefinition:
			ability_component.learn_ability(mapped_ability)
			return
	
	# 如果是旧的SkillData，需要转换（这里需要业务层实现转换逻辑）
	push_warning("AbilitySystemAdapter: Cannot add skill of type %s, need GameplayAbilityDefinition or register mapping first" % skill.get_class())

## 注册SkillData到GameplayAbilityDefinition的映射（用于兼容旧接口）
func register_skill_mapping(skill_data: Resource, ability_def: GameplayAbilityDefinition) -> void:
	if skill_data.has_method("get") and skill_data.get("skill_id"):
		var skill_id = skill_data.get("skill_id")
		if skill_id is StringName:
			_skill_data_map[skill_id] = ability_def
	_skill_data_to_ability_map[skill_data] = ability_def

## 消耗生命值
func consume_hp(amount: float) -> bool:
	if not vital_component:
		return false
	
	# 假设使用 "Health" 作为ID
	var health_id = &"Health"
	if not vital_component.has_vital(health_id):
		health_id = &"HP"
		if not vital_component.has_vital(health_id):
			return false
	
	return vital_component.modify_vital(health_id, -amount)

## 恢复生命值
func restore_hp(amount: float) -> float:
	if not vital_component:
		return 0.0
	
	# 假设使用 "Health" 作为ID
	var health_id = &"Health"
	if not vital_component.has_vital(health_id):
		health_id = &"HP"
		if not vital_component.has_vital(health_id):
			return 0.0
	
	var before = vital_component.get_vital_value(health_id)
	vital_component.modify_vital(health_id, amount)
	var after = vital_component.get_vital_value(health_id)
	return after - before

## 使用魔法值（可选）
func use_mp(amount: float) -> bool:
	if not vital_component:
		return false
	
	var mana_id = &"Mana"
	if not vital_component.has_vital(mana_id):
		mana_id = &"MP"
		if not vital_component.has_vital(mana_id):
			return false
	
	return vital_component.modify_vital(mana_id, -amount)

## 处理活跃状态效果
func process_active_statuses(battle_manager: Node) -> void:
	if not status_component:
		return
	
	# godot_ability_system 的状态系统会自动处理，这里可以添加额外的逻辑
	# 例如：检查状态是否影响战斗流程
	var active_statuses = status_component.get_active_statuses()
	for status_instance in active_statuses:
		# 可以在这里处理状态对战斗的影响
		pass

## 更新状态持续时间
func update_status_durations() -> void:
	# godot_ability_system 的状态系统会自动更新，这里不需要额外操作
	pass

func get_skill_name(skill: Resource) -> String:
	if skill is GameplayAbilityDefinition:
		return skill.ability_name
	return ""

func is_skill_melee(skill: Resource) -> bool:
	if skill is GameplayAbilityDefinition:
		return skill.tags.has(&"melee")
	return false

#endregion

#region ========== 辅助方法 ==========
## 获取技能消耗
func _get_skill_cost(skill: Resource) -> float:
	if skill is GameplayAbilityDefinition:
		if not is_instance_valid(skill):
			return 0.0
		var ability_instance = ability_component.get_ability_instance(skill.ability_id)
		if not is_instance_valid(ability_instance):
			push_error("AbilitySystemAdapter: Ability instance not found for skill %s" % skill.ability_id)
			return 0.0
		if not ability_instance.has_feature("CostFeature"):
			return 0.0
		var cost_feature = ability_instance.get_feature("CostFeature") as CostFeature
		if not is_instance_valid(cost_feature):
			return 0.0
		for cost in cost_feature.costs:
			if cost is VitalCost:
				return cost.amount
		return 0.0
	return 0.0

## 属性值变化处理
func _on_attribute_value_changed(id: StringName, new_val: float) -> void:
	# 通过vital_component获取属性实例（因为它继承自GameplayAttributeComponent）
	if not vital_component:
		return
	var attr_instance = vital_component.get_attribute(id)
	if attr_instance:
		var old_val = attr_instance.get_value() - (new_val - attr_instance.get_value())
		attribute_current_value_changed.emit(attr_instance, old_val, new_val)

## Vital值变化处理
func _on_vital_value_changed(vital_id: StringName, current: float, max: float, percent: float, is_regen: bool) -> void:
	# 如果是生命值变化，可能需要触发属性变化信号
	if vital_id == &"Health" or vital_id == &"HP":
		# 可以在这里触发生命值变化事件
		pass

## 状态应用处理
func _on_status_applied(status_id: StringName, instance: GameplayStatusInstance) -> void:
	# 检查状态是否影响动作限制
	_update_action_restrictions()

## 状态移除处理
func _on_status_removed(status_id: StringName) -> void:
	# 更新动作限制
	_update_action_restrictions()

## 更新动作限制（根据状态标签）
func _update_action_restrictions() -> void:
	if not is_instance_valid(status_component):
		return
	
	var new_restrictions: Array[String] = []
	var active_statuses = status_component.get_active_statuses()
	
	for status_instance in active_statuses:
		var status_data = status_instance.status_data
		if not status_data:
			continue
		
		# 检查状态的标签，如果包含动作限制标签，添加到限制列表
		# 这里需要根据实际的标签系统实现
		# 例如：如果状态有 "block_action" 标签，则限制动作
		for tag in status_data.tags:
			if tag == &"block_action" or tag == &"any_action":
				if not new_restrictions.has(tag):
					new_restrictions.append(tag)
	
	# 如果限制发生变化，发出信号
	if new_restrictions != _restricted_action_tags:
		_restricted_action_tags = new_restrictions
		action_tags_changed.emit(_restricted_action_tags)

#endregion
