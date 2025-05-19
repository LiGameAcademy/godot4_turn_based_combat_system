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

signal character_defeated(source: Variant)										## 角色被击败
signal display_health_changed(current_value: float, max_value: float)			## 显示血量变化
signal display_mana_changed(current_value: float, max_value: float)				## 显示法力变化

func _ready() -> void:
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
