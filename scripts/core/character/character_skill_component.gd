extends Node
class_name CharacterSkillComponent

## 运行时角色实际持有的AttributeSet实例 (通过模板duplicate而来)
var _active_attribute_set: SkillAttributeSet = null		
## 可用的技能
var _skills: Array[SkillData] = []

## 信号
signal attribute_base_value_changed(attribute_instance: SkillAttribute, old_value: float, new_value: float)				## 属性基础值改变
signal attribute_current_value_changed(attribute_instance: SkillAttribute, old_value: float, new_value: float)			## 属性当前值改变

## 初始化组件
func initialize(attribute_set_resource: SkillAttributeSet, skills: Array[SkillData]) -> void:
	# 这是因为AttributeSet本身是一个Resource, 直接使用会导致所有实例共享数据
	_active_attribute_set = attribute_set_resource.duplicate(true)
	# 初始化技能列表
	_skills = skills
	if not _active_attribute_set:
		push_error("无法初始化AttributeSet，资源无效！")
		return
	if not _skills.is_empty() and not _skills:
		push_error("无法初始化技能列表，技能数据无效！")
		return

	# 初始化AttributeSet，这将创建并配置所有属性实例
	_active_attribute_set.initialize_set()
	
	_active_attribute_set.current_value_changed.connect(
		func(attribute_instance: SkillAttribute, old_value: float, new_value: float) -> void:
			attribute_current_value_changed.emit(attribute_instance, old_value, new_value)
	)
	_active_attribute_set.base_value_changed.connect(
		func(attribute_instance: SkillAttribute, old_value: float, new_value: float) -> void:
			attribute_base_value_changed.emit(attribute_instance, old_value, new_value)
	)

#region --- 属性管理 ---
## 获取属性基础值
func get_attribute_base_value(attribute_name: StringName) -> float:
	return _active_attribute_set.get_base_value(attribute_name)

## 获取属性当前值
func get_attribute_current_value(attribute_name: StringName) -> float:
	return _active_attribute_set.get_current_value(attribute_name)

## 设置属性基础值
func set_attribute_base_value(attribute_name: StringName, value: float) -> void:
	_active_attribute_set.set_base_value(attribute_name, value)

## 添加属性修改器
func add_attribute_modifier(attribute_name: StringName, modifier: SkillAttributeModifier) -> void:
	_active_attribute_set.add_attribute_modifier(attribute_name, modifier)

## 移除属性修改器
func remove_attribute_modifier(attribute_name: StringName, modifier: SkillAttributeModifier) -> void:
	_active_attribute_set.remove_attribute_modifier(attribute_name, modifier)

## 获取属性修改器
func get_attribute_modifiers(attribute_name: StringName) -> Array[SkillAttributeModifier]:
	return _active_attribute_set.get_attribute_modifiers(attribute_name)

## 获取属性实例
func get_attribute(attribute_name: StringName) -> SkillAttribute:
	return _active_attribute_set.get_attribute(attribute_name)

## 获取AttributeSet
func get_attribute_set() -> SkillAttributeSet:
	return _active_attribute_set

## 使用MP
func use_mp(amount: float) -> bool:
	var current_mp = _active_attribute_set.get_current_value(&"CurrentMana")
	if current_mp < amount:
		return false
	_active_attribute_set.modify_base_value(&"CurrentMana", -amount)
	return true

## 恢复MP
func restore_mp(amount: float) -> float:
	_active_attribute_set.modify_base_value(&"CurrentMana", amount)
	return amount

## 消耗生命值
func consume_hp(amount: float) -> bool:
	_active_attribute_set.modify_base_value(&"CurrentHealth", -amount)
	return true

## 恢复生命值
func restore_hp(amount: float) -> float:
	_active_attribute_set.modify_base_value(&"CurrentHealth", amount)
	return amount
#endregion

#region --- 技能管理 ---

## 是否有足够的MP释放技能
func has_enough_mp_for_any_skill() -> bool:
	var current_mp = _active_attribute_set.get_current_value(&"CurrentMana")
	for skill in _skills:
		if current_mp >= skill.mp_cost:
			return true
	return false

## 检查是否有足够的MP使用指定技能
func has_enough_mp_for_skill(skill: SkillData) -> bool:
	var current_mp = _active_attribute_set.get_current_value(&"CurrentMana")
	return current_mp >= skill.mp_cost

## 获取所有技能
## [return] 技能数据数组
func get_skills() -> Array[SkillData]:
	return _skills

## 添加技能
func add_skill(skill: SkillData) -> void:
	_skills.append(skill)

## 移除技能
func remove_skill(skill: SkillData) -> void:
	_skills.erase(skill)

## 获取技能
## [param skill_id] 技能ID
## [return] 技能数据
func get_skill(skill_id: StringName) -> SkillData:
	for skill in _skills:
		if skill.skill_id == skill_id:
			return skill
	return null

## 检查是否有指定技能
## [param skill_id] 技能ID
## [return] 是否有指定技能
func has_skill(skill_id: StringName) -> bool:
	return get_skill(skill_id) != null

## 获取技能数量
## [return] 技能数量
func get_skill_count() -> int:
	return _skills.size()

## 获取可用技能列表
## [return] 可用技能列表
func get_available_skills() -> Array:
	var available_skills : Array = []
	for skill in _skills:
		if has_enough_mp_for_skill(skill):
			available_skills.append(skill)
	return available_skills
#endregion

