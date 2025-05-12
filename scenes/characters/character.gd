extends Node2D
class_name Character

@export var character_data: CharacterData

# 运行时从CharacterData初始化的核心战斗属性
var character_name: String
var current_hp: int
var max_hp: int
var current_mp: int:
	set(value):
		current_mp = value
		mp_bar.value = value
		mp_label.text = "MP: " + str(value) + "/" + str(max_mp)
var max_mp: int:
	set(value):
		max_mp = value
		mp_bar.max_value = value
		mp_label.text = "MP: " + str(current_mp) + "/" + str(value)
var attack: int
var defense: int
var speed: int
var magic_attack: int = 0  # 魔法攻击力
var magic_defense: int = 0 # 魔法防御力

## 元素类型
var element : int :
	get:
		return character_data.element

# 引用场景中的节点
@onready var hp_bar : ProgressBar = %HPBar
@onready var hp_label := %HPLabel
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_label: Label = %MPLabel
@onready var name_label := $Container/NameLabel
@onready var character_rect := $Container/CharacterRect
@onready var defense_indicator : DefenseIndicator = $DefenseIndicator

var is_defending: bool = false			## 防御状态标记

signal hp_changed(new_hp: int, max_hp: int)
signal character_died()

# 状态效果相关
var active_status_effects: Array = []  # Array[StatusEffect]
signal status_effect_added(effect)
signal status_effect_removed(effect)
signal status_effect_updated(effect)

# 控制效果相关
var control_effects = {}  # 字典，键为控制类型，值为持续回合数
signal control_effect_applied(control_type, duration)
signal control_effect_removed(control_type)
signal control_effect_changed(character)

func _ready():
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")

	if !hp_changed.is_connected(_on_hp_changed):
		hp_changed.connect(_on_hp_changed)
	
	# 初始化HP条
	_on_hp_changed(current_hp, max_hp)

	if defense_indicator:
		defense_indicator.hide()

## 初始化玩家数据
func initialize_from_data(data: CharacterData):
	# 保存数据引用
	self.character_data = data
	
	# 初始化属性
	character_name = data.character_name
	max_hp = data.max_hp
	current_hp = data.current_hp
	max_mp = data.max_mp
	current_mp = data.current_mp
	attack = data.attack
	defense = data.defense
	speed = data.speed
	magic_attack = data.magic_attack
	magic_defense = data.magic_defense
	
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
func take_damage(base_damage: int) -> int:
	var final_damage: int = base_damage

	# 如果处于防御状态，则减免伤害
	if is_defending:
		final_damage = round(final_damage * 0.5)
		print(character_name + " 正在防御，伤害减半！")
		set_defending(false)	# 防御效果通常在受到一次攻击后解除
	
	final_damage = max(1, final_damage)	# 保证至少1点伤害

	current_hp = max(0, current_hp - final_damage)

	hp_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		die()
	
	return final_damage

func heal(amount: int) -> int:
	current_hp = min(max_hp, current_hp + amount)
	update_visual()
	print(character_name + " 恢复 " + str(amount) + " 点HP, 剩余HP: " + str(current_hp))
	return amount

func use_mp(amount: int) -> bool:
	if current_mp >= amount:
		current_mp -= amount
		update_visual()
		return true
	return false

## 死亡处理方法
func die() -> void:
	print(character_name + " 已被击败!")
	# 在完整游戏中会添加死亡动画和事件
	character_died.emit()
	modulate = Color(1, 1, 1, 0.5) # 半透明表示被击败

## 是否存活
func is_alive() -> bool:
	return current_hp > 0

## 回合开始时重置标记
func reset_turn_flags() -> void:
	set_defending(false)
	# 这里可以添加其他需要在回合开始时重置的标记

## 是否足够释放技能MP
func has_enough_mp_for_any_skill() -> bool:
	for skill in character_data.skills:
		if current_mp >= skill.mp_cost:
			return true
	return false

func _on_hp_changed(new_hp : int, maximum_hp: int) -> void:
	if not hp_bar:
		return
	hp_bar.max_value = maximum_hp
	hp_bar.value = new_hp
	hp_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)
	# 根据血条百分比改变颜色
	if hp_bar.ratio <= 0.25:
		hp_bar.self_modulate = Color.RED
	elif hp_bar.ratio <= 0.5:
		hp_bar.self_modulate = Color.YELLOW
	else:
		hp_bar.self_modulate = Color.GREEN

# 添加状态效果
func add_status_effect(effect_data: StatusEffectData, source: Character = null) -> StatusEffect:
	# 检查是否已有相同ID的效果
	var existing_effect = get_status_effect_by_id(effect_data.effect_id)
	
	if existing_effect:
		# 已存在相同效果，处理叠加
		var new_effect = StatusEffect.new(effect_data, source)
		existing_effect.stack_effect(new_effect)
		status_effect_updated.emit(existing_effect)
		print(character_name + " 的状态 " + effect_data.effect_name + " 已叠加至 " + str(existing_effect.stack_count) + " 层")
		return existing_effect
	else:
		# 不存在，添加新效果
		var effect = StatusEffect.new(effect_data, source)
		active_status_effects.append(effect)
		status_effect_added.emit(effect)
		print(character_name + " 获得了状态: " + effect_data.effect_name)
		return effect

# 移除状态效果
func remove_status_effect(effect_id: String) -> void:
	for i in range(active_status_effects.size() - 1, -1, -1):
		if active_status_effects[i].data.effect_id == effect_id:
			var effect = active_status_effects[i]
			active_status_effects.remove_at(i)
			status_effect_removed.emit(effect)
			print(character_name + " 的状态 " + effect.data.effect_name + " 已移除")
			break

# 清除所有状态效果
func clear_all_status_effects() -> void:
	var effects_to_remove = active_status_effects.duplicate()
	active_status_effects.clear()
	
	for effect in effects_to_remove:
		status_effect_removed.emit(effect)
	
	print(character_name + " 的所有状态效果已清除")

# 通过ID获取状态效果
func get_status_effect_by_id(effect_id: String) -> StatusEffect:
	for effect in active_status_effects:
		if effect.data.effect_id == effect_id:
			return effect
	return null

# 获取所有特定类型的状态效果
func get_status_effects_by_type(type: int) -> Array:  # Array[StatusEffect]
	var result = []
	for effect in active_status_effects:
		if effect.data.effect_type == type:
			result.append(effect)
	return result

# 检查是否可以行动
func can_act() -> bool:
	# 如果有眩晕效果，无法行动
	if has_control_effect("stun"):
		return false
	
	if has_control_effect("sleep"):
		return false
	
	# 检查状态效果
	for effect in active_status_effects:
		if !effect.allows_action():
			return false
			
	return true

# 处理回合结束时的状态效果
func process_status_effects_end_of_round() -> void:
	# 处理持续伤害/治疗效果
	for effect in active_status_effects:
		if effect.data.effect_type == StatusEffectData.EffectType.DOT:
			var damage = effect.get_dot_hot_value()
			print(character_name + " 因 " + effect.data.effect_name + " 受到 " + str(damage) + " 点伤害")
			take_damage(damage)
		
		elif effect.data.effect_type == StatusEffectData.EffectType.HOT:
			var healing = effect.get_dot_hot_value()
			print(character_name + " 因 " + effect.data.effect_name + " 恢复 " + str(healing) + " 点生命")
			heal(healing)
	
	# 更新持续时间并移除已结束的效果
	for i in range(active_status_effects.size() - 1, -1, -1):
		var effect = active_status_effects[i]
		if effect.update_duration():  # 如果效果已结束
			print(character_name + " 的状态 " + effect.data.effect_name + " 已结束")
			active_status_effects.remove_at(i)
			status_effect_removed.emit(effect)
	
	# 处理控制效果的持续时间
	process_control_effects_end_turn()

# 计算考虑状态效果的属性值
func get_modified_stat(stat_type: int, base_value: float) -> float:
	var modified_value = base_value
	
	for effect in active_status_effects:
		# 检查效果是否影响指定属性或所有属性
		if effect.data.target_stat == stat_type or effect.data.target_stat == StatusEffectData.TargetStat.ALL_STATS:
			modified_value += effect.calculate_stat_modification(base_value)
	
	# 确保数值不会低于1（避免负值属性）
	return max(1.0, modified_value)

# 获取考虑状态效果后的攻击力
func get_modified_attack() -> int:
	return int(get_modified_stat(StatusEffectData.TargetStat.ATTACK, attack))

# 获取考虑状态效果后的防御力
func get_modified_defense() -> int:
	return int(get_modified_stat(StatusEffectData.TargetStat.DEFENSE, defense))

# 获取考虑状态效果后的魔法攻击力
func get_modified_magic_attack() -> int:
	return int(get_modified_stat(StatusEffectData.TargetStat.MAGIC_ATTACK, magic_attack))

# 获取考虑状态效果后的魔法防御力
func get_modified_magic_defense() -> int:
	return int(get_modified_stat(StatusEffectData.TargetStat.MAGIC_DEFENSE, magic_defense))

# 获取考虑状态效果后的速度
func get_modified_speed() -> int:
	return int(get_modified_stat(StatusEffectData.TargetStat.SPEED, speed))

## 应用控制效果
func apply_control_effect(control_type: String, duration: int):
	if control_effects.has(control_type):
		# 如果已有此类控制效果，取更长的持续时间
		control_effects[control_type] = max(control_effects[control_type], duration)
	else:
		# 否则直接添加
		control_effects[control_type] = duration
	
	print("%s 被%s，持续%d回合" % [character_name, get_control_name(control_type), duration])
	
	# 发出信号
	control_effect_applied.emit(control_type, duration)
	control_effect_changed.emit(self)

## 检查是否有特定控制效果
func has_control_effect(control_type: String) -> bool:
	return control_effects.has(control_type) and control_effects[control_type] > 0

## 获取所有控制效果
func get_all_control_effects() -> Dictionary:
	return control_effects.duplicate()

## 移除控制效果
func remove_control_effect(control_type: String):
	if control_effects.has(control_type):
		control_effects.erase(control_type)
		control_effect_removed.emit(control_type)
		control_effect_changed.emit(self)

## 处理回合结束时的控制效果
func process_control_effects_end_turn():
	var effects_to_remove = []
	
	# 减少所有控制效果的持续时间
	for effect_type in control_effects.keys():
		control_effects[effect_type] -= 1
		
		# 如果持续时间为0，准备移除
		if control_effects[effect_type] <= 0:
			effects_to_remove.append(effect_type)
	
	# 移除过期的控制效果
	for effect_type in effects_to_remove:
		print("%s 的%s效果已结束" % [character_name, get_control_name(effect_type)])
		control_effects.erase(effect_type)
		control_effect_removed.emit(effect_type)
	
	# 如果有效果被移除，发出信号
	if effects_to_remove.size() > 0:
		control_effect_changed.emit(self)

## 获取控制效果显示名称
func get_control_name(control_type: String) -> String:
	match control_type:
		"stun":
			return "眩晕"
		"silence":
			return "沉默"
		"root":
			return "定身"
		"sleep":
			return "睡眠"
		_:
			return control_type

## 检查是否能使用技能（考虑控制效果）
func can_use_skills() -> bool:
	# 如果有沉默效果，无法使用技能
	if has_control_effect("silence"):
		return false
	
	# 如果有眩晕效果，无法使用技能
	if has_control_effect("stun"):
		return false
	
	return true
