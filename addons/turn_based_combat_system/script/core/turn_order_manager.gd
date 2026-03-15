extends Node
class_name TurnOrderManager

## 回合管理器
## 负责管理战斗回合的顺序和流程
## 包括构建回合队列、获取下一个角色、检查角色位置等

## 回合队列
var turn_queue: Array[Node] = []
## 当前行动者
var current_character: Node = null

signal turn_changed(character: Node)				## 当回合角色改变时发出

## 初始化
## [param character_registry] BattleCharacterRegistryManager 实例
func initialize() -> void:
	turn_queue.clear()
	current_character = null

## 构建回合队列
func build_queue(all_characters: Array[Node]) -> void:
	turn_queue = all_characters.duplicate(true)
	turn_queue.sort_custom(func(a : Node, b : Node): 
		var skill_component_a : SkillComponentInterface = a.get_skill_component() if a.has_method("get_skill_component") else null
		var skill_component_b : SkillComponentInterface = b.get_skill_component() if b.has_method("get_skill_component") else null
		if not is_instance_valid(skill_component_a) or not is_instance_valid(skill_component_b):
			return false
		var speed_a = skill_component_a.get_attribute_current_value(&"speed")
		var speed_b = skill_component_b.get_attribute_current_value(&"speed")
		return speed_a > speed_b
		)
	print("回合顺序已生成: %d 个角色" % turn_queue.size())

## 队列中是否还存在下一个角色
func has_next_character() -> bool:
	return not turn_queue.is_empty()

## 获取下一个角色
## [return] 下一个角色
func get_next_character() -> void:
	if turn_queue.is_empty():
		push_error("回合队列为空！无法获取下一个角色！")
		return
		
	current_character = turn_queue.pop_front()
	turn_changed.emit(current_character)

## 获取剩余回合数
## [return] 剩余回合数
func get_remaining_turn_count() -> int:
	return turn_queue.size()

## 获取角色在队列中的位置
## [param character] 要检查的角色
## [return] 角色在队列中的位置
func get_character_position_in_queue(character: Node) -> int:
	return turn_queue.find(character)

## 在队列中插入角色
## [param character] 要插入的角色
## [param position] 插入位置
func insert_character_at_position(character: Node, position: int = 0) -> void:
	if position < 0 or position > turn_queue.size():
		turn_queue.append(character)
	else:
		turn_queue.insert(position, character)
	
	var character_name = character.get_character_name() if character.has_method("get_character_name") else "未知角色"
	print("%s 已被插入到回合队列位置 %d" % [character_name, position])

## 从队列中移除角色
## [param character] 要移除的角色
## [return] 是否成功移除
func remove_character_from_queue(character: Node) -> bool:
	if turn_queue.has(character):
		turn_queue.erase(character)
		print("%s 已从回合队列中移除" % character.character_name)
		return true
	return false

## 清空队列
func clear_queue() -> void:
	turn_queue.clear()
	current_character = null
