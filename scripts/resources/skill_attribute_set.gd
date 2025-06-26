extends Resource
class_name SkillAttributeSet

## 在编辑器中配置此AttributeSet需要初始化的属性模板及其基础值覆盖
@export var attributes_to_initialize: Array[SkillAttribute] = []

## 存储实际初始化的SkillAttribute实例
## Key: StringName (attribute_name), Value: SkillAttribute实例
var _initialized_attributes: Dictionary[StringName, SkillAttribute] = {}
var _is_initialized: bool = false

# 信号定义
## 当属性的基础值发生变化后发出
signal base_value_changed(attribute_instance: SkillAttribute, old_base_value: float, new_base_value: float)
## 当属性的当前值发生变化后发出 (在Modifier应用/移除并重算后)
signal current_value_changed(attribute_instance: SkillAttribute, old_current_value: float, new_current_value: float)

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
		attribute_instance.set_base_value_internal(attribute_instance.base_value)
		attribute_instance.base_value_changed.connect(
			func(old_value, new_value): base_value_changed.emit(attribute_instance, old_value, new_value)
		)
		attribute_instance.current_value_changed.connect(
			func(old_value, new_value): current_value_changed.emit(attribute_instance, old_value, new_value)
		)
		
		if _initialized_attributes.has(attribute_instance.attribute_name):
			printerr("Duplicate attribute_name '%s' found in AttributeSet configuration." % attribute_instance.attribute_name)
		_initialized_attributes[attribute_instance.attribute_name] = attribute_instance
	
	_is_initialized = true
	_on_resolve_initial_value_dependencies() # 调用钩子函数

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
	
	# 钩子：基础值变化后
	_post_base_value_change(attr, old_base, attr.get_base_value(), source)
	return true

## 修改属性基础值
func modify_base_value(attribute_name: StringName, modify_value: float, source: Variant = null) -> bool:
	var attr : SkillAttribute = get_attribute(attribute_name)
	if not attr: return false
	
	return set_base_value(attribute_name, attr.get_base_value() + modify_value, source)

## 向指定属性应用一个Modifier
func apply_modifier(modifier: SkillAttributeModifier, source_id : int) -> void:
	var attr : SkillAttribute = get_attribute(modifier.attribute_id)
	if not attr or not modifier: return
	# (可选) 可以在这里添加逻辑，如果Modifier已存在则如何处理 (例如基于source_id刷新或拒绝)
	if attr.get_active_modifiers().has(modifier):
		printerr("Modifier %s already exists for attribute %s." % [modifier, modifier.attribute_id])
		return
	modifier.source_id = source_id
	attr.add_modifier_internal(modifier) # 添加到属性实例的列表

## 从指定属性移除一个Modifier (通过Modifier实例或其source_id)
func remove_modifier(modifier_instance: SkillAttributeModifier) -> void:
	if not is_instance_valid(modifier_instance): return

	var attr : SkillAttribute = get_attribute(modifier_instance.attribute_id)
	if not attr: return
	
	# 直接调用内部方法，逻辑清晰
	attr.remove_modifier_internal(modifier_instance)

## 通过来源ID移除匹配该ID的所有修改器
func remove_modifiers_by_source_id(source_id: String) -> void:
	if source_id.is_empty(): return

	for attr : SkillAttribute in _initialized_attributes.values():
		# 为了安全地在迭代中移除元素，我们从后往前遍历
		var modifiers : Array[SkillAttributeModifier] = attr.get_active_modifiers()
		for i in range(modifiers.size() - 1, -1, -1):
			var modifier = modifiers[i]
			if modifier.source_id == source_id:
				attr.remove_modifier_internal(modifier)

#region --- 钩子函数 (虚拟方法，由具体业务逻辑的AttributeSet子类重写) ---

## 在属性的基础值将要被修改之前调用。
## 返回值: float - 修正后的新基础值；或 bool (false表示阻止修改)。
func _pre_base_value_change(
		attribute_instance: SkillAttribute, _old_base_value: float, 
		proposed_new_base_value: float, _source: Variant) -> Variant:
	var final_value = proposed_new_base_value
	
	# 通用钳制：例如，确保CurrentHealth不超过MaxHealth
	if attribute_instance.attribute_name == &"CurrentHealth":
		var max_health_attr = get_attribute(&"MaxHealth")
		if max_health_attr:
			final_value = clampf(final_value, attribute_instance.min_value, max_health_attr.get_current_value())
	return final_value

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
		_attribute_instance: SkillAttribute, _old_current_value: float, 
		proposed_new_current_value: float, _source: Variant) -> Variant:
	# 其他通用钳制（基于属性自身定义）已在SkillAttribute.recalculate_current_value()中处理
	# 但这里可以添加更复杂的、跨属性的或特定于AttributeSet的钳制逻辑
	return proposed_new_current_value

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
		current_health_attr.set_base_value_internal(max_health_attr.get_base_value())

	var current_mana_attr: SkillAttribute = get_attribute(&"CurrentMana")
	var max_mana_attr: SkillAttribute = get_attribute(&"MaxMana")

	if current_mana_attr and max_mana_attr:
		current_mana_attr.set_base_value_internal(max_mana_attr.get_base_value())
		# print_rich("Hook InitDep: [b]CurrentMana[/b] (%.1f) set by [b]MaxMana[/b] (%.1f)" % [current_mana_attr.current_value, max_mana_attr.get_current_value()])
#endregion
