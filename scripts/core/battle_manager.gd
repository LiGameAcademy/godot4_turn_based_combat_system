extends Node
class_name BattleManager

const CHARACTER = preload("res://scenes/characters/character.tscn")
const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

# 核心系统引用
var character_registry: BattleCharacterRegistryManager		## 角色注册管理器
var state_manager: BattleStateManager
var visual_effects: BattleVisualEffects
var combat_rules: CombatRuleManager
var turn_order_manager: TurnOrderManager					## 回合顺序管理器

var current_selected_skill : SkillData = null				## 当前选中的技能
var effect_processors = {}									## 效果处理器

## 最大回合数限制，0表示无限制
var max_turn_count: int = 0

## 当前回合数
var current_turn_count: int = 0

# 信号
signal turn_changed(character)								## 回合变化
signal battle_ended(is_victory)								## 战斗结束
signal player_action_required(character)					## 通知UI玩家需要行动
signal enemy_action_executed(attacker, target, damage)		## 敌人执行了行动

func _ready():
	_init_core_systems()
	# 订阅SkillSystem的视觉效果请求信号
	SkillSystem.visual_effect_requested.connect(_on_visual_effect_requested)

#region --- 获取目标 ---
## 获取友方角色的合法目标
## [param caster] 技能施放者
## [param include_self] 是否包含施放者自己
## [return] 可以作为目标的友方角色列表
func get_valid_ally_targets(caster: Character, include_self: bool) -> Array[Character]:
	var skill_context := SkillSystem.SkillExecutionContext.new(
		character_registry,
		visual_effects,
	)
	return SkillSystem.get_valid_ally_targets(skill_context, caster, include_self)

## 获取敌方角色的合法目标
## [param caster] 技能施放者
## [return] 可以作为目标的敌方角色列表
func get_valid_enemy_targets(caster: Character) -> Array[Character]:
	var skill_context := SkillSystem.SkillExecutionContext.new(
		character_registry,
		visual_effects,
	)
	return SkillSystem.get_valid_enemy_targets(skill_context, caster)

## 玩家选择行动 - 由BattleScene调用
## [param action_type] 动作类型
## [param target] 动作目标
## [param params] 额外参数
func player_select_action(
		action_type: CharacterCombatComponent.ActionType, 
		target: Character = null, 
		params: Dictionary = {}) -> void:
	if not state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		return
		
	print_rich("[color=cyan]玩家选择行动: %s[/color]" % action_type)
	
	# 设置为行动执行状态
	state_manager.change_state(BattleStateManager.BattleState.ACTION_EXECUTION)

	var source : Character = turn_order_manager.current_character
	_execute_action(action_type, source, target, params)
	
	# 行动结束后转入回合结束
	state_manager.change_state(BattleStateManager.BattleState.ROUND_END)

#endregion

#region --- 执行敌人AI ---
## 执行敌人回合
func _execute_enemy_turn() -> void:
	# 获取当前行动角色
	var enemy_character : Character = turn_order_manager.current_character
	if not is_instance_valid(enemy_character):
		print("ERROR: 无效的敌人角色")
		state_manager.change_state(BattleStateManager.BattleState.ROUND_END)
		return
	
	# 检查角色是否有AI组件
	var ai_component = enemy_character.ai_component
	if not ai_component:
		print_rich("[color=orange]角色没有AI组件，使用默认攻击[/color]")
		# 执行默认攻击
		state_manager.change_state(BattleStateManager.BattleState.ACTION_EXECUTION)
		var result = await _execute_action(
			CharacterCombatComponent.ActionType.ATTACK, 
			enemy_character, 
			_get_default_target(enemy_character), 
			{}
		)
		var damage = result.get("damage", 0)
		enemy_action_executed.emit(enemy_character, _get_default_target(enemy_character), damage)
	else:
		# 执行AI行动
		state_manager.change_state(BattleStateManager.BattleState.ACTION_EXECUTION)
		var action_result = await ai_component.execute_action()
		
		# 如果AI无法决策或执行失败，直接结束回合
		if not action_result or not action_result.is_valid:
			print_rich("[color=orange]AI行动失败，跳过回合[/color]")
		else:
			# 发送敌人行动执行信号
			enemy_action_executed.emit(action_result.source, action_result.target, action_result.damage)
	
	# 等待一段时间后结束回合
	await get_tree().create_timer(1.0).timeout
	state_manager.change_state(BattleStateManager.BattleState.ROUND_END)

## 获取默认目标（当AI组件不可用时）
func _get_default_target(source_character: Character) -> Character:
	# 获取敌人列表
	var enemies = []
	for character in character_registry.get_all_characters():
		if character_registry.is_enemy_of(source_character, character):
			enemies.append(character)
	
	# 如果有敌人，选择第一个
	if not enemies.is_empty():
		return enemies[0]
	
	# 如果没有敌人，返回自己（应该不会发生）
	return source_character

#endregion

#region --- 注册角色 ---
## 创建角色
func create_character(character_data: CharacterData, position: Vector2, is_player: bool) -> Character:
	# 实例化角色
	var character : Character = CHARACTER.instantiate()
	if not character:
		push_error("BattleManager: 无法实例化角色")
		return null
	
	# 设置角色数据
	character.setup(character_data)
	character.is_player = is_player
	
	# 添加到适当的区域
	var parent_node = get_node("../PlayerArea") if is_player else get_node("../EnemyArea")
	if parent_node:
		parent_node.add_child(character)
		
		# 注册角色
		character_registry.register_character(character, is_player)
		_subscribe_to_character_signals(character)
	
		# 设置角色位置
		character.global_position = position
		character.initialize(self)
		return character
	else:
		push_error("BattleManager: 找不到角色区域节点")
		character.queue_free()
		return null

## 设置战斗
func setup_battle(
		player_characters: Array[Character], 
		enemy_characters: Array[Character]) -> void:
	# 重置战斗状态
	_reset()
	
	# 注册角色
	for character in player_characters:
		character_registry.register_character(character, true)
		_subscribe_to_character_signals(character)
	
	for character in enemy_characters:
		character_registry.register_character(character, false)
		_subscribe_to_character_signals(character)
	
	print("已注册 ", character_registry.get_player_team(true).size(), " 名玩家角色和 ", character_registry.get_enemy_team(false).size(), " 名敌人")
	_start_battle()

## 重置战斗状态
func _reset() -> void:
	# 重置战斗状态
	#state_manager.reset()
	
	# 清除所有注册的角色
	#character_registry.clear()s
	
	# 重置回合顺序管理器
	#if turn_order_manager:
		#turn_order_manager.reset()
	
	# 重置当前技能
	current_selected_skill = null
	
	# 重置回合计数
	current_turn_count = 0

## 开始战斗
func _start_battle() -> void:
	print("战斗开始!")
	
	if character_registry.get_player_team(true).is_empty() or character_registry.get_enemy_team(false).is_empty():
		push_error("无法开始战斗：缺少玩家或敌人!")
		return
	
	state_manager.change_state(BattleStateManager.BattleState.BATTLE_START)

## 订阅角色信号
func _subscribe_to_character_signals(character : Character) -> void:
	if not character:
		return
	if not character.character_defeated.is_connected(_on_character_defeated):
		character.character_defeated.connect(_on_character_defeated)
	#TODO 链接其他信号

## 获取所有角色
func get_all_characters() -> Array[Character]:
	return character_registry.get_all_characters()

## 获取玩家队伍
func get_player_team() -> Array[Character]:
	return character_registry.get_player_team(true)

## 获取敌人队伍
func get_enemy_team() -> Array[Character]:
	return character_registry.get_enemy_team(false)

## 下一个回合
func _next_turn() -> void:
	# 更新回合计数
	current_turn_count += 1
	
	# 检查是否超过最大回合数
	if max_turn_count > 0 and current_turn_count > max_turn_count:
		print_rich("[color=red]超过最大回合数 %d，战斗失败[/color]" % max_turn_count)
		# 触发战斗结束信号，失败
		battle_ended.emit(false)
		state_manager.change_state(BattleStateManager.BattleState.DEFEAT)
		return
	
	var next_character = turn_order_manager.get_next_character()
	
	if not next_character:
		print("回合结束，重新构建回合顺序")
		turn_order_manager.build_queue()
		next_character = turn_order_manager.get_next_character()
		
	if not next_character:
		print("没有可行动的角色")
		combat_rules.check_battle_end_conditions()
		return
	
	turn_changed.emit(next_character)
	
	print(next_character.character_name, " 的回合")
	
	# 检查角色是否可以行动（是否被眼晕或其他状态限制）
	if not _can_character_act(next_character):
		print_rich("[color=orange]%s 无法行动，自动跳过回合[/color]" % next_character.character_name)
		# 先更新角色的回合结束状态
		turn_order_manager.current_character = next_character
		await _update_current_character_turn_end()
		# 然后进入下一个角色的回合
		_next_turn()
		return
	
	# 判断是玩家还是敌人的回合
	if character_registry.is_player_character(next_character):
		state_manager.change_state(BattleStateManager.BattleState.PLAYER_TURN)
	else:
		state_manager.change_state(BattleStateManager.BattleState.ENEMY_TURN)

## 检查角色是否可以行动
func _can_character_act(character: Character) -> bool:
	if not is_instance_valid(character) or not character.combat_component or not character.skill_component:
		return false
	
	# 检查角色是否可以执行任何动作
	var restricted_tags = character.skill_component.get_restricted_action_tags()
	return not restricted_tags.has(&"any_action")

## 更新当前角色的回合结束状态
func _update_current_character_turn_end() -> void:
	var current_character = turn_order_manager.current_character
	if is_instance_valid(current_character) and current_character.combat_component:
		print_rich("[color=yellow]更新角色 %s 的状态持续时间[/color]" % current_character.character_name)
		await current_character.combat_component.on_turn_end()

## 执行动作
## [param action_type] 动作类型
## [param source] 动作执行者
## [param target] 动作目标
## [param params] 额外参数（如技能数据、道具数据等）
## [return] 动作执行结果
func _execute_action(
		action_type: CharacterCombatComponent.ActionType, 
		source: Character, 
		target : Character = null, 
		params : Dictionary = {}) -> Dictionary:
	if not is_instance_valid(source):
		push_error("无效的动作执行者")
		return {"success": false, "error": "无效的动作执行者"}
	
	if not source.combat_component:
		push_error("角色缺少战斗组件")
		return {"success": false, "error": "角色缺少战斗组件"}
	
	params.skill_context = SkillSystem.SkillExecutionContext.new(character_registry, visual_effects)
	# 调用角色战斗组件的执行动作方法
	var result = await source.execute_action(action_type, target, params)
	
	# 检查战斗是否结束
	combat_rules.check_battle_end_conditions()
	
	return result

## 初始化核心系统
func _init_core_systems() -> void:
	# 初始化各个核心系统
	character_registry = BattleCharacterRegistryManager.new()
	state_manager = BattleStateManager.new()
	visual_effects = BattleVisualEffects.new()
	turn_order_manager = TurnOrderManager.new()
	combat_rules = CombatRuleManager.new()
	
	# 添加到场景树
	add_child(character_registry)
	add_child(state_manager)
	add_child(visual_effects)
	add_child(turn_order_manager)
	add_child(combat_rules)
	
	# 订阅信号
	state_manager.state_changed.connect(_on_battle_state_changed)
	turn_order_manager.turn_changed.connect(_on_turn_order_changed)
	
	# 设置名称
	character_registry.name = "BattleCharacterRegistryManager"
	state_manager.name = "BattleStateManager"
	visual_effects.name = "VisualEffectsHandler"
	turn_order_manager.name = "TurnOrderManager"
	combat_rules.name = "CombatRuleManager"
	
	# 初始化
	character_registry.initialize()
	turn_order_manager.initialize(character_registry)
	# 初始化战斗规则管理器
	combat_rules.initialize(character_registry)
	visual_effects.initialize(DAMAGE_NUMBER_SCENE)
	character_registry.character_registered.connect(_on_character_registered)

#endregion

#region --- 角色注册处理 ---
## 角色注册处理
## [param character] 注册的角色
func _on_character_registered(character: Character) -> void:
	character.initialize(self)

## 角色死亡信号处理函数
func _on_character_defeated(character: Character) -> void:
	print_rich("[color=purple]" + character.character_name + " 已被击败![/color]")
	# 检查战斗是否结束
	combat_rules.check_battle_end_conditions()

# 处理战斗状态变化
## 处理视觉效果请求
## [param effect_type] 效果类型
## [param target] 目标节点
## [param params] 参数字典
func _on_visual_effect_requested(effect_type: StringName, target: Node, params: Dictionary) -> void:
	if not visual_effects or not is_instance_valid(target):
		return
	
	# 根据效果类型调用相应的视觉效果方法
	match effect_type:
		&"damage":
			visual_effects.show_normal_damage(target, params)
		&"effective_hit":
			visual_effects.show_effective_hit(target, params)
		&"ineffective_hit":
			visual_effects.show_ineffective_hit(target, params)
		&"damage_number":
			visual_effects.show_damage_number(
				target, 
				params.get("damage", 0), 
				false, 
				params.get("color", Color.RED), 
				params.get("prefix", ""),
				Vector2(0, 50) # 默认偏移
			)
		&"heal":
			visual_effects.show_heal_number(target, params.get("amount", 0))
		&"status":
			visual_effects.show_status_text(target, params.get("text", "Status"), params.get("is_positive", true))
		# &"hit":
		# 	if target is Character and target.has_method("play_animation"):
		# 		target.play_animation("hit")
		# &"cast":
		# 	if target is Character and target.has_method("play_animation"):
		# 		target.play_animation("skill")
		_:
			push_warning("BattleManager: 未知的视觉效果类型: %s" % effect_type)

## 处理回合顺序变化
## [param character] 当前回合角色
func _on_turn_order_changed(character: Character) -> void:
	# 处理回合变化
	print("Turn changed to: %s" % character.character_name)
	turn_changed.emit(character)
	
	# 如果是玩家角色，通知UI玩家需要行动
	if character_registry.is_player_character(character):
		state_manager.change_state(BattleStateManager.BattleState.PLAYER_TURN)
	else:
		# 如果是敌人，转到敌人回合状态
		state_manager.change_state(BattleStateManager.BattleState.ENEMY_TURN)

## 处理战斗状态变化
## [param old_state] 旧状态
## [param new_state] 新状态
func _on_battle_state_changed(old_state, new_state):
	print("战斗状态变化: ", state_manager.get_state_name(old_state), " -> ", state_manager.get_state_name(new_state))
	
	match new_state:
		BattleStateManager.BattleState.BATTLE_START:
			print("战斗开始初始化...")
			# 战斗初始化
			turn_order_manager.build_queue()
			await get_tree().create_timer(1.0).timeout
			state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
			
		BattleStateManager.BattleState.ROUND_START:
			print("回合开始...")
			# 回合开始处理，确定行动者
			_next_turn()
			#TODO 重置当前回合角色标记
			
		BattleStateManager.BattleState.PLAYER_TURN:
			# 通知UI需要玩家输入
			print("玩家回合：等待输入...")
			player_action_required.emit(turn_order_manager.current_character)
		
		BattleStateManager.BattleState.ENEMY_TURN:
			# 执行敌人AI
			print("敌人回合：", turn_order_manager.current_character.character_name, " 思考中...")
			# 延迟一下再执行AI，避免敌人行动过快
			await get_tree().create_timer(1.0).timeout
			await _execute_enemy_turn()
			
		BattleStateManager.BattleState.ROUND_END:
			print("回合结束...")
			# 处理回合结束效果
			await get_tree().create_timer(0.5).timeout
			
			# 调用当前角色的回合结束方法，更新状态效果持续时间
			await _update_current_character_turn_end()
			
			# 检查战斗是否结束
			var is_battle_ended = combat_rules.check_battle_end_conditions()
			if is_battle_ended:
				state_manager.change_state(BattleStateManager.BattleState.VICTORY if character_registry.is_team_defeated(false) else BattleStateManager.BattleState.DEFEAT)
			else:
				state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
			
		BattleStateManager.BattleState.VICTORY:
			print("胜利!")
			# 处理胜利后的逻辑
			battle_ended.emit(true)

		BattleStateManager.BattleState.DEFEAT:
			print("失败!")
			# 处理失败后的逻辑
			battle_ended.emit(false)
			
		BattleStateManager.BattleState.ACTION_EXECUTION:
			# 执行选择的行动
			# 这部分通常在选择行动后直接调用_execute_action
			print("执行选择的行动...")
			
			# TODO: 实现_execute_action逻辑
#endregion
