extends Node
class_name BattleStateManager

# 将BattleState枚举定义在这里，作为这个模块的内部定义
enum BattleState { 
	IDLE, 
	START, 
	ROUND_START,
	ROUND_END, 
	TURN_START,
	TURN_END,
	PLAYER_TURN, 
	ENEMY_TURN, 
	VICTORY, 
	DEFEAT }

var current_state: BattleState = BattleState.IDLE
var previous_state: BattleState = BattleState.IDLE

# 定义一个内容更丰富的信号，传递旧状态和新状态
signal state_changed(previous_state: BattleState, new_state: BattleState)

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

func is_in_state(state: BattleState) -> bool:
	return current_state == state
	
