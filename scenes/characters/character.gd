extends Node2D
class_name Character

#region --- 引用场景中的节点 ---
@onready var hp_bar : ProgressBar = %HPBar
@onready var hp_label := %HPLabel
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_label: Label = %MPLabel
@onready var name_label := $Container/NameLabel
@onready var character_rect := $Container/CharacterRect
@onready var defense_indicator : DefenseIndicator = $DefenseIndicator
@onready var combat_manager: CombatComponent = $CombatComponent
#endregion
@export var character_data: CharacterData
var active_attribute_set: SkillAttributeSet = null			## 持有当前活动的AttributeSet实例

#region --- 常用属性的便捷Getter
var current_hp: float:
	get:
		return active_attribute_set.get_current_value("CurrentHealth")
var max_hp: float:
	get:
		return active_attribute_set.get_current_value("MaxHealth")
var current_mp: float:
	get:
		return active_attribute_set.get_current_value("CurrentMana")
var max_mp: float:
	get:
		return active_attribute_set.get_current_value("MaxMana")
var attack: float:
	get:
		return active_attribute_set.get_current_value("AttackPower")
var defense: float:
	get:
		return active_attribute_set.get_current_value("DefensePower")
var speed: float:
	get:
		return active_attribute_set.get_current_value("Speed")
var magic_attack: float:
	get:
		return active_attribute_set.get_current_value("MagicAttack")
var magic_defense: float:
	get:
		return active_attribute_set.get_current_value("MagicDefense")
#endregion

#region --- 状态标记 ---
var character_name: String
var is_defending: bool = false			## 防御状态标记
var is_alive: bool:
	get:
		return current_hp > 0 if active_attribute_set else false
## 元素类型
var element : int :
	get:
		return character_data.element
#endregion

signal health_changed(new_hp: int, max_hp: int)
signal mana_changed(new_mp: int, max_mp: int)
signal character_died()

func _ready() -> void:
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")

	if defense_indicator:
		defense_indicator.hide()

	# 链接AttributeSet到Character
	active_attribute_set.current_value_changed.connect(_on_attribute_current_value_changed)
	active_attribute_set.base_value_changed.connect(_on_attribute_base_value_changed)

	# 初始化UI显示
	_update_name_display()
	_update_health_display()
	# _update_mana_display()

	print("%s initialized. HP: %.1f/%.1f, Attack: %.1f" % [character_data.character_name, current_hp, max_hp, attack])
	
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
	
	print(character_name + " 初始化完毕，HP: " + str(current_hp) + "/" + str(max_hp))

## 更新显示
func update_visual():
	if name_label:
		name_label.text = character_name
	
	if hp_label:
		hp_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)
	
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

	active_attribute_set.set_current_value("CurrentHealth", active_attribute_set.get_current_value("CurrentHealth") - final_damage)
	return final_damage

func heal(amount: int) -> int:
	active_attribute_set.set_current_value("CurrentHealth", active_attribute_set.get_current_value("CurrentHealth") + amount)
	return amount

func use_mp(amount: int) -> bool:
	if active_attribute_set.get_current_value("CurrentMana") >= amount:
		active_attribute_set.set_current_value("CurrentMana", active_attribute_set.get_current_value("CurrentMana") - amount)
		return true
	return false

## 回合开始时重置标记
func reset_turn_flags() -> void:
	set_defending(false)
	# 这里可以添加其他需要在回合开始时重置的标记

## 是否足够释放技能MP
func has_enough_mp_for_any_skill() -> bool:
	for skill in character_data.skills:
		if active_attribute_set.get_current_value("CurrentMana") >= skill.mp_cost:
			return true
	return false

# 以下是代理方法，将调用转发给CombatManager

## 执行技能
func execute_skill(skill_data, targets: Array) -> Array:
	return combat_manager.execute_skill(skill_data, targets)

## 添加状态
func add_status(status, source: Character = null):
	return combat_manager.add_status(status, source)

## 移除状态
func remove_status(status_id: String) -> void:
	combat_manager.remove_status(status_id)

## 获取状态
func get_status_by_id(status_id: String):
	return combat_manager.get_status_by_id(status_id)

## 获取状态来源
func get_status_source(status_id: String) -> Character:
	return combat_manager.get_status_source(status_id)

## 获取所有状态
func get_all_statuses() -> Array:
	return combat_manager.get_all_statuses()

## 获取所有状态及其来源
func get_all_statuses_with_sources() -> Array:
	return combat_manager.get_all_statuses_with_sources()

## 更新状态持续时间
func update_statuses_duration() -> void:
	combat_manager.update_statuses_duration()

## 检查是否有指定状态
func has_status(status_id: String) -> bool:
	return combat_manager.has_status(status_id)

## 应用控制效果
func apply_control_effect(control_type: String, duration: int):
	combat_manager.apply_control_effect(control_type, duration)

## 检查是否有特定控制效果
func has_control_effect(control_type: String) -> bool:
	return combat_manager.has_control_effect(control_type)

## 获取所有控制效果
func get_all_control_effects() -> Dictionary:
	return combat_manager.get_all_control_effects()

## 移除控制效果
func remove_control_effect(control_type: String):
	combat_manager.remove_control_effect(control_type)

## 检查是否可以行动
func can_act() -> bool:
	return combat_manager.can_act()

## 处理回合结束时的控制效果
func process_control_effects_end_turn():
	combat_manager.process_control_effects_end_turn()

## 处理回合结束时的状态效果
func process_status_effects_end_of_round() -> void:
	combat_manager.process_status_effects_end_of_round()

#region --- UI 更新辅助方法 ---
func _update_name_display():
	if name_label and character_data:
		name_label.text = character_data.character_name

func _update_health_display():
	if not hp_bar:
		return
	if not active_attribute_set:
		return
	
	var current_val = active_attribute_set.get_current_value(&"CurrentHealth")
	var max_val = active_attribute_set.get_current_value(&"MaxHealth")
	hp_bar.max_value = max_val
	hp_bar.value = current_val
	hp_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)
	# 根据血条百分比改变颜色
	if hp_bar.ratio <= 0.25:
		hp_bar.self_modulate = Color.RED
	elif hp_bar.ratio <= 0.5:
		hp_bar.self_modulate = Color.YELLOW
	else:
		hp_bar.self_modulate = Color.GREEN
	
func _update_mana_display():
	if not mp_bar:
		return
	if not active_attribute_set:
		return
	
	var current_val = active_attribute_set.get_current_value(&"CurrentMana")
	var max_val = active_attribute_set.get_current_value(&"MaxMana")
	mp_bar.max_value = max_val
	mp_bar.value = current_val
	mp_label.text = "MP: " + str(current_mp) + "/" + str(max_mp)
#endregion

## 死亡处理方法
func _die(death_source: Variant = null) -> void:
	# is_alive 的getter会自动更新，但这里可以执行死亡动画、音效、移除出战斗等逻辑
	print_rich("[color=red][b]%s[/b] has been defeated by %s![/color]" % [character_data.character_name, death_source])
	character_died.emit(self)
	modulate = Color(0.5, 0.5, 0.5, 0.5) # 变灰示例, 表示被击败

#region --- 信号处理方法 ---

func _on_attribute_current_value_changed(attribute: SkillAttribute, old_value: int, new_value: int, source: Variant) -> void:
	print_rich("[b]%s[/b]'s [color=yellow]%s[/color] changed from [color=red]%.1f[/color] to [color=green]%.1f[/color] (Source: %s)" % [character_data.character_name, attribute.display_name, old_value, new_value, source])
	
	if attribute.attribute_name == &"CurrentHealth":
		health_changed.emit(new_value, max_hp, self)
		_update_health_display()
		if new_value <= 0.0 and old_value > 0.0: # 从存活到死亡
			_die(source)
	elif attribute.attribute_name == &"MaxHealth":
		# MaxHealth变化也需要通知UI更新，并可能影响CurrentHealth的钳制（已在AttributeSet钩子中处理）
		health_changed.emit(current_hp, new_value, self)
		_update_health_display()
	elif attribute.attribute_name == &"CurrentMana":
		mana_changed.emit(new_value, max_mp, self)
		_update_mana_display()
	elif attribute.attribute_name == &"MaxMana":
		mana_changed.emit(current_mp, new_value, self)
		_update_mana_display()

func _on_attribute_base_value_changed(attribute: SkillAttribute, _old_value: int, _new_value: int, _source: Variant) -> void:
	print_rich("[b]%s[/b]'s [color=yellow]%s (Base)[/color] changed from [color=red]%.1f[/color] to [color=green]%.1f[/color] (Source: %s)" % [character_data.character_name, attribute.display_name, _old_value, _new_value, _source])
	# 通常基础值变化也会导致当前值变化，相关信号已在_on_attribute_current_value_changed处理
	# 但如果UI需要特别区分显示基础值和当前值，可以在这里做处理
	if attribute.attribute_name == &"MaxHealth": # 例如基础MaxHealth变化
		_update_health_display() # 确保UI同步
	
#endregion
