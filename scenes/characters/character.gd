extends Node2D
class_name Character

@export var character_data: CharacterData

# 运行时从CharacterData初始化的核心战斗属性
var character_name: String
var current_hp: int
var max_hp: int
var current_mp: int
var max_mp: int
var attack: int
var defense: int
var speed: int

# 引用场景中的节点
@onready var hp_bar : ProgressBar = %HPBar
@onready var hp_label := %HPLabel
@onready var name_label := $Container/NameLabel
@onready var character_rect := $Container/CharacterRect
@onready var defense_indicator: DefenseIndicator = $DefenseIndicator

var _is_defending: bool = false			## 防御状态标记

signal hp_changed(new_hp: int, max_hp: int)
signal character_died()

func _ready():
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")

	if !hp_changed.is_connected(_on_hp_changed):
		hp_changed.connect(_on_hp_changed)
	
	# 初始化HP条
	_on_hp_changed(current_hp, max_hp)

## 初始化玩家数据
func initialize_from_data(data: CharacterData):
	# 保存数据引用
	self.character_data = data
	
	# 初始化属性
	self.character_name = data.character_name
	self.max_hp = data.max_hp
	self.current_hp = data.current_hp
	self.max_mp = data.max_mp
	self.current_mp = data.current_mp
	self.attack = data.attack
	self.defense = data.defense
	self.speed = data.speed
	
	# 更新视觉表现
	update_visual()
	
	print_rich("[color=cyan][b]{0}[/b][/color] 初始化完毕，HP: [color=lime]{1}/{2}[/color]".format([character_name, current_hp, max_hp]))

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
	_is_defending = value
	if defense_indicator:
		if _is_defending:
			defense_indicator.show_indicator()
		else:
			defense_indicator.hide_indicator()

## 伤害处理方法
func take_damage(base_damage: int) -> int:
	var final_damage: int = base_damage

	# 如果处于防御状态，则减免伤害
	if _is_defending:
		final_damage = round(final_damage * 0.5)
	
		print(character_name + " 正在防御，伤害减半！")
		set_defending(false)	# 防御效果通常在受到一次攻击后解除
	
	final_damage = max(1, final_damage)	# 保证至少1点伤害

	current_hp = max(0, current_hp - final_damage)

	hp_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		die()
	
	print_rich("[color=red]" + character_name + " 受到 " + str(final_damage) + " 点伤害![/color]")
	return final_damage

func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)
	update_visual()
	print_rich("[color=cyan][b]{0}[/b][/color] 恢复 [color=green]{1}[/color] 点HP, 剩余HP: [color=lime]{2}[/color]".format([character_name, amount, current_hp]))

func use_mp(amount: int) -> bool:
	if current_mp >= amount:
		current_mp -= amount
		update_visual()
		return true
	return false

func die():
	print_rich("[color=red][b]{0} 已被击败![/b][/color]".format([character_name]))
	# 在完整游戏中会添加死亡动画和事件
	character_died.emit()
	modulate = Color(1, 1, 1, 0.5) # 半透明表示被击败

## 回合开始时重置标记
func reset_turn_flags() -> void:
	set_defending(false)

func _on_hp_changed(new_hp : int, maximum_hp: int) -> void:
	if not hp_bar:
		return
	hp_bar.max_value = maximum_hp
	hp_bar.value = new_hp

	# 根据血条百分比改变颜色
	if hp_bar.ratio <= 0.25:
		hp_bar.self_modulate = Color.RED
	elif hp_bar.ratio <= 0.5:
		hp_bar.self_modulate = Color.YELLOW
	else:
		hp_bar.self_modulate = Color.GREEN
	
	hp_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)
