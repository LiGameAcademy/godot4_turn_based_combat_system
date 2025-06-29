extends Node2D
class_name Character

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

# 引用场景中的节点
@onready var hp_bar : ProgressBar = %HPBar
@onready var hp_label := %HPLabel
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_label: Label = %MPLabel
@onready var name_label := $Container/NameLabel
@onready var character_rect := $Container/CharacterRect
@onready var defense_indicator : DefenseIndicator = $DefenseIndicator
# 组件引用
@onready var combat_component: CharacterCombatComponent = %CharacterCombatComponent
@onready var skill_component: CharacterSkillComponent = %CharacterSkillComponent

#region --- 常用属性的便捷Getter ---
var current_hp: float:
	get: return skill_component.get_attribute_current_value(&"CurrentHealth") if skill_component else 0.0
	set(value): assert(false, "cannot set current_hp")
var max_hp: float:
	get: return skill_component.get_attribute_current_value(&"MaxHealth") if skill_component else 0.0
	set(value): assert(false, "cannot set max_hp")
var current_mp: float:
	get: return skill_component.get_attribute_current_value(&"CurrentMana") if skill_component else 0.0
	set(value): assert(false, "cannot set current_mp")
var max_mp: float:
	get: return skill_component.get_attribute_current_value(&"MaxMana") if skill_component else 0.0
	set(value): assert(false, "cannot set max_mp")
var attack_power: float:
	get: return skill_component.get_attribute_current_value(&"AttackPower") if skill_component else 0.0
	set(value): assert(false, "cannot set attack_power")
var defense_power: float:
	get: return skill_component.get_attribute_current_value(&"DefensePower") if skill_component else 0.0
	set(value): assert(false, "cannot set defense_power")
var speed: float:
	get: return skill_component.get_attribute_current_value(&"Speed") if skill_component else 0.0
	set(value): assert(false, "cannot set speed")
var magic_attack : float:
	get: return skill_component.get_attribute_current_value(&"MagicAttack") if skill_component else 0.0
	set(value): assert(false, "cannot set magic_attack")
var magic_defense : float:
	get: return skill_component.get_attribute_current_value(&"MagicDefense") if skill_component else 0.0
	set(value): assert(false, "cannot set magic_defense")
var character_name : StringName:
	get: return character_data.character_name if character_data else "" 
	set(value): assert(false, "cannot set character_name")
#endregion

@export var character_data: CharacterData

# 属性委托给战斗组件
var is_defending: bool:
	get: return combat_component.is_defending if combat_component else false
var is_alive : bool = true:							## 生存状态标记
	get: return current_hp > 0
var element: int:
	get : return combat_component.element

# 信号 - 这些信号将转发组件的信号
signal character_defeated
signal health_changed(current_hp: float, max_hp: float, character: Character)
signal mana_changed(current_mp: float, max_mp: float, character: Character)
signal status_applied_to_character(character: Character, status_instance: SkillStatusData)
signal status_removed_from_character(character: Character, status_id: StringName, status_instance_data_before_removal: SkillStatusData)
signal status_updated_on_character(character: Character, status_instance: SkillStatusData, old_stacks: int, old_duration: int)

func _ready():
	if character_data:
		_initialize_from_data(character_data)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")
	# 初始化组件
	_init_components()

	# 初始化UI显示
	_update_name_display()
	_update_health_display()
	_update_mana_display()

	print("%s initialized. HP: %.1f/%.1f, Attack: %.1f" % [character_data.character_name, current_hp, max_hp, attack_power])

## 玩家选择行动
func execute_action(action_type: CharacterCombatComponent.ActionType, target: Character = null, params: Dictionary = {}) -> void:
	if not combat_component:
		return
	combat_component.execute_action(action_type, target, params)

## 生成伤害数字
func spawn_damage_number(amount: float, color : Color, prefix : String = "") -> void:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -50)
	damage_number.show_damage(amount, false, color, prefix)

## 更新显示
func update_visual() -> void:
	if name_label:
		name_label.text = character_name
	
	if character_rect and character_data:
		character_rect.color = character_data.color

## 伤害处理方法
func take_damage(base_damage: float) -> float:
	if not combat_component:
		return 0.0
	var result = combat_component.take_damage(base_damage)
	spawn_damage_number(result, Color.RED)
	return result

func heal(amount: float) -> float:
	if not combat_component:
		return 0.0
	var result = combat_component.heal(amount)
	spawn_damage_number(result, Color.GREEN)
	return result

func on_turn_start(battle_manager : BattleManager) -> void:
	if combat_component:
		combat_component.on_turn_start(battle_manager)

func on_turn_end(battle_manager : BattleManager) -> void:
	if combat_component:
		combat_component.on_turn_end(battle_manager)

## 是否足够释放技能MP
func has_enough_mp_for_any_skill() -> bool:
	if skill_component:
		return skill_component.has_enough_mp_for_any_skill()
	return false

## 检查是否有足够的MP使用指定技能
func has_enough_mp_for_skill(skill: SkillData) -> bool:
	if skill_component:
		return skill_component.has_enough_mp_for_skill(skill)
	return false

## 使用MP
func use_mp(amount: float) -> bool:
	if skill_component:
		return skill_component.use_mp(amount)
	return false

## 恢复MP
func restore_mp(amount: float) -> float:
	if skill_component:
		return skill_component.restore_mp(amount)
	return 0.0

## 播放动画
func play_animation(animation_name: String) -> void:
	print("假装播放了动画：", animation_name)

func apply_skill_status(status_instance: SkillStatusData, source_character: Character, effect_data_from_skill: SkillEffectData) -> Dictionary:
	if skill_component:
		return skill_component.apply_status(status_instance, source_character, effect_data_from_skill)
	return {"applied_successfully": false, "reason": "invalid_status_template"}

## 初始化组件
func _init_components() -> void:
	if not combat_component:
		push_error("战斗组件未初始化！")
		return
	if not skill_component:
		push_error("技能组件未初始化！")
		return
	
	combat_component.initialize(character_data.element, character_data.attack_skill)

	# 连接组件信号
	combat_component.defending_changed.connect(_on_defending_changed)
	combat_component.character_defeated.connect(_on_character_defeated)

	skill_component.status_applied.connect(func(character, status_instance): 
		status_applied_to_character.emit(character, status_instance))
		
	skill_component.status_removed.connect(func(character, status_id, status_instance): 
		status_removed_from_character.emit(character, status_id, status_instance))
		
	skill_component.status_updated.connect(func(character, status_instance, old_stacks, old_duration): 
		status_updated_on_character.emit(character, status_instance, old_stacks, old_duration))

	skill_component.attribute_base_value_changed.connect(_on_attribute_base_value_changed)
	skill_component.attribute_current_value_changed.connect(_on_attribute_current_value_changed)

## 初始化玩家数据
func _initialize_from_data(data: CharacterData):
	# 保存数据引用
	character_data = data
	
	skill_component.initialize(character_data.attribute_set_resource, character_data.skills.duplicate(true))
	print(character_name + " 初始化完毕，HP: " + str(current_hp) + "/" + str(max_hp))
	
	# 初始化组件
	_init_components()

#region --- UI 更新辅助方法 ---
func _update_name_display() -> void:
	if name_label and character_data:
		name_label.text = character_data.character_name

func _update_health_display() -> void:
	if hp_bar and skill_component: # 确保active_attribute_set已初始化
		var current_val = skill_component.get_attribute_current_value(&"CurrentHealth")
		var max_val = skill_component.get_attribute_current_value(&"MaxHealth")
		hp_bar.max_value = max_val
		hp_bar.value = current_val
		hp_label.text = "%d/%d" % [roundi(current_val), roundi(max_val)]

func _update_mana_display() -> void:
	if mp_bar and skill_component: # 确保active_attribute_set已初始化
		var current_val = skill_component.get_attribute_current_value(&"CurrentMana")
		var max_val = skill_component.get_attribute_current_value(&"MaxMana")
		mp_bar.max_value = max_val
		mp_bar.value = current_val
		mp_label.text = "%d/%d" % [roundi(current_val), roundi(max_val)]

#endregion

#region --- 信号处理 ---
## 当AttributeSet中的属性当前值变化时调用
func _on_attribute_current_value_changed(
		attribute_instance: SkillAttribute, _old_value: float, new_value: float) -> void:
	if attribute_instance.attribute_name == &"CurrentHealth":
		health_changed.emit(new_value, max_hp, self)
		_update_health_display()
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
	
func _on_defending_changed(value: bool):
	if not defense_indicator:
		return
	if value:
		defense_indicator.show_indicator()
	else:
		defense_indicator.hide_indicator()

func _on_character_defeated():
	if defense_indicator:
		defense_indicator.hide_indicator()
	modulate = Color(0.5, 0.5, 0.5, 0.5) # 变灰示例
	character_defeated.emit()

#endregion
