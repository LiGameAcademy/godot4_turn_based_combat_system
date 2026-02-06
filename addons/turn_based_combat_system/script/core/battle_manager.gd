extends Node
class_name BattleManager

## 战斗管理器-全局单例
## 负责管理战斗的流程和状态

const BattleState = BattleStateManager.BattleState

## 状态管理器
@onready var state_manager: BattleStateManager = %BattleStateManager
## 战斗视觉效果管理器
@onready var battle_visual_effects: BattleVisualEffects = %BattleVisualEffects
## 角色注册管理器
@onready var character_registry: BattleCharacterRegistryManager = %BattleCharacterRegistryManager
## 回合顺序管理器
@onready var turn_order_manager: TurnOrderManager = %TurnOrderManager
## 战斗规则管理器
@onready var combat_rule_manager: CombatRuleManager = %CombatRuleManager

## 施法位置引用
@export var cast_marker : Marker2D

# 回合顺序管理
var turn_queue: Array[Node]:								## 回合队列
	get:
		return turn_order_manager.turn_queue
	set(_value):
		push_error("cannot set turn_queue becouse its readonly!")
var current_turn_character: Node = null:			## 当前行动者
	get:
		return turn_order_manager.current_character
	set(_value):
		push_error("cannot set current_turn_character becouse its readonly!")
var is_player_turn : bool = false :						## 是否是玩家回合
	get:
		return character_registry.is_player_character(current_turn_character)
	set(_value):
		push_error("cannot set is_player_turn becouse its readonly!")
var characters : Array[Node]:
	get:
		return character_registry.get_all_characters()
var current_turn_count: int :
	get:
		return combat_rule_manager.current_turn_count

## 信号
signal turn_changed(character: Node)							## 当前行动者改变时触发
signal battle_ended(is_victory: bool)							## 战斗结束时触发
signal battle_info_logged(text: String)							## 战斗日志记录时触发
signal round_changed(turn_count: int)							## 回合改变时触发

## 敌人行动执行时触发
signal enemy_action_executed(source: Node, target: Node, damage: float)	

func _ready() -> void:
	character_registry.initialize()
	character_registry.character_registered.connect(_on_character_registered)
	character_registry.character_unregistered.connect(_on_character_unregistered)
	character_registry.team_changed.connect(_on_team_changed)

	combat_rule_manager.initialize(character_registry)
	combat_rule_manager.player_victory.connect(_on_player_victory)
	combat_rule_manager.player_defeat.connect(_on_player_defeat)

	turn_order_manager.initialize()
	turn_order_manager.turn_changed.connect(
		func(character: Node) -> void:
			if character != current_turn_character:
				return
			turn_changed.emit(character)
	)

	state_manager.state_changed.connect(_on_state_changed)
	state_manager.initialize(BattleStateManager.BattleState.IDLE)

## 开始战斗
func start_battle() -> void:
	_log_battle_info("[color=yellow][b]===== 战斗开始! =====[/b][/color]")
	
	var player_characters = character_registry.get_player_team(true)
	if player_characters.is_empty():
		push_error("无法开始战斗：缺少玩家!")
		return
	var enemy_characters = character_registry.get_enemy_team(true)
	if enemy_characters.is_empty():
		push_error("无法开始战斗：缺少敌人!")
		return
	state_manager.change_state(BattleStateManager.BattleState.START)

## 玩家选择行动 - 由BattleScene调用
## [param action_type] 行动类型
## [param target] 目标角色
## [param params] 行动参数
func player_select_action(action_type: CharacterCombatComponent.ActionType, target: Node = null, params: Dictionary = {}) -> void:
	if not is_player_turn:
		_log_battle_info("[color=red]当前不是玩家回合，无法选择行动![/color]")
		return

	if not is_instance_valid(current_turn_character):
		push_error("当前行动者不存在！")
		return

	var combat_component = current_turn_character.get_combat_component() if current_turn_character.has_method("get_combat_component") else null
	if not is_instance_valid(combat_component):
		push_error("当前行动者没有战斗组件！")
		return

	_log_battle_info("[color=cyan]玩家选择行动: %s[/color]" % action_type)
	
	params.merge({"battle_manager": self}, true)

	await combat_component.execute_action(action_type, target, params)

	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

## 执行敌人AI
func execute_enemy_ai() -> void:
	if not is_instance_valid(current_turn_character):
		push_error("当前行动者不存在！")
		return

	# 检查角色是否有AI组件
	var ai_component = current_turn_character.get_ai_component() if current_turn_character.has_method("get_ai_component") else null

	if not is_instance_valid(ai_component):
		push_error("当前行动者没有AI组件！")
		return

	# 执行AI行动
	var action_result = await ai_component.execute_action()

	# 如果AI无法决策或执行失败，直接结束回合
	if not action_result or not action_result.is_valid:
		_log_battle_info("[color=red][错误][/color] AI无法决策或执行失败，跳过回合")
	else:
		# 发送敌人行动执行信号
		enemy_action_executed.emit(action_result.source, action_result.target, action_result.damage)

	await get_tree().create_timer(1.0).timeout
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

## 添加角色
func add_character(character: Node, is_player: bool = true) -> void:
	var combat_component = character.get_combat_component() if character.has_method("get_combat_component") else null
	if not is_instance_valid(combat_component):
		push_error("角色 {0} 没有战斗组件！".format([character.character_name]))
		return
	combat_component.character_defeated.connect(_on_character_defeated.bind(character))
	character_registry.register_character(character, is_player)
	
## 移除角色
## [param character] 角色
func remove_character(character: Node) -> void:
	var combat_component = character.get_combat_component() if character.has_method("get_combat_component") else null
	if not is_instance_valid(combat_component):
		push_error("角色 {0} 没有战斗组件！".format([character.character_name]))
		return
	combat_component.character_defeated.disconnect(_on_character_defeated.bind(character))
	character_registry.unregister_character(character)		

## 获取有效的敌方目标列表（过滤掉已倒下的角色）
## [param caster] 施法者
## [return] 有效的敌方目标列表
func get_valid_enemy_targets(caster : Node) -> Array[Node]:
	if not is_instance_valid(caster):
		push_error("施法者不存在！")
		return [] as Array[Node]
	return character_registry.get_opposing_team_for_character(caster)

## 获取有效的友方目标列表
## [param include_self] 是否包括施法者自己
## [param caster] 施法者
## [return] 有效的友方目标列表
func get_valid_ally_targets(caster : Node, include_self: bool = false) -> Array[Node]:
	if not is_instance_valid(caster):
		push_error("施法者不存在！")
		return [] as Array[Node]
	return character_registry.get_allied_team_for_character(caster, include_self)

## 判断是否是敌人
## [param character1] 角色1
## [param character2] 角色2
## [return] 是否是敌人
func is_enemy(character1: Node, character2: Node) -> bool:
	return character_registry.is_enemy_of(character1, character2)

## 构建回合队列
func _build_turn_queue(all_characters: Array[Node]) -> void:
	turn_order_manager.build_queue(all_characters)
	_log_battle_info("[color=yellow][战斗系统][/color] 回合队列已建立: [color=green][b]{0}[/b][/color] 个角色".format([turn_queue.size()]))

## 战斗日志
## [param text] 日志文本
func _log_battle_info(text: String) -> void:
	print_rich(text)
	battle_info_logged.emit(text)

## 检查战斗结束条件
## [return] 战斗是否结束
func _check_battle_end_condition() -> bool:
	# 检查玩家是否全部阵亡
	return combat_rule_manager.check_battle_end_conditions()

#region 视觉反馈
## 状态效果应用视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_status_effect(target: Node, params: Dictionary = {}) -> void:
	battle_visual_effects.play_status_effect(target, params)
	
## 播放施法效果
## [param target] 目标角色
## [param params] 参数
func _play_cast_effect(_target: Node, _params: Dictionary = {}) -> void:
	battle_visual_effects.play_cast_effect(_target, _params)

## 播放治疗施法效果
## [param target] 目标角色
## [param params] 参数
func _play_heal_cast_effect(_target: Node, _params: Dictionary = {}) -> void:
	if battle_visual_effects.has_method("play_heal_cast_effect"):
		battle_visual_effects.play_heal_cast_effect(_target, _params)

## 治疗效果视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_heal_effect(target: Node, _params : Dictionary = {}) -> void:
	battle_visual_effects.play_heal_effect(target, _params)
	
## 受击效果视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_hit_effect(_target: Node, _params: Dictionary = {}) -> void:
	pass

## 状态效果应用成功视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_status_applied_success_effect(_target: Node, _params: Dictionary = {}) -> void:
	pass

## 受击数字效果
## [param target] 目标角色
## [param params] 参数
func _play_damage_number_effect(_target: Node, _params: Dictionary = {}) -> void:
	var damage : float = _params.get("damage", 0)
	var color : Color = _params.get("color", Color.RED)
	var prefix : String = _params.get("prefix", "")
	_target.spawn_damage_number(damage, color, prefix)

#endregion

#region 状态处理
func _handle_start_state() -> void:
	_log_battle_info("[color=yellow][战斗系统][/color] 战斗开始")
	state_manager.change_state(BattleStateManager.BattleState.ROUND_START)

func _handle_round_start_state() -> void:
	combat_rule_manager.add_turn_count()
	var all_characters: Array[Node] = character_registry.get_all_characters()
	_build_turn_queue(all_characters)
	if turn_queue.is_empty():
		state_manager.change_state(BattleStateManager.BattleState.DEFEAT)
	else:
		state_manager.change_state(BattleStateManager.BattleState.TURN_START)
	_log_battle_info("[color=yellow][战斗系统][/color] 第 {0} 回合开始".format([current_turn_count]))
	round_changed.emit(current_turn_count)

func _handle_turn_start_state() -> void:
	turn_order_manager.get_next_character()
	
	if not is_instance_valid(current_turn_character):
		push_error("当前行动者不存在！")
		return
	var combat_component = current_turn_character.get_combat_component() if current_turn_character.has_method("get_combat_component") else null
	if not is_instance_valid(combat_component):
		push_error("当前行动者没有战斗组件！")
		return
	combat_component.on_turn_start(self)

	if not is_player_turn:
		await get_tree().create_timer(1.0).timeout
		await execute_enemy_ai()
	var character_name : String = current_turn_character.get_character_name() if current_turn_character.has_method("get_character_name") else "Unknown"
	_log_battle_info("[color=yellow][战斗系统][/color] {0} 的回合开始".format([character_name]))
	

func _handle_turn_end_state() -> void:
	var combat_component = current_turn_character.get_combat_component() if current_turn_character.has_method("get_combat_component") else null
	if not is_instance_valid(combat_component):
		push_error("当前行动者没有战斗组件！")
		return
	var character_name : String = current_turn_character.get_character_name() if current_turn_character.has_method("get_character_name") else "Unknown"
	combat_component.on_turn_end(self)
	if turn_order_manager.has_next_character():
		# 进入下一个角色的回合
		state_manager.change_state(BattleStateManager.BattleState.TURN_START)
	else:
		state_manager.change_state(BattleStateManager.BattleState.ROUND_END)
	_log_battle_info("[color=yellow][战斗系统][/color] {0} 的回合结束".format([character_name]))

func _handle_round_end_state() -> void:
	_log_battle_info("[color=yellow][战斗系统][/color] 第 {0} 回合结束".format([current_turn_count]))
	state_manager.change_state(BattleStateManager.BattleState.ROUND_START)

func _handle_victory_state() -> void:
	_log_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
	battle_ended.emit(true)

func _handle_defeat_state() -> void:
	_log_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
	battle_ended.emit(false)
#endregion

#region 信号处理
## 状态改变处理函数
## [param _previous_state] 上一个状态
## [param new_state] 新状态
func _on_state_changed(_previous_state: BattleStateManager.BattleState, new_state: BattleStateManager.BattleState) -> void:
	var all_characters: Array[Node] = character_registry.get_all_characters()

	if new_state == BattleState.START:
		_handle_start_state()
	elif new_state == BattleState.ROUND_START:
		_handle_round_start_state()
	elif new_state == BattleState.TURN_START:
		_handle_turn_start_state()
	elif new_state == BattleState.TURN_END:
		_handle_turn_end_state()
	elif new_state == BattleState.ROUND_END:
		_handle_round_end_state()
	elif new_state == BattleState.VICTORY:
		_handle_victory_state()
	elif new_state == BattleState.DEFEAT:
		_handle_defeat_state()

func _on_character_registered(character: Node) -> void:
	var character_name : String = character.get_character_name() if character.has_method("get_character_name") else "Unknown"
	_log_battle_info("[color=green][b]{0}[/b][/color] 已注册到战斗中".format([character_name]))
	if not character.has_method("initialize"):
		push_error("角色没有初始化方法！")
		return
	character.initialize(self, cast_marker)

func _on_character_unregistered(character: Node) -> void:
	var character_name : String = character.get_character_name() if character.has_method("get_character_name") else "Unknown"
	_log_battle_info("[color=red][b]{0}[/b][/color] 已从战斗中移除".format([character_name]))

func _on_team_changed(team_characters: Array[Node], team_id: BattleCharacterRegistryManager.TeamType) -> void:
	var team_name : String = "玩家" if team_id == BattleCharacterRegistryManager.TeamType.PLAYER else "敌人"
	_log_battle_info("队伍 [color=green][b] {0} [/b][/color] 已改变".format([team_name]))

func _on_player_victory() -> void:
	_log_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
	state_manager.change_state(BattleStateManager.BattleState.VICTORY)

func _on_player_defeat() -> void:
	_log_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
	state_manager.change_state(BattleStateManager.BattleState.DEFEAT)

func _on_character_defeated(character: Node) -> void:
	var character_name : String = character.get_character_name() if character.has_method("get_character_name") else "Unknown"
	print("Character %s defeated, attempting to unregister." % character_name)
	_check_battle_end_condition()
#endregion
