extends Node2D
class_name Character

@export var character_data: CharacterData

#region --- 常用属性的便捷Getter ---
var current_hp: float:
	get: return active_attribute_set.get_current_value(&"CurrentHealth") if active_attribute_set else 0.0
var max_hp: float:
	get: return active_attribute_set.get_current_value(&"MaxHealth") if active_attribute_set else 0.0
var current_mp: float:
	get: return active_attribute_set.get_current_value(&"CurrentMana") if active_attribute_set else 0.0
var max_mp: float:
	get: return active_attribute_set.get_current_value(&"MaxMana") if active_attribute_set else 0.0
var attack_power: float:
	get: return active_attribute_set.get_current_value(&"AttackPower") if active_attribute_set else 0.0
var defense_power: float:
	get: return active_attribute_set.get_current_value(&"DefensePower") if active_attribute_set else 0.0
var speed: float:
	get: return active_attribute_set.get_current_value(&"Speed") if active_attribute_set else 0.0
var magic_attack : float:
	get: return active_attribute_set.get_current_value(&"MagicAttack") if active_attribute_set else 0.0
var magic_defense : float:
	get: return active_attribute_set.get_current_value(&"MagicDefense") if active_attribute_set else 0.0
var character_name : StringName:
	get: return character_data.character_name if character_data else "" 
#endregion

# 引用场景中的节点
@onready var hp_bar : ProgressBar = %HPBar
@onready var hp_label := %HPLabel
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_label: Label = %MPLabel
@onready var name_label := $Container/NameLabel
@onready var character_rect := %CharacterRect
@onready var defense_indicator : DefenseIndicator = $DefenseIndicator

var is_defending: bool = false							## 防御状态标记
var is_alive : bool = true:								## 生存状态标记
	get: return current_hp > 0
var active_attribute_set: SkillAttributeSet = null		## 运行时角色实际持有的AttributeSet实例 (通过模板duplicate而来)

signal character_defeated(character: Character)
signal health_changed(current_hp: float, max_hp: float, character: Character)
signal mana_changed(current_mp: float, max_mp: float, character: Character)

func _ready():
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")

	# 链接AttributeSet到Character
	active_attribute_set.current_value_changed.connect(_on_attribute_current_value_changed)
	active_attribute_set.base_value_changed.connect(_on_attribute_base_value_changed)
	
	# 初始化UI显示
	_update_name_display()
	_update_health_display()
	_update_mana_display()

	print("%s initialized. HP: %.1f/%.1f, Attack: %.1f" % [character_data.character_name, current_hp, max_hp, attack_power])

## 初始化玩家数据
func initialize_from_data(data: CharacterData):
	# 保存数据引用
	character_data = data
	
	character_name = character_data.character_name
	# 为每个Character实例创建独立的AttributeSet
	# 这是因为AttributeSet本身是一个Resource, 直接使用会导致所有实例共享数据
	active_attribute_set = character_data.attribute_set_resource.duplicate(true)
	if not active_attribute_set:
		push_error("无法创建AttributeSet实例！")
		return
	
	# 初始化AttributeSet，这将创建并配置所有属性实例
	active_attribute_set.initialize_set()
	
	# 更新视觉表现
	update_visual()
	
	print_rich("[color=cyan][b]{0}[/b][/color] 初始化完毕，HP: [color=lime]{1}/{2}[/color]".format([character_name, current_hp, max_hp]))

## 更新显示
func update_visual():
	if name_label:
		name_label.text = character_name
	
	if character_rect and character_data:
		character_rect.color = character_data.color

## 设置防御状态
func set_defending(value: bool) -> void:
	is_defending = value
	if defense_indicator:
		if is_defending:
			defense_indicator.show_indicator()
		else:
			defense_indicator.hide_indicator()

## 伤害处理方法
func take_damage(base_damage: float) -> float:
	var final_damage: float = base_damage

	# 如果处于防御状态，则减免伤害
	if is_defending:
		final_damage = round(final_damage * 0.5)
		print(character_name + " 正在防御，伤害减半！")
		set_defending(false)	# 防御效果通常在受到一次攻击后解除

	if final_damage <= 0: 
		return 0

	active_attribute_set.modify_base_value("CurrentHealth", -final_damage)
	return final_damage

func heal(amount: int) -> int:
	active_attribute_set.modify_base_value("CurrentHealth", amount)
	return amount

func use_mp(amount: int) -> bool:
	if current_mp >= amount:
		active_attribute_set.modify_base_value("CurrentMana", -amount)
		return true
	return false

## 回合开始时重置标记
func reset_turn_flags() -> void:
	set_defending(false)

## 是否足够释放技能MP
func has_enough_mp_for_any_skill() -> bool:
	for skill in character_data.skills:
		if current_mp >= skill.mp_cost:
			return true
	return false

## 播放动画
func play_animation(animation_name: String) -> void:
	print("假装播放了动画：", animation_name)

## 死亡处理方法
func _die():
	# is_alive 的getter会自动更新，但这里可以执行死亡动画、音效、移除出战斗等逻辑
	print_rich("[color=red][b]%s[/b] has been defeated![/color]" % [character_data.character_name])
	character_defeated.emit(self)
	modulate = Color(0.5, 0.5, 0.5, 0.5) # 变灰示例

#region --- UI 更新辅助方法 ---
func _update_name_display() -> void:
	if name_label and character_data:
		name_label.text = character_data.character_name

func _update_health_display() -> void:
	if hp_bar and active_attribute_set: # 确保active_attribute_set已初始化
		var current_val = active_attribute_set.get_current_value(&"CurrentHealth")
		var max_val = active_attribute_set.get_current_value(&"MaxHealth")
		hp_bar.max_value = max_val
		hp_bar.value = current_val
		hp_label.text = "%d/%d" % [roundi(current_val), roundi(max_val)]

func _update_mana_display() -> void:
	if mp_bar and active_attribute_set: # 确保active_attribute_set已初始化
		var current_val = active_attribute_set.get_current_value(&"CurrentMana")
		var max_val = active_attribute_set.get_current_value(&"MaxMana")
		mp_bar.max_value = max_val
		mp_bar.value = current_val
		mp_label.text = "%d/%d" % [roundi(current_val), roundi(max_val)]

#endregion

## 当AttributeSet中的属性当前值变化时调用
func _on_attribute_current_value_changed(attribute_instance: SkillAttribute, old_value: float, new_value: float):
	if attribute_instance.attribute_name == &"CurrentHealth":
		health_changed.emit(new_value, max_hp, self)
		_update_health_display()
		if new_value <= 0.0 and old_value > 0.0: # 从存活到死亡
			_die()
	elif attribute_instance.attribute_name == &"MaxHealth":
		# MaxHealth变化也需要通知UI更新，并可能影响CurrentHealth的钳制（已在AttributeSet钩子中处理）
		health_changed.emit(current_hp, new_value, self)
		_update_health_display()
	elif attribute_instance.attribute_name == &"CurrentMana":
		mana_changed.emit(new_value, max_mp, self)
		_update_mana_display()
	elif attribute_instance.attribute_name == &"MaxMana":
		mana_changed.emit(current_mp, new_value, self)
		_update_mana_display()

## 当AttributeSet中的属性基础值变化时调用
func _on_attribute_base_value_changed(attribute_instance: SkillAttribute, _old_value: float, _new_value: float):
	# 通常基础值变化也会导致当前值变化，相关信号已在_on_attribute_current_value_changed处理
	# 但如果UI需要特别区分显示基础值和当前值，可以在这里做处理
	if attribute_instance.attribute_name == &"MaxHealth": # 例如基础MaxHealth变化
		_update_health_display() # 确保UI同步

#region --- 状态管理 ---

var _active_statuses: Dictionary = {} ## Key: status_id (StringName), Value: SkillStatusData (运行时实例!)

## 当状态效果被应用到角色身上时发出
signal status_applied_to_character(character: Character, status_instance: SkillStatusData)							
## 当状态效果从角色身上移除时发出
signal status_removed_from_character(character: Character, status_id: StringName, status_instance_data_before_removal: SkillStatusData)
## 当状态效果更新时发出 (例如 stacks 或 duration 变化)
signal status_updated_on_character(character: Character, status_instance: SkillStatusData, old_stacks: int, old_duration: int)

## 添加状态效果到角色身上 (由 ApplyStatusProcessor 调用)
## [param effect_data_from_skill] 是那个类型为STATUS的SkillEffectData，用于获取duration_override等
func apply_skill_status(status_template: SkillStatusData, p_source_char: Character, effect_data_from_skill: SkillEffectData) -> Dictionary:
	if not is_instance_valid(status_template):
		return {"applied_successfully": false, "reason": "invalid_status_template"}
	
	var status_id : StringName = status_template.status_id
	var result_info : Dictionary = {"applied_successfully": false, "reason": "unknown", "status_instance": null}

	# 1. 抵抗检查
	if _check_status_resistance(status_template, result_info):
		return result_info

	# 2. 覆盖逻辑
	_handle_status_override(status_template)

	# 3. 获取效果数据参数
	var duration_override = effect_data_from_skill.status_duration_override if is_instance_valid(effect_data_from_skill) else -1
	var stacks_to_apply_from_effect = effect_data_from_skill.status_stacks_to_apply if is_instance_valid(effect_data_from_skill) else 1

	# 4. 处理状态应用逻辑
	var runtime_status_instance: SkillStatusData
	if _active_statuses.has(status_id): # 已存在同ID状态，处理叠加
		runtime_status_instance = _update_existing_status(
			status_template, 
			p_source_char, 
			duration_override, 
			stacks_to_apply_from_effect, 
			result_info
		)
	else: # 全新状态添加
		runtime_status_instance = _apply_new_status(
			status_template, 
			p_source_char, 
			duration_override, 
			stacks_to_apply_from_effect, 
			result_info
		)
		if not runtime_status_instance:
			return result_info

	result_info.status_instance = runtime_status_instance
	return result_info

## 移除状态效果
## [param status_id] 要移除的状态ID
## [param trigger_end_effects] 是否触发结束效果
## [return] 是否成功移除状态
func remove_skill_status(status_id: StringName, trigger_end_effects: bool = true) -> bool:
	if not _active_statuses.has(status_id): return false
	var runtime_status_instance: SkillStatusData = _active_statuses[status_id]
	_active_statuses.erase(status_id)
	_apply_attribute_modifiers_for_status(runtime_status_instance, false)
	status_removed_from_character.emit(self, status_id, runtime_status_instance) 

	var end_effects = runtime_status_instance.end_effects
	if trigger_end_effects and not end_effects.is_empty():
		var bm_ref : BattleManager = get_battle_manager_reference()
		if bm_ref:
			var effect_source = runtime_status_instance.source_char if is_instance_valid(runtime_status_instance.source_char) else self
			await bm_ref.apply_effects(end_effects, effect_source, [self])
	return true

## 检查状态是否被抵抗
## 遍历当前所有活动状态，检查是否有状态抵抗新状态的添加
## [param status_template] 要添加的状态模板
## [param result_info] 返回结果字典，用于填充抵抗原因
## [return] 如果被抵抗返回 true，否则返回 false
func _check_status_resistance(status_template: SkillStatusData, result_info: Dictionary) -> bool:
	for active_status_instance: SkillStatusData in _active_statuses.values():
		if status_template.is_countered_by(active_status_instance.status_id):
			result_info.reason = "resisted_by_status_%s" % active_status_instance.status_id
			return true
	return false

## 处理状态覆盖逻辑
## 如果新状态可以覆盖其他状态，则先移除那些被覆盖的状态
## [param status_template] 要添加的状态模板
func _handle_status_override(status_template: SkillStatusData) -> void:
	if not status_template.overrides_states.is_empty():
		var ids_to_remove_due_to_override: Array[StringName] = []
		for id_to_override in status_template.overrides_states:
			if _active_statuses.has(id_to_override):
				ids_to_remove_due_to_override.append(id_to_override)
		for id_rem in ids_to_remove_due_to_override:
			remove_skill_status(id_rem, true) # 移除被覆盖的状态，并触发结束效果

## 更新已存在的状态
## 处理状态的各种叠加行为，如刷新持续时间、增加层数等
## [param status_template] 状态模板
## [param p_source_char] 状态来源角色
## [param duration_override] 持续时间覆盖
## [param stacks_to_apply] 要应用的层数
## [param result_info] 结果信息字典
## [return] 更新后的状态实例
func _update_existing_status(status_template: SkillStatusData, p_source_char: Character, 
		duration_override: int, stacks_to_apply: int, result_info: Dictionary) -> SkillStatusData:
	var status_id: StringName = status_template.status_id
	var runtime_status_instance: SkillStatusData = _active_statuses[status_id]
	var old_stacks: int = runtime_status_instance.stacks
	var old_duration: int = runtime_status_instance.left_duration
	
	runtime_status_instance.source_char = p_source_char
	var new_duration_base = duration_override if duration_override > -1 else status_template.duration
	var new_stack_count = runtime_status_instance.stacks

	# 根据不同的堆叠行为处理状态
	match status_template.stack_behavior:
		SkillStatusData.StackBehavior.NO_STACK:
			runtime_status_instance.left_duration = new_duration_base
			result_info.reason = "no_stack_refreshed"
		SkillStatusData.StackBehavior.REFRESH_DURATION:
			runtime_status_instance.left_duration = new_duration_base
			result_info.reason = "duration_refreshed"
		SkillStatusData.StackBehavior.ADD_DURATION:
			runtime_status_instance.left_duration += new_duration_base
			result_info.reason = "duration_added"
		SkillStatusData.StackBehavior.ADD_STACKS_REFRESH_DURATION:
			new_stack_count = min(old_stacks + stacks_to_apply, status_template.max_stacks)
			runtime_status_instance.left_duration = new_duration_base
			result_info.reason = "stacked_duration_refreshed"
		SkillStatusData.StackBehavior.ADD_STACKS_INDEPENDENT_DURATION:
			new_stack_count = min(old_stacks + stacks_to_apply, status_template.max_stacks)
			runtime_status_instance.left_duration = max(runtime_status_instance.left_duration, new_duration_base)
			result_info.reason = "stacked_independent_simplified"
	
	# 如果层数变化，需要重新应用属性修改器
	if runtime_status_instance.stacks != new_stack_count:
		_apply_attribute_modifiers_for_status(runtime_status_instance, false) # 先移除旧修改器
		runtime_status_instance.stacks = new_stack_count
		_apply_attribute_modifiers_for_status(runtime_status_instance) # 再应用新修改器
	
	result_info.applied_successfully = true
	
	# 如果状态有变化，发出信号
	if old_stacks != runtime_status_instance.stacks or old_duration != runtime_status_instance.left_duration:
		status_updated_on_character.emit(self, runtime_status_instance, old_stacks, old_duration)
	
	return runtime_status_instance

## 应用全新的状态
## 当角色不存在该状态时，创建新的状态实例并应用
## [param status_template] 状态模板
## [param p_source_char] 状态来源角色
## [param duration_override] 持续时间覆盖
## [param stacks_to_apply] 要应用的层数
## [param result_info] 结果信息字典
## [return] 创建的状态实例，如果失败则返回 null
func _apply_new_status(status_template: SkillStatusData, p_source_char: Character, 
		duration_override: int, stacks_to_apply: int, result_info: Dictionary) -> SkillStatusData:
	# 创建新的状态实例
	var runtime_status_instance = status_template.duplicate(true) as SkillStatusData
	if not runtime_status_instance:
		result_info.reason = "failed_to_duplicate_status_template"
		return null
	
	# 设置状态属性
	runtime_status_instance.source_char = p_source_char
	runtime_status_instance.target_char = self
	runtime_status_instance.left_duration = duration_override if duration_override > -1 else status_template.duration
	runtime_status_instance.stacks = clamp(stacks_to_apply, 1, status_template.max_stacks)
	
	# 将状态添加到活动状态字典中
	_active_statuses[status_template.status_id] = runtime_status_instance
	
	# 应用属性修改器
	_apply_attribute_modifiers_for_status(runtime_status_instance)
	
	# 设置结果信息并发出信号
	result_info.reason = "newly_applied"
	result_info.applied_successfully = true
	status_applied_to_character.emit(self, runtime_status_instance)
	
	return runtime_status_instance

## 应用/移除一个状态实例的属性修改器
## [param runtime_status_inst] 要应用的技能状态实例
## [param add] 是否添加修改器，否则移除
func _apply_attribute_modifiers_for_status(runtime_status_inst: SkillStatusData, add: bool = true) -> void:
	if not active_attribute_set or not is_instance_valid(runtime_status_inst): return
	if runtime_status_inst.attribute_modifiers.is_empty(): return

	for modifier_template: SkillAttributeModifier in runtime_status_inst.attribute_modifiers:
		var mod_instance: SkillAttributeModifier = modifier_template.duplicate(true)
		mod_instance.magnitude *= runtime_status_inst.stacks
		var attr_to_modify: StringName = mod_instance.attribute_id
		if not active_attribute_set.get_attribute(attr_to_modify): # 确保角色有此属性
			push_warning("Character '%s' AttributeSet does not have attribute '%s' for modifier from status '%s'." % [character_name, attr_to_modify, runtime_status_inst.status_id])
			continue
		if add:
			active_attribute_set.apply_modifier(mod_instance, runtime_status_inst.get_instance_id())
		else:
			# 移除时，需要能够精确移除或按来源ID移除
			active_attribute_set.remove_modifiers_by_source_id(runtime_status_inst.get_instance_id())

## 由 BattleManager 在回合结束时调用
func process_active_statuses(p_battle_manager_ref): 
	if not is_alive: return 
	var status_ids_to_process = _active_statuses.keys().duplicate() 
	var expired_status_ids: Array[StringName] = []

	for status_id in status_ids_to_process: 
		if not _active_statuses.has(status_id) or not is_alive: continue
		var status_instance: SkillStatusData = _active_statuses[status_id]
		if not status_instance.ongoing_effects.is_empty():
			var effect_source = status_instance.source_char if is_instance_valid(status_instance.source_char) else self
			await p_battle_manager_ref.apply_effects(status_instance.ongoing_effects, effect_source, [self])
		if not is_alive: break 
	
	if not is_alive: return

	status_ids_to_process = _active_statuses.keys().duplicate() 
	for status_id in status_ids_to_process: 
		if not _active_statuses.has(status_id): continue
		var status_instance: SkillStatusData = _active_statuses[status_id]
		if status_instance.duration_type == SkillStatusData.DurationType.TURNS:
			if status_instance.left_duration > 0: 
				status_instance.left_duration -= 1
			if status_instance.left_duration <= 0: 
				expired_status_ids.append(status_id)
			
	for expired_id in expired_status_ids: 
		if _active_statuses.has(expired_id): 
			await remove_skill_status(expired_id, true)

## 获取 BattleManager 引用
## [return] BattleManager 引用
func get_battle_manager_reference() -> BattleManager: # 确保此方法在Character.gd中定义
	var bm_node = get_tree().current_scene.find_child("BattleManager", true, false) 
	return bm_node if bm_node is BattleManager else null

## 获取所有活动状态的运行时实例
## [return] 所有活动状态的运行时实例数组
func get_all_active_status_instances_for_check() -> Array[SkillStatusData]:
	return _active_statuses.values()

## MP检查
func can_cast_skill(skill_data: SkillData) -> bool: # 由BattleManager调用
	if not is_instance_valid(skill_data): return false
	return current_mp >= skill_data.mp_cost # current_mp getter 依赖 active_attribute_set

## MP扣减
func deduct_mp_for_skill(source_skill: SkillData): # 由BattleManager调用
	var amount := source_skill.mp_cost
	if amount > 0 and is_instance_valid(active_attribute_set): 
		var mp_attr_name = &"CurrentMana"
		var old_mp = active_attribute_set.get_current_value(mp_attr_name)
		# 通过AttributeSet修改MP，以便触发信号和钩子
		active_attribute_set.set_current_value(mp_attr_name, old_mp - amount, source_skill)

## 获取角色身上所有状态限制的行动类别 (供 BattleManager.can_perform_action 使用)
func get_combined_restricted_action_categories() -> Array[StringName]:
	var all_restrictions: Array[StringName] = []
	for status_instance: SkillStatusData in _active_statuses.values():
		all_restrictions.append_array(status_instance.restricted_action_categories)
	# 可以去重，如果需要
	var unique_restrictions = []
	for restriction in all_restrictions:
		if not unique_restrictions.has(restriction):
			unique_restrictions.append(restriction)
	return unique_restrictions
#endregion
