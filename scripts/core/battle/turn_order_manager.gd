extends Node
class_name TurnOrderManager

## 回合管理器
## 负责管理战斗回合的顺序和流程
## 包括构建回合队列、获取下一个角色、检查角色位置等

var turn_queue: Array[Character] = []
var current_character: Character = null

var _character_registry: BattleCharacterRegistryManager

signal turn_changed(character)
signal round_ended

func initialize(character_registry: BattleCharacterRegistryManager) -> void:
	if not character_registry:
		push_error("TurnOrderManager requires a BattleCharacterRegistryManager reference.")
		return
	_character_registry = character_registry

func build_queue() -> void:
	turn_queue.clear()
	
	# 收集所有存活角色
	var all_characters: Array[Character] = []
	for player in _character_registry.get_player_team(true):
		if player.is_alive:
			all_characters.append(player)
			
	for enemy in _character_registry.get_enemy_team(true):
		if enemy.is_alive:
			all_characters.append(enemy)
	
	# 按速度排序
	all_characters.sort_custom(func(a, b): return a.speed > b.speed)
	turn_queue = all_characters
	
	print("回合顺序已生成: %d 个角色" % turn_queue.size())

func get_next_character() -> Character:
	if turn_queue.is_empty():
		round_ended.emit()
		return null
		
	current_character = turn_queue.pop_front()
	turn_changed.emit(current_character)
	return current_character

func is_player_character(character: Character, player_characters: Array[Character]) -> bool:
	return player_characters.has(character)

func get_remaining_turn_count() -> int:
	return turn_queue.size()
	
func get_character_position_in_queue(character: Character) -> int:
	return turn_queue.find(character)
	
func insert_character_at_position(character: Character, position: int = 0) -> void:
	if position < 0 or position > turn_queue.size():
		turn_queue.append(character)
	else:
		turn_queue.insert(position, character)
	
	print("%s 已被插入到回合队列位置 %d" % [character.character_name, position])
	
func remove_character_from_queue(character: Character) -> bool:
	if turn_queue.has(character):
		turn_queue.erase(character)
		print("%s 已从回合队列中移除" % character.character_name)
		return true
	return false
	
func clear_queue() -> void:
	turn_queue.clear()
	current_character = null
