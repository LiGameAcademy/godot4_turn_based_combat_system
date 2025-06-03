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
@onready var hp_label = $Container/HPLabel
@onready var name_label = $Container/NameLabel
@onready var character_rect = $Container/CharacterRect

func _ready():
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")

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

func update_visual():
	if name_label:
		name_label.text = character_name
	
	if hp_label:
		hp_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)
	
	if character_rect and character_data:
		character_rect.color = character_data.color

# 战斗相关方法
func apply_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	update_visual()
	print_rich("[color=cyan][b]{0}[/b][/color] 受到 [color=red]{1}[/color] 点伤害, 剩余HP: [color=lime]{2}[/color]".format([character_name, amount, current_hp]))
	
	if current_hp == 0:
		die()

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
	modulate = Color(1, 1, 1, 0.5) # 半透明表示被击败
