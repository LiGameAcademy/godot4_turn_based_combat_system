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
