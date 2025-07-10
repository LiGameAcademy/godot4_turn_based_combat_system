extends Node
class_name BattleManager

## 战斗管理器-全局单例
## 负责管理战斗的流程和状态

## 状态管理器
@onready var state_manager: BattleStateManager = %BattleStateManager
@onready var battle_visual_effects: BattleVisualEffects = %BattleVisualEffects
@onready var battle_character_registry_manager: BattleCharacterRegistryManager = %BattleCharacterRegistryManager
@onready var turn_order_manager: TurnOrderManager = %TurnOrderManager
@onready var combat_rule_manager: CombatRuleManager = %CombatRuleManager

# 回合顺序管理
var turn_queue: Array = []:								## 回合队列
	get:
		return turn_order_manager.turn_queue
	set(_value):
		push_error("cannot set turn_queue becouse its readonly!")

var current_turn_character: Character = null:			## 当前行动者
	get:
		return turn_order_manager.current_character
	set(_value):
		push_error("cannot set current_turn_character becouse its readonly!")
var is_player_turn : bool = false :						## 是否是玩家回合
	get:
		return state_manager.current_state == BattleStateManager.BattleState.PLAYER_TURN
	set(_value):
		push_error("cannot set is_player_turn becouse its readonly!")
var characters : Array[Character]:
	get:
		return battle_character_registry_manager.get_all_characters()
var current_turn_index: int :
	get:
		return turn_order_manager.current_turn_index

## 信号
signal turn_changed(character: Character)						## 当前行动者改变时触发
signal battle_ended(is_victory: bool)							## 战斗结束时触发
signal battle_info_logged(text: String)							## 战斗日志记录时触发
## 敌人行动执行时触发
signal enemy_action_executed(source: Character, target: Character, damage: float)	

func _ready() -> void:
	battle_character_registry_manager.initialize()
	battle_character_registry_manager.character_registered.connect(_on_character_registered)
	battle_character_registry_manager.character_unregistered.connect(_on_character_unregistered)
	battle_character_registry_manager.team_changed.connect(_on_team_changed)

	combat_rule_manager.initialize(battle_character_registry_manager)
	combat_rule_manager.player_victory.connect(_on_player_victory)
	combat_rule_manager.player_defeat.connect(_on_player_defeat)

	turn_order_manager.initialize(battle_character_registry_manager)
	turn_order_manager.turn_changed.connect(_on_turn_changed)
	turn_order_manager.round_ended.connect(_on_round_ended)

	state_manager.state_changed.connect(_on_state_changed)
	SkillSystem.battle_manager = self
	state_manager.initialize(BattleStateManager.BattleState.IDLE)

## 开始战斗
func start_battle() -> void:
	_log_battle_info("[color=yellow][b]===== 战斗开始! =====[/b][/color]")
	
	var player_characters = battle_character_registry_manager.get_player_team(true)
	if player_characters.is_empty():
		push_error("无法开始战斗：缺少玩家!")
		return
	var enemy_characters = battle_character_registry_manager.get_enemy_team(true)
	if enemy_characters.is_empty():
		push_error("无法开始战斗：缺少敌人!")
		return
	state_manager.change_state(BattleStateManager.BattleState.START)

## 玩家选择行动 - 由BattleScene调用
## [param action_type] 行动类型
## [param target] 目标角色
## [param params] 行动参数
func player_select_action(
		action_type: CharacterCombatComponent.ActionType, 
		target: Character = null, 
		params: Dictionary = {}
		) -> void:
	if not state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		_log_battle_info("[color=red]当前不是玩家回合，无法选择行动![/color]")
		return
		
	_log_battle_info("[color=cyan]玩家选择行动: %s[/color]" % action_type)
	
	params.merge({"skill_context": SkillExecutionContext.new(self)}, true)
	current_turn_character.execute_action(action_type, target, params)

	# 检查战斗是否结束
	if _check_battle_end_condition():
		return # 战斗已结束
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

## 执行敌人AI
func execute_enemy_ai() -> void:
	var character : Character = current_turn_character
	if not is_instance_valid(character):
		push_error("当前行动者不存在！")
		return

	# 检查角色是否有AI组件
	var ai_component = character.get_ai_component()
	if not ai_component:
		push_error("敌人没有AI组件！")
		# 简单的AI逻辑：总是攻击第一个存活的玩家角色
		var target = null
		for player in battle_character_registry_manager.get_player_team(true):
			if player.current_hp > 0:
				target = player
				break
		if target:
			_log_battle_info("[color=orange][b]{0}[/b][/color] 选择攻击 [color=blue][b]{1}[/b][/color]".format([current_turn_character.character_name, target.character_name]))
			current_turn_character.execute_action(
				CharacterCombatComponent.ActionType.ATTACK, 
				target, 
				{
					"skill_context": SkillExecutionContext.new(self)
				})
		else:
			_log_battle_info("[color=red][错误][/color] 敌人找不到可攻击的目标")
	else:
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

## 检查战斗结束条件
## [return] 战斗是否结束
func _check_battle_end_condition() -> bool:
	# 检查玩家是否全部阵亡
	return combat_rule_manager.check_battle_end_conditions()

## 添加角色
func add_character(character: Character, is_player: bool = true) -> void:
	battle_character_registry_manager.register_character(character, is_player)
	
## 移除角色
## [param character] 角色
func remove_character(character: Character) -> void:
	battle_character_registry_manager.unregister_character(character)		
	_check_battle_end_condition()

## 获取有效的敌方目标列表（过滤掉已倒下的角色）
## [param caster] 施法者
## [return] 有效的敌方目标列表
func get_valid_enemy_targets(caster : Character = null) -> Array[Character]:
	if is_instance_valid(caster):
		return battle_character_registry_manager.get_opposing_team_for_character(caster)
	return battle_character_registry_manager.get_opposing_team_for_character(current_turn_character)

## 获取有效的友方目标列表
## [param include_self] 是否包括施法者自己
## [param caster] 施法者
## [return] 有效的友方目标列表
func get_valid_ally_targets(include_self: bool = false, caster : Character = null) -> Array[Character]:
	if is_instance_valid(caster):
		return battle_character_registry_manager.get_allied_team_for_character(caster, include_self)
	return battle_character_registry_manager.get_allied_team_for_character(current_turn_character, include_self)

func is_enemy(character1: Character, character2: Character) -> bool:
	return battle_character_registry_manager.is_enemy_of(character1, character2)

## 构建回合队列
func _build_turn_queue() -> void:
	turn_order_manager.build_queue()
	_log_battle_info("[color=yellow][战斗系统][/color] 回合队列已建立: [color=green][b]{0}[/b][/color] 个角色".format([turn_queue.size()]))

## 战斗日志
## [param text] 日志文本
func _log_battle_info(text: String) -> void:
	print_rich(text)
	battle_info_logged.emit(text)

#region 视觉反馈
## 状态效果应用视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_status_effect(target: Character, params: Dictionary = {}) -> void:
	battle_visual_effects.play_status_effect(target, params)
	
## 播放施法效果
## [param target] 目标角色
## [param params] 参数
func _play_cast_effect(_target: Character, _params: Dictionary = {}) -> void:
	battle_visual_effects.play_cast_effect(_target, _params)

## 播放治疗施法效果
## [param target] 目标角色
## [param params] 参数
func _play_heal_cast_effect(_target: Character, _params: Dictionary = {}) -> void:
	if battle_visual_effects.has_method("play_heal_cast_effect"):
		battle_visual_effects.play_heal_cast_effect(_target, _params)

## 治疗效果视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_heal_effect(target: Character, _params : Dictionary = {}) -> void:
	battle_visual_effects.play_heal_effect(target, _params)
	
## 受击效果视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_hit_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

## 状态效果应用成功视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_status_applied_success_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

## 受击数字效果
## [param target] 目标角色
## [param params] 参数
func _play_damage_number_effect(_target: Character, _params: Dictionary = {}) -> void:
	var damage : float = _params.get("damage", 0)
	var color : Color = _params.get("color", Color.RED)
	var prefix : String = _params.get("prefix", "")
	_target.spawn_damage_number(damage, color, prefix)

#endregion

#region 信号处理

## 角色死亡信号处理函数
## [param character] 角色
func _on_character_died(character: Character) -> void:
	print_rich("[color=purple]" + character.character_name + " 已被击败![/color]")

	# 从回合队列中移除
	if turn_queue.has(character):
		turn_queue.erase(character)
	
	# 如果当前行动者死亡，需要特殊处理
	if current_turn_character == character:
		print("当前行动者 " + character.character_name + " 已阵亡。")
	
	# 检查战斗是否结束
	_check_battle_end_condition()	

## 状态改变处理函数
## [param _previous_state] 上一个状态
## [param new_state] 新状态
func _on_state_changed(
		_previous_state: BattleStateManager.BattleState, 
		new_state: BattleStateManager.BattleState) -> void:
	# 所有状态下的动作逻辑都在这里
	match new_state:
		BattleStateManager.BattleState.START:
			state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
		BattleStateManager.BattleState.ROUND_START:
			# 大回合开始，构建回合队列
			_log_battle_info("[color=yellow][战斗系统][/color] 新的回合开始")
			combat_rule_manager.add_turn_count()
			if _check_battle_end_condition():
				# 战斗已结束，状态已在_check_battle_end_condition中切换
				return
				
			_build_turn_queue()
			if turn_queue.is_empty():
				state_manager.change_state(BattleStateManager.BattleState.DEFEAT)
			else:
				state_manager.change_state(BattleStateManager.BattleState.TURN_START)
				
		BattleStateManager.BattleState.TURN_START:
			# 小回合开始，确定当前行动角色
			current_turn_character = turn_order_manager.get_next_character()
		BattleStateManager.BattleState.PLAYER_TURN:
			pass
						
		BattleStateManager.BattleState.ENEMY_TURN:
			await get_tree().create_timer(1.0).timeout
			execute_enemy_ai()
			
		BattleStateManager.BattleState.TURN_END:
			# 小回合结束，检查战斗状态
			if _check_battle_end_condition():
				# 战斗已结束，状态已在_check_battle_end_condition中切换
				return
			current_turn_character.on_turn_end(self)
			# 进入下一个角色的回合
			state_manager.change_state(BattleStateManager.BattleState.TURN_START)
			
		BattleStateManager.BattleState.ROUND_END:
			# 大回合结束，进入新的回合
			_log_battle_info("[color=yellow][战斗系统][/color] 回合结束")
			state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
		BattleStateManager.BattleState.VICTORY:
			_log_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
			battle_ended.emit(true)
		BattleStateManager.BattleState.DEFEAT:
			_log_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
			battle_ended.emit(false)

func _on_character_registered(character: Character) -> void:
	_log_battle_info("[color=green][b]{0}[/b][/color] 已注册到战斗中".format([character.character_name]))
	character.initialize(self)

func _on_character_unregistered(character: Character) -> void:
	_log_battle_info("[color=red][b]{0}[/b][/color] 已从战斗中移除".format([character.character_name]))

func _on_team_changed(team_characters: Array[Character], team_id: String) -> void:
	print_rich("[color=yellow][b]{0}[/b][/color] 队伍 [color=green][b]{1}[/b][/color] 已改变".format([team_characters, team_id]))

func _on_player_victory() -> void:
	_log_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
	state_manager.change_state(BattleStateManager.BattleState.VICTORY)

func _on_player_defeat() -> void:
	_log_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
	state_manager.change_state(BattleStateManager.BattleState.DEFEAT)

func _on_turn_changed(character: Character) -> void:
	_log_battle_info("[color=cyan][回合][/color] [color=orange][b]{0}[/b][/color] 的回合开始".format([character.character_name]))
	character.on_turn_start(self)

	# 检查角色能否行动
	if not character.can_action:
		_log_battle_info("[color=red][错误][/color] 角色无法行动, 跳过回合")
		state_manager.change_state(BattleStateManager.BattleState.TURN_END)
		return

	# 根据角色类型决定下一个状态
	var is_player = battle_character_registry_manager.is_player_character(character)
	var next_state = BattleStateManager.BattleState.PLAYER_TURN if is_player else BattleStateManager.BattleState.ENEMY_TURN
	state_manager.change_state(next_state)
	turn_changed.emit(character) # 通知UI

func _on_round_ended() -> void:
	_log_battle_info("[color=yellow][战斗系统][/color] 回合结束")
	state_manager.change_state(BattleStateManager.BattleState.ROUND_END)

#endregion
