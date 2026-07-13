extends Resource
class_name CharacterData

@export var character_name: String = "英雄"
@export_multiline var description: String = "一个勇敢的战士。"

@export_group("核心属性")
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_mp: int = 50
@export var current_mp: int = 50
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 7

@export_group("视觉表现")
@export var color: Color = Color.BLUE  # 为原型阶段设置的角色颜色

# 辅助函数
func reset_stats():
	current_hp = max_hp
	current_mp = max_mp

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	
func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)
	
func use_mp(amount: int) -> bool:
	if current_mp >= amount:
		current_mp -= amount
		return true
	return false
