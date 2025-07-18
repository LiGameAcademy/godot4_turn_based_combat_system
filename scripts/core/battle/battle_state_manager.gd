extends Node
class_name BattleStateManager

## 状态管理器
## 负责管理战斗的流程和状态

## 状态枚举
enum BattleState { 
	IDLE, 					## 空闲状态
	START, 					## 开始状态
	ROUND_START,			## 回合开始状态
	ROUND_END,				## 回合结束状态
	TURN_START,				## 回合开始状态
	TURN_END,				## 回合结束状态
	PLAYER_TURN,			## 玩家回合状态
	ENEMY_TURN,				## 敌人回合状态
	VICTORY, 				## 胜利状态
	DEFEAT					## 失败状态
}

var current_state: BattleState = BattleState.IDLE			## 当前状态
var previous_state: BattleState = BattleState.IDLE			## 上一个状态

signal state_changed(previous_state: BattleState, new_state: BattleState)	## 状态切换信号

## 初始化状态机
func initialize(initial_state: BattleState = BattleState.IDLE) -> void:
	current_state = initial_state
	previous_state = initial_state
	print_rich("[color=purple][状态机][/color] 已初始化，初始状态为: %s" % BattleState.keys()[current_state])

## 切换状态的核心方法
func change_state(new_state: BattleState) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	# 打印日志并发出信号
	print_rich("[color=purple][状态机][/color] 状态切换: [color=gray]%s[/color] -> [color=yellow]%s[/color]" % [BattleState.keys()[previous_state], BattleState.keys()[new_state]])
	state_changed.emit(previous_state, new_state)

## 判断当前状态
func is_in_state(state: BattleState) -> bool:
	return current_state == state
