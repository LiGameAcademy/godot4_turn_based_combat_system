extends Node
class_name CombatRuleManager

## 战斗规则管理器
## 负责管理战斗规则和状态
## 包括回合管理、胜负判断等

## 引用 CharacterRegistryManager (通常需要它来检查队伍状态)
var _character_registry: BattleCharacterRegistryManager 

# 可配置的规则
@export var max_turns: int = -1 		## 最大回合数，-1表示无限制
var current_turn_count: int = 0		## 当前回合数

# 战斗状态信号
signal player_victory				## 玩家胜利
signal player_defeat					## 玩家失败

## 初始化，在 BattleManager 中获取其他模块的引用
## [param registry] BattleCharacterRegistryManager 实例
func initialize(registry: BattleCharacterRegistryManager) -> void:
	if not is_instance_valid(registry):
		push_error("CombatRuleManager requires a BattleCharacterRegistryManager reference.")
		return
	_character_registry = registry
	current_turn_count = 0
	print("CombatRuleManager initialized.")

## 战斗回合计数
func add_turn_count() -> void:
	current_turn_count += 1
	print("[CombatRuleManager] Turn %d started." % current_turn_count)
	
	# 检查回合数限制
	if max_turns > 0 and current_turn_count > max_turns:
		print_rich("[color=orange]Max turns reached![/color]")
		# 根据游戏规则处理，可能是平局或玩家失败
		player_defeat.emit() 
		# battle_draw.emit()
		return

	# TODO: 这里可以添加每回合开始时触发的特殊规则或环境效果
	# e.g., apply_global_battlefield_effect()

## 用于检查战斗是否结束
## [return] 是否战斗已结束
func check_battle_end_conditions() -> bool: # 返回true如果战斗已结束
	if not _character_registry:
		push_error("CharacterRegistry is not set in CombatRuleManager!")
		return false

	var player_team_defeated = _character_registry.is_team_defeated(true)
	var enemy_team_defeated = _character_registry.is_team_defeated(false)

	if enemy_team_defeated and not player_team_defeated:
		print_rich("[color=green][b]Player Victory![/b][/color]")
		player_victory.emit()
		return true
	elif player_team_defeated and not enemy_team_defeated:
		print_rich("[color=red][b]Player Defeat![/b][/color]")
		player_defeat.emit()
		return true
	elif player_team_defeated and enemy_team_defeated: #双方同时被击败
		print_rich("[color=yellow]Battle Draw! (Both teams defeated)[/color]")
		player_defeat.emit() # 假设同归于尽算玩家失败
		return true

	return false # 战斗未结束
