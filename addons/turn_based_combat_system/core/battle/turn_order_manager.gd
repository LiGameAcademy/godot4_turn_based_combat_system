extends Node
class_name TurnOrderManager

## 回合管理器
## 负责管理战斗回合的顺序和流程
## 包括构建回合队列、获取下一个角色、检查角色位置等

## 回合队列
var turn_queue: Array[Node] = []
## 当前行动者
var current_character: Node = null
var current_turn_index: int = -1
## 角色注册管理器
var _character_registry: BattleCharacterRegistryManager

signal turn_changed(character: Node)				## 当回合角色改变时发出

## 初始化
## [param character_registry] BattleCharacterRegistryManager 实例
func initialize(character_registry: BattleCharacterRegistryManager) -> void:
	if not character_registry:
		push_error("TurnOrderManager requires a BattleCharacterRegistryManager reference.")
		return
	_character_registry = character_registry
	current_turn_index = 0

## 构建回合队列
func build_queue() -> void:
	turn_queue.clear()
	
	# 收集所有存活角色
	var all_characters: Array[Node] = []
	for player in _character_registry.get_player_team(true):
		if _is_character_alive(player):
			all_characters.append(player)
			
	for enemy in _character_registry.get_enemy_team(true):
		if _is_character_alive(enemy):
			all_characters.append(enemy)
	
	# 按速度排序（使用鸭子类型获取速度）
	all_characters.sort_custom(func(a, b): return _get_character_speed(a) > _get_character_speed(b))
	turn_queue = all_characters
	
	print("回合顺序已生成: %d 个角色" % turn_queue.size())

## 队列中是否还存在下一个角色
func has_next_character() -> bool:
	return not turn_queue.is_empty()

## 获取下一个角色
## [return] 下一个角色
func get_next_character() -> Node:
	if turn_queue.is_empty():
		push_error("回合队列为空！无法获取下一个角色！")
		return null
		
	current_character = turn_queue.pop_front()
	current_turn_index += 1
	turn_changed.emit(current_character)
	return current_character

## 检查角色是否为玩家角色
## [param character] 要检查的角色
## [param player_characters] 玩家角色列表
## [return] 是否为玩家角色
func is_player_character(character: Node, player_characters: Array[Node]) -> bool:
	return player_characters.has(character)

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
	
	var char_name = _get_character_name(character)
	print("%s 已被插入到回合队列位置 %d" % [char_name, position])
	
## 从队列中移除角色
## [param character] 要移除的角色
## [return] 是否成功移除
func remove_character_from_queue(character: Node) -> bool:
	if turn_queue.has(character):
		turn_queue.erase(character)
		var char_name = _get_character_name(character)
		print("%s 已从回合队列中移除" % char_name)
		return true
	return false

## 清空队列
func clear_queue() -> void:
	turn_queue.clear()
	current_character = null

#region --- 辅助方法（鸭子类型支持） ---
## 获取角色名称（鸭子类型）
func _get_character_name(character: Node) -> String:
	if character.has_method("get_character_name"):
		return character.get_character_name()
	elif "character_name" in character:
		return character.character_name
	return "Unknown"

## 检查角色是否存活（鸭子类型）
func _is_character_alive(character: Node) -> bool:
	if character.has_method("get_is_alive"):
		return character.get_is_alive()
	elif "is_alive" in character:
		return character.is_alive
	return false

## 获取角色速度（鸭子类型）
func _get_character_speed(character: Node) -> float:
	if character.has_method("get_speed"):
		return character.get_speed()
	elif "speed" in character:
		return character.speed
	return 0.0
#endregion
