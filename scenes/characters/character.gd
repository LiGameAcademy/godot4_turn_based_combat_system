extends Node2D
class_name Character

@export var character_data: CharacterData

#region --- 引用场景中的节点 ---
@onready var hp_bar : ProgressBar = %HPBar
@onready var hp_label := %HPLabel
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_label: Label = %MPLabel
@onready var name_label := $Container/NameLabel
@onready var character_rect := $Container/CharacterRect
@onready var defense_indicator : DefenseIndicator = $DefenseIndicator
# 组件引用
@onready var combat_component: = $CombatComponent
@onready var skill_component : SkillComponent = $SkillComponent
#endregion

#region --- 常用属性的便捷Getter
var current_hp: float:
	get:
		return skill_component.get_calculated_attribute(&"CurrentHealth") if is_instance_valid(skill_component) else 0.0
var max_hp: float:
	get:
		return skill_component.get_calculated_attribute(&"MaxHealth") if is_instance_valid(skill_component) else 0.0
var current_mp: float:
	get:
		return skill_component.get_calculated_attribute(&"CurrentMana") if is_instance_valid(skill_component) else 0.0
var max_mp: float:
	get:
		return skill_component.get_calculated_attribute(&"MaxMana") if is_instance_valid(skill_component) else 0.0
var attack: float:
	get:
		return skill_component.get_calculated_attribute(&"AttackPower") if is_instance_valid(skill_component) else 0.0
var defense: float:
	get:
		return skill_component.get_calculated_attribute(&"DefensePower") if is_instance_valid(skill_component) else 0.0
var speed: float:
	get:
		return skill_component.get_calculated_attribute(&"Speed") if is_instance_valid(skill_component) else 0.0
var magic_attack: float:
	get:
		return skill_component.get_calculated_attribute(&"MagicAttack") if is_instance_valid(skill_component) else 0.0
var magic_defense: float:
	get:
		return skill_component.get_calculated_attribute(&"MagicDefense") if is_instance_valid(skill_component) else 0.0
var character_name: String:
	get: return character_data.character_name if character_data else "UnnamedCharacter"
## 元素类型
var element : int :
	get:
		return character_data.element
#endregion

#region --- 状态标记 ---
var is_defending: bool = false			## 防御状态标记
var is_alive: bool:
	get:
		return current_hp > 0
#endregion

# signal health_changed(new_hp: int, max_hp: int)
# signal mana_changed(new_mp: int, max_mp: int)
# signal character_died()

signal character_defeated(source: Variant)										## 角色被击败
signal display_health_changed(current_value: float, max_value: float)			## 显示血量变化
signal display_mana_changed(current_value: float, max_value: float)				## 显示法力变化

func _ready() -> void:
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")

	if defense_indicator:
		defense_indicator.hide()

	# 连接来自 SkillComponent 内部 AttributeSet 的信号
	if skill_component.attribute_set_instance:
		if not skill_component.attribute_set_instance.current_value_changed.is_connected(_on_attribute_current_value_changed):
			skill_component.attribute_set_instance.current_value_changed.connect(_on_attribute_current_value_changed)
		# 如果需要，也可以连接 base_value_changed
	else:
		push_error("SkillComponent for '%s' did not initialize its AttributeSet instance." % character_name)

	# 初始化UI显示
	_update_name_display()
	_update_health_display()
	_update_mana_display()

	if defense_indicator:
		defense_indicator.hide_indicator()

	print("Character '%s' initialized. HP: %.1f/%.1f" % [character_name, current_hp, max_hp])
	
## 初始化玩家数据
func initialize_from_data(data: CharacterData):
	# 保存数据引用
	character_data = data

	# 初始化组件
	skill_component.initialize(character_data)
	
	print(character_name + " 初始化完毕，HP: " + str(current_hp) + "/" + str(max_hp))

## 由battleManager在角色加入战斗时调用，注入
func initialize_battle_context(p_battle_manager: BattleManager) -> void:
	if is_instance_valid(skill_component):
		skill_component.set_skill_system_reference(p_battle_manager.skill_system)
	if is_instance_valid(combat_component):
		combat_component.set_battle_manager_reference(p_battle_manager)

#region --- 核心 HP/MP 修改 (通常由 CombatComponent 或 EffectProcessor 间接调用) ---
## 返回实际HP变化量 (负数为伤害,正数为治疗)
func modify_hp(amount: int, source: Variant = null) -> int:
	if not is_instance_valid(skill_component) or not skill_component.attribute_set_instance: return 0
	
	var ch_attr_name = &"CurrentHealth"
	var current_val = skill_component.attribute_set_instance.get_current_value(ch_attr_name)
	# AttributeSet 的 _pre_current_value_change (例如CurrentHealth钳制到MaxHealth) 会处理边界
	# AttributeSet 会发出 current_value_changed 信号, Character._on_attribute_current_value_changed 会响应
	skill_component.attribute_set_instance.set_current_value(ch_attr_name, current_val + amount, source)
	
	# 返回实际变化 (set_current_value可能因为钳制而不完全等于amount)
	var new_val = skill_component.attribute_set_instance.get_current_value(ch_attr_name)
	return int(round(new_val - current_val))

## 返回实际MP变化量
func modify_mp(amount: int, source: Variant = null) -> int:
	if not is_instance_valid(skill_component) or not skill_component.attribute_set_instance: return 0

	var cm_attr_name = &"CurrentMana"
	var current_val = skill_component.attribute_set_instance.get_current_value(cm_attr_name)
	skill_component.attribute_set_instance.set_current_value(cm_attr_name, current_val + amount, source)
	
	var new_val = skill_component.attribute_set_instance.get_current_value(cm_attr_name)
	return int(round(new_val - current_val))

## 供 SkillSystem 调用的便捷方法 (替代之前 SkillData.can_cast)
func check_mp_cost(cost: int) -> bool:
	return current_mp >= cost

## 供 SkillSystem 调用的便捷方法
func deduct_mp_for_skill(cost: int, skill_source: SkillData):
	modify_mp(-cost, skill_source)
#endregion

#region --- 供外部（如AI或BattleManager的execute_attack）调用的简单动作接口 ---
## 这些方法会通过 CombatComponent 路由，如果需要更复杂的行动判断
func simple_attack(target_character: Character):
	if is_instance_valid(combat_component) and combat_component.has_method("perform_basic_attack"):
		combat_component.perform_basic_attack(target_character)
	else:
		push_warning("Character %s cannot perform_basic_attack via CombatComponent." % character_name)

func simple_defend():
	if is_instance_valid(combat_component):
		combat_component.set_defending(true)
	else:
		push_warning("Character %s cannot set_defending via CombatComponent." % character_name)

# 供动画系统调用的方法 (示例)
# func play_animation(anim_name: StringName):
#    if animation_player: animation_player.play(anim_name)

#endregion

#region --- UI 更新辅助方法 ---
func _update_name_display():
	if name_label and character_data:
		name_label.text = character_data.character_name

func _update_health_display():
	if not hp_bar or not hp_label: return
	var ch = current_hp
	var mh = max_hp
	hp_bar.max_value = mh if mh > 0 else 1 # Avoid division by zero or negative max for ProgressBar
	hp_bar.value = ch
	hp_label.text = "HP: %d/%d" % [int(round(ch)), int(round(mh))]
	if mh > 0:
		var ratio = ch / mh
		if ratio <= 0.25: hp_bar.self_modulate = Color.RED
		elif ratio <= 0.5: hp_bar.self_modulate = Color.YELLOW
		else: hp_bar.self_modulate = Color.GREEN
	else:
		hp_bar.self_modulate = Color.GRAY
		hp_bar.value = 0 # Ensure bar is empty if max_hp is 0 or less
	display_health_changed.emit(ch, mh, self)

func _update_mana_display():
	if not mp_bar or not mp_label: return
	var cm = current_mp
	var mm = max_mp
	mp_bar.max_value = mm if mm > 0 else 1
	mp_bar.value = cm
	mp_label.text = "MP: %d/%d" % [int(round(cm)), int(round(mm))]
	display_mana_changed.emit(cm, mm, self)
#endregion

## 死亡处理方法
func _die(death_source: Variant = null) -> void:
	# is_alive 的getter会自动更新，但这里可以执行死亡动画、音效、移除出战斗等逻辑
	print_rich("[color=red][b]%s[/b] has been defeated by %s![/color]" % [character_data.character_name, death_source])
	character_defeated.emit(self)
	modulate = Color(0.5, 0.5, 0.5, 0.5) # 变灰示例, 表示被击败

#region --- 信号处理方法 ---

func _on_attribute_current_value_changed(attribute: SkillAttribute, old_value: int, new_value: int, source: Variant) -> void:
	print_rich("[b]%s[/b]'s [color=yellow]%s[/color] changed from [color=red]%.1f[/color] to [color=green]%.1f[/color] (Source: %s)" % [character_data.character_name, attribute.display_name, old_value, new_value, source])
	
	if attribute.attribute_name == &"CurrentHealth":
		_update_health_display()
		if new_value <= 0.0 and old_value > 0.0: # 从存活到死亡
			_die(source)
	elif attribute.attribute_name == &"MaxHealth":
		# MaxHealth变化也需要通知UI更新，并可能影响CurrentHealth的钳制（已在AttributeSet钩子中处理）
		_update_health_display()
	elif attribute.attribute_name == &"CurrentMana":
		_update_mana_display()
	elif attribute.attribute_name == &"MaxMana":
		_update_mana_display()

func _on_attribute_base_value_changed(attribute: SkillAttribute, _old_value: int, _new_value: int, _source: Variant) -> void:
	print_rich("[b]%s[/b]'s [color=yellow]%s (Base)[/color] changed from [color=red]%.1f[/color] to [color=green]%.1f[/color] (Source: %s)" % [character_data.character_name, attribute.display_name, _old_value, _new_value, _source])
	# 通常基础值变化也会导致当前值变化，相关信号已在_on_attribute_current_value_changed处理
	# 但如果UI需要特别区分显示基础值和当前值，可以在这里做处理
	if attribute.attribute_name == &"MaxHealth": # 例如基础MaxHealth变化
		_update_health_display() # 确保UI同步
	
#endregion
