extends Resource
class_name SkillAttribute

## 属性的唯一标识名 (例如: "MaxHealth", "AttackPower")
@export var attribute_name: StringName = &""
## 属性的显示名称 (例如: "最大生命值", "攻击力")
@export var display_name: String = ""
## 属性的详细描述
@export_multiline var description: String = ""
## 属性的基础值。在.tres模板中代表默认基础值。
## 在被AttributeSet持有的实例中，代表该角色此属性的当前基础值。
@export var base_value: float = 0.0:
	set(value):
		var old_value = base_value
		base_value = value
		base_value_changed.emit(old_value, value)
## 属性允许的最小值
@export var min_value: float = -INF
## 属性允许的最大值
@export var max_value: float = INF
## 属性值是否可以为负
@export var can_be_negative: bool = false

var current_value: float = 0.0:								## 属性的当前值 (运行时计算得出，不直接导出)
	set(value):
		var old_value = current_value
		current_value = value
		current_value_changed.emit(old_value, value)
var _active_modifiers: Array[SkillAttributeModifier] = []	## 当前作用于此属性实例的修改器列表 (由AttributeSet管理添加和移除)
var _owner_set: SkillAttributeSet = null					## 对所属AttributeSet的引用 (在AttributeSet初始化时设置)

signal current_value_changed(old_value, new_value)
signal base_value_changed(old_value, new_value)

func _init(p_owner_set: SkillAttributeSet = null, p_base_value_override: float = -1.0) -> void:
	_owner_set = p_owner_set
	if p_base_value_override != -1.0: # 允许在实例化时覆盖默认基础值
		base_value = p_base_value_override
	else:
		# 如果没有覆盖，确保current_value初始时基于base_value（在.tres中配置的）
		# 但完整的_recalculate_current_value通常在AttributeSet初始化后调用
		pass

	# 注意：current_value的初始计算最好由AttributeSet在所有属性都实例化后统一触发
	# 此处仅确保变量存在。

func get_active_modifiers() -> Array[SkillAttributeModifier]:
	return _active_modifiers

## (由AttributeSet调用) 添加一个Modifier并触发重算
func add_modifier_internal(modifier: SkillAttributeModifier) -> void:
	if not modifier in _active_modifiers: # 避免重复添加同一个Modifier实例
		_active_modifiers.append(modifier)
		_recalculate_current_value()
		# print("Added modifier %s to %s" % [modifier, attribute_name])

## (由AttributeSet调用) 移除一个Modifier并触发重算
func remove_modifier_internal(modifier: SkillAttributeModifier) -> void:
	if modifier in _active_modifiers:
		_active_modifiers.erase(modifier)
		_recalculate_current_value()
		# print("Removed modifier %s from %s" % [modifier, attribute_name])

## (由AttributeSet调用) 设置基础值
func set_base_value_internal(new_base_value: float) -> void:
	base_value = new_base_value
	_recalculate_current_value()

## 获取当前计算出的值
func get_current_value() -> float:
	return current_value

## 获取基础值
func get_base_value() -> float:
	return base_value

## 设置所属的AttributeSet (在AttributeSet中实例化此属性时调用)
func set_owner_set(owner: SkillAttributeSet) -> void:
	_owner_set = owner

## 重新计算current_value，基于base_value和所有激活的Modifier
## 返回值: bool - 当前值是否实际发生了变化
func _recalculate_current_value() -> bool:
	var previous_current_value = current_value
	var value_after_additive_mods = base_value # 用于某些百分比计算的基准
	var additive_bonus: float = 0.0
	var multiply_percentage_total_bonus: float = 1.0 # 乘法叠加器通常从1开始

	# 步骤 1: 计算所有固定值增减 (Additive)
	for modifier in _active_modifiers:
		if modifier.operation == SkillAttributeModifier.ModifierOperation.ADD_ABSOLUTE:
			additive_bonus += modifier.magnitude
	
	value_after_additive_mods += additive_bonus

	# 步骤 2: 计算基于“当前累计值”的百分比修改 (通常这些Modifier会独立相乘或相加作用)
	# 我们这里采用独立相乘的方式更为常见和灵活 (例如: 最终伤害*1.5, 然后再*1.2)
	for modifier in _active_modifiers:
		if modifier.operation == SkillAttributeModifier.ModifierOperation.ADD_PERCENTAGE:
			multiply_percentage_total_bonus *= (1.0 + modifier.magnitude) 
			# 注意: magnitude 为 0.2 表示 +20%, -0.1 表示 -10%

	var final_value = value_after_additive_mods * multiply_percentage_total_bonus

	# 步骤 3: 处理覆盖型Modifier (Override) - 通常取最后一个或优先级最高的
	# 为简化，我们取最后一个遇到的Override Modifier
	var override_value: float = NAN # Not A Number, 表示没有Override
	for modifier in _active_modifiers:
		if modifier.operation == SkillAttributeModifier.ModifierOperation.OVERRIDE:
			override_value = modifier.magnitude
	
	if not is_nan(override_value):
		final_value = override_value

	# 步骤 4: 应用最终钳制 (Clamping)
	var clamped_value = final_value
	if not can_be_negative and clamped_value < 0.0:
		clamped_value = 0.0
	
	clamped_value = clampf(clamped_value, min_value, max_value)

	# 更新current_value
	current_value = clamped_value
	
	return current_value != previous_current_value
