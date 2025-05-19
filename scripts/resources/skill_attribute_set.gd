extends Resource
class_name SkillAttributeSet

# 信号定义
## 当属性的基础值发生变化后发出
signal base_value_changed(attribute_instance: SkillAttribute, old_base_value: float, new_base_value: float, source: Variant)
## 当属性的当前值发生变化后发出 (在Modifier应用/移除并重算后)
signal current_value_changed(attribute_instance: SkillAttribute, old_current_value: float, new_current_value: float, source: Variant)

## 在编辑器中配置此AttributeSet需要初始化的属性模板及其基础值覆盖
@export var attributes_to_initialize: Array[SkillAttribute] = []

## 存储实际初始化的SkillAttribute实例
## Key: StringName (attribute_name), Value: SkillAttribute实例
var _initialized_attributes: Dictionary[StringName, SkillAttribute] = {}
var _is_initialized: bool = false

## 初始化AttributeSet，创建所有属性实例
## 通常在角色_ready()中，获得AttributeSet实例后调用
func initialize_set() -> void:
	if _is_initialized:
		printerr("AttributeSet is already initialized.")
		return

	_initialized_attributes.clear() # 清空以支持重复初始化 (如果需要)
	
	for template: SkillAttribute in attributes_to_initialize:
		# 关键：为每个角色复制独立的属性实例
		var attribute_instance: SkillAttribute = template.duplicate(true) as SkillAttribute
		attribute_instance.set_owner_set(self) # 设置对父Set的引用
		
		# 初始时，当前值等于基础值 (Modifier尚未应用)
		attribute_instance.current_value = attribute_instance.base_value 
		
		if _initialized_attributes.has(attribute_instance.attribute_name):
			printerr("Duplicate attribute_name '%s' found in AttributeSet configuration." % attribute_instance.attribute_name)
		_initialized_attributes[attribute_instance.attribute_name] = attribute_instance
	
	_is_initialized = true
	_on_resolve_initial_value_dependencies() # 调用钩子函数

	# 所有属性实例创建完毕后，可以进行一次全局的初始计算 (例如处理依赖关系，或确保CurrentHealth不超过MaxHealth)
	for attr_instance in _initialized_attributes.values():
		# 初始的 current_value 钳制 (例如 CurrentHealth 不应超过 MaxHealth)
		var old_cv = attr_instance.current_value
		var proposed_cv = attr_instance.current_value
		
		# 调用 _pre_current_value_change 钩子进行初始钳制
		var final_cv = _pre_current_value_change(attr_instance, old_cv, proposed_cv, "Initialization")
		if typeof(final_cv) == TYPE_FLOAT:
			attr_instance.current_value = final_cv
		elif typeof(final_cv) == TYPE_BOOL and not final_cv:
			# 初始化时不应被阻止，但可以记录一个警告
			print("Initial value for %s was proposed to be changed by pre-hook but returned false." % attr_instance.attribute_name)

	print("AttributeSet initialized with attributes: ", _initialized_attributes.keys())

## 获取指定名称的属性实例 (SkillAttribute的副本)
func get_attribute(attribute_name: StringName) -> SkillAttribute:
	if not _is_initialized: 
		printerr("AttributeSet not initialized. Call initialize_set() first.")
		return null
	if not _initialized_attributes.has(attribute_name):
		printerr("Attribute '%s' not found in this AttributeSet." % attribute_name)
		return null
	return _initialized_attributes[attribute_name]

## 获取属性的当前计算值
func get_current_value(attribute_name: StringName) -> float:
	var attr := get_attribute(attribute_name)
	return attr.get_current_value() if attr else 0.0

## 获取属性的基础值
func get_base_value(attribute_name: StringName) -> float:
	var attr := get_attribute(attribute_name)
	return attr.get_base_value() if attr else 0.0

## 设置属性的基础值
func set_base_value(attribute_name: StringName, new_base_value: float, source: Variant = null) -> bool:
	var attr : SkillAttribute = get_attribute(attribute_name)
	if not attr: return false

	var old_base = attr.get_base_value()
	if old_base == new_base_value: return false # 没有变化

	# 钩子：基础值变化前
	var proposed_value = _pre_base_value_change(attr, old_base, new_base_value, source)
	var final_new_base_value = new_base_value
	if typeof(proposed_value) == TYPE_FLOAT:
		final_new_base_value = proposed_value
	elif typeof(proposed_value) == TYPE_BOOL and not proposed_value:
		print("Change to base value of %s was denied by _pre_base_value_change." % attribute_name)
		return false # 变化被阻止

	attr.set_base_value_internal(final_new_base_value)
	
	# 基础值变化后，需要重算当前值，因为Modifier可能依赖基础值
	var old_current = attr.get_current_value()
	var new_current_after_recalc = attr.get_current_value()

	# 钩子：基础值变化后
	_post_base_value_change(attr, old_base, attr.get_base_value(), source)
	base_value_changed.emit(attr, old_base, attr.get_base_value(), source)

	# 如果当前值也因此改变，也触发当前值变化的钩子和信号
	if old_current != new_current_after_recalc:
		set_current_value(attribute_name, new_current_after_recalc, source)
		
	return true

##  设置属性的当前值
func set_current_value(attribute_name: StringName, new_current_value: float, source: Variant = null) -> bool:
	var attr : SkillAttribute = get_attribute(attribute_name)
	if not attr: return false

	var old_current_value = attr.get_current_value()
	var proposed_new_current_value = new_current_value

	# 钩子：当前值变化前
	var final_new_value = _pre_current_value_change(attr, old_current_value, proposed_new_current_value, source if source else "SetCurrent")
	if typeof(final_new_value) == TYPE_FLOAT:
		attr.current_value = final_new_value # 钩子可能再次修改（例如额外钳制）
	elif typeof(final_new_value) == TYPE_BOOL and not final_new_value:
		# 如果钩子阻止了这次当前值的变化，可能需要回滚或特殊处理，但通常不建议这么做
		print("Current value change for %s was denied by _pre_current_value_change." % attribute_name)
		return false # 变化被阻止

	# 触发当前值变化钩子
	_post_current_value_change(attr, old_current_value, attr.get_current_value(), source if source else "SetCurrent")
	current_value_changed.emit(attr, old_current_value, attr.get_current_value(), source if source else "SetCurrent")

	return true

## 向指定属性应用一个Modifier
func apply_modifier(modifier: SkillAttributeModifier, source: Variant = null):
	var attr : SkillAttribute = get_attribute(modifier.attribute_id)
	if not attr or not modifier: return

	# (可选) 可以在这里添加逻辑，如果Modifier已存在则如何处理 (例如基于source_id刷新或拒绝)
	if attr._active_modifiers.has(modifier):
		printerr("Modifier %s already exists for attribute %s." % [modifier, modifier.attribute_id])
		return
	
	attr.add_modifier_internal(modifier) # 添加到属性实例的列表
	var proposed_new_current_value = attr.get_current_value()

	set_current_value(modifier.attribute_id, proposed_new_current_value, source if source else modifier.source_id)

## 从指定属性移除一个Modifier (通过Modifier实例或其source_id)
func remove_modifier(modifier_or_id_to_remove: Variant, source: Variant = null):
	var attr : SkillAttribute = get_attribute(modifier_or_id_to_remove)
	if not attr: return

	var modifier_found_and_removed = false
	
	var temp_modifier_list = attr._active_modifiers.duplicate() # 复制列表以安全迭代和移除
	var modifier_to_remove : SkillAttributeModifier = null
	for m in temp_modifier_list:
		var should_remove = false
		if modifier_or_id_to_remove is SkillAttributeModifier and m == modifier_or_id_to_remove:
			should_remove = true
		elif modifier_or_id_to_remove is String and m.source_id == modifier_or_id_to_remove and m.source_id != "":
			should_remove = true # 允许多个来自同一source_id的modifier被一次性移除
		
		if should_remove:
			attr.remove_modifier_internal(m)
			modifier_to_remove = m
			modifier_found_and_removed = true
			# print("Attempting to remove modifier %s from %s" % [m, attribute_name])

	if not modifier_found_and_removed:
		# print("Modifier to remove not found on %s: " % attribute_name, modifier_or_id_to_remove)
		return

	var proposed_new_current_value = attr.get_current_value()

	set_current_value(modifier_to_remove.attribute_id, proposed_new_current_value, source if source else modifier_to_remove.source_id)

#region --- 钩子函数 (虚拟方法，由具体业务逻辑的AttributeSet子类重写) ---

## 在属性的基础值将要被修改之前调用。
## 返回值: float - 修正后的新基础值；或 bool (false表示阻止修改)。
func _pre_base_value_change(
		_attribute_instance: SkillAttribute, _old_base_value: float, 
		proposed_new_base_value: float, _source: Variant) -> Variant:
	# 默认实现：允许修改，不做任何变动。
	# 子类可重写，例如：力量属性的基础值不能低于1。
	return proposed_new_base_value

## 在属性的基础值已经被修改之后调用。
func _post_base_value_change(
		_attribute_instance: SkillAttribute, _old_base_value: float, 
		_new_base_value: float, _source: Variant) -> void:
	# 默认实现：什么也不做。
	# 子类可重写，例如：当“最大生命值”基础值变化时，可能需要按比例调整“当前生命值”的基础值（如果业务逻辑如此设计）。
	pass

## 在属性的当前值因Modifier应用/移除或基础值变化导致重算后，将要最终确认前调用。
## 返回值: float - 修正后的新当前值；或 bool (false表示阻止本次当前值的变化，但这通常不推荐，除非有非常特殊的理由)。
func _pre_current_value_change(
		attribute_instance: SkillAttribute, _old_current_value: float, 
		proposed_new_current_value: float, _source: Variant) -> Variant:
	var final_value = proposed_new_current_value
	
	# 通用钳制：例如，确保CurrentHealth不超过MaxHealth的当前值
	if attribute_instance.attribute_name == &"CurrentHealth":
		var max_health_attr = get_attribute(&"MaxHealth")
		if max_health_attr:
			final_value = clampf(final_value, attribute_instance.min_value, max_health_attr.get_current_value())
	
	# 其他通用钳制（基于属性自身定义）已在SkillAttribute.recalculate_current_value()中处理
	# 但这里可以添加更复杂的、跨属性的或特定于AttributeSet的钳制逻辑
	
	return final_value

## 在属性的当前值已经被修改并最终确认后调用。
func _post_current_value_change(
		_attribute_instance: SkillAttribute, _old_current_value: float, 
		_new_current_value: float, _source: Variant) -> void:
	# 默认实现：什么也不做。
	# 子类可重写，例如：
	# - 如果CurrentHealth变为0，触发角色死亡逻辑。
	# - 如果某个属性值达到特定阈值，赋予一个特殊状态。
	# - 更新UI（虽然更推荐UI直接监听信号）。
	# print("PostChange %s: from %s to %s (Source: %s)" % [attribute_instance.attribute_name, old_current_value, new_current_value, source])
	pass

## 可被派生类覆盖的钩子函数，用于在属性基础值设定后，最终校验前，处理属性间的初始化值依赖。
## 例如：将CurrentHealth的初始值设置为MaxHealth的初始值。
## 基类提供一个常见的默认实现。
func _on_resolve_initial_value_dependencies() -> void:
	# 默认实现：同步CurrentHealth与MaxHealth, CurrentMana与MaxMana
	var current_health_attr: SkillAttribute = get_attribute(&"CurrentHealth")
	var max_health_attr: SkillAttribute = get_attribute(&"MaxHealth")

	if current_health_attr and max_health_attr:
		current_health_attr.current_value = max_health_attr.get_current_value()
		# print_rich("Hook InitDep: [b]CurrentHealth[/b] (%.1f) set by [b]MaxHealth[/b] (%.1f)" % [current_health_attr.current_value, max_health_attr.get_current_value()])

	var current_mana_attr: SkillAttribute = get_attribute(&"CurrentMana")
	var max_mana_attr: SkillAttribute = get_attribute(&"MaxMana")

	if current_mana_attr and max_mana_attr:
		current_mana_attr.current_value = max_mana_attr.get_current_value()
		# print_rich("Hook InitDep: [b]CurrentMana[/b] (%.1f) set by [b]MaxMana[/b] (%.1f)" % [current_mana_attr.current_value, max_mana_attr.get_current_value()])

#endregion
