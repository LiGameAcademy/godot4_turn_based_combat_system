extends Resource
class_name BattleData

## 战斗标题
@export var battle_title: String = "战斗"

## 战斗背景
@export var battle_background: Texture2D

## 战斗音乐
@export var battle_music: AudioStream

## 敌人数据列表
@export var enemy_data_list: Array[CharacterData] = []

## 敌人位置列表 (对应enemy_data_list的每个敌人)
@export var enemy_positions: Array[Vector2] = []

## 玩家角色数据列表 (可选，如果为空则使用全局玩家队伍)
@export var player_data_list: Array[CharacterData] = []

## 玩家位置列表 (对应player_data_list的每个角色)
@export var player_positions: Array[Vector2] = []

## 战斗最大回合数 (超过此回合数自动失败，0表示无限制)
@export var max_turn_count: int = 0

## 战斗失败时的场景
@export_file("*.tscn") var defeat_scene: String = ""

## 战斗胜利时的场景
@export_file("*.tscn") var victory_scene: String = ""

## 战斗胜利奖励
@export var exp_reward: int = 0
@export var gold_reward: int = 0
@export var item_rewards: Array = []

## 战斗特殊条件
@export var is_boss_battle: bool = false
@export var allow_escape: bool = true
@export var special_conditions: Dictionary = {}

## 战斗描述 (用于战斗日志或介绍)
@export_multiline var battle_description: String = ""

## 获取敌人数量
func get_enemy_count() -> int:
	return enemy_data_list.size()

## 获取玩家角色数量
func get_player_count() -> int:
	return player_data_list.size()

## 检查战斗数据是否有效
func is_valid() -> bool:
	# 至少需要有敌人数据
	if enemy_data_list.is_empty():
		return false
		
	# 检查敌人位置是否与敌人数据匹配
	if enemy_positions.size() != enemy_data_list.size():
		return false
		
	# 如果有玩家数据，检查玩家位置是否匹配
	if not player_data_list.is_empty() and player_positions.size() != player_data_list.size():
		return false
		
	return true
