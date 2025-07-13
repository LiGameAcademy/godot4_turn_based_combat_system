extends Node
class_name CombatRuleManager

## 战斗规则管理器
## 负责管理战斗规则和状态
## 包括回合管理、胜负判断等

## 引用 CharacterRegistryManager (通常需要它来检查队伍状态)
var _character_registry: BattleCharacterRegistryManager 

# 战斗状态信号
signal player_victory	## 玩家胜利
signal player_defeat	## 玩家失败

# 可配置的规则
@export var max_turns: int = -1 		## 最大回合数，-1表示无限制
var current_turn_count: int = 0			## 当前回合数

## 初始化，在 BattleManager 中获取其他模块的引用
## [param registry] BattleCharacterRegistryManager 实例
func initialize(registry: BattleCharacterRegistryManager) -> void:
	if not registry:
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

	# 这里可以添加每回合开始时触发的特殊规则或环境效果
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
		# battle_draw.emit() # 或者根据规则判定为失败
		player_defeat.emit() # 假设同归于尽算玩家失败
		return true
	
	# 检查其他可能的结束条件，例如特定Boss被击败，或达到某个目标
	# if check_special_victory_conditions():
	#    player_victory.emit()
	#    return true
	# if check_special_defeat_conditions():
	#    player_defeat.emit()
	#    return true

	return false # 战斗未结束

# --- 你可以添加更多自定义规则方法 ---
## 应用全局战场效果
## [return] 是否成功应用
# func apply_global_battlefield_effect():
#   print("Applying global battlefield effect...")
#   for char in _character_registry.get_all_living_characters():
#       if is_instance_valid(char):
#           # 例如，每回合所有角色受到少量毒性伤害
#           # char.take_damage(5, "Poisonous Fumes") 
#           pass

## 检查特殊胜利条件
## [return] 是否满足特殊胜利条件
# func check_special_victory_conditions() -> bool:
#   # 例如：如果某个特定敌人 (Boss) 被击败
#   # var boss = _character_registry.get_character_by_id("boss_unique_id")
#   # if boss and not boss.is_alive:
#   #    return true
#   return false
