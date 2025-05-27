extends Node
class_name BattleManager

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

# 核心系统引用
var character_registry: BattleCharacterRegistryManager		## 角色注册管理器
var state_manager: BattleStateManager
var visual_effects: BattleVisualEffects
var combat_rules: CombatRuleManager
var turn_order_manager: TurnOrderManager					## 回合顺序管理器

## 当前选中的技能
var current_selected_skill : SkillData = null

var effect_processors = {}		## 效果处理器

# 信号
signal turn_changed(character)
signal battle_ended(is_victory)
# 添加额外信号用于与UI交互
signal player_action_required(character) # 通知UI玩家需要行动
signal enemy_action_executed(attacker, target, damage) # 敌人执行了行动

func _ready():
	_init_core_systems()
	
	# 订阅SkillSystem的视觉效果请求信号
	SkillSystem.visual_effect_requested.connect(_on_visual_effect_requested)
	
	_start_battle()

## 获取友方目标
func get_valid_ally_targets(caster: Character, include_self: bool) -> Array[Character]:
	var skill_context := SkillSystem.SkillExecutionContext.new(
		character_registry,
		visual_effects,
	)
	return SkillSystem.get_valid_ally_targets(skill_context, caster, include_self)

## 获取敌方目标
func get_valid_enemy_targets(caster: Character) -> Array[Character]:
	var skill_context := SkillSystem.SkillExecutionContext.new(
		character_registry,
		visual_effects,
	)
	return SkillSystem.get_valid_enemy_targets(skill_context, caster)

## 执行动作
## [param action_type] 动作类型
## [param source] 动作执行者
## [param target] 动作目标
## [param params] 额外参数（如技能数据、道具数据等）
## [return] 动作执行结果
func execute_action(action_type: CharacterCombatComponent.ActionType, source: Character, target = null, params = null) -> Dictionary:
	if not is_instance_valid(source):
		push_error("无效的动作执行者")
		return {"success": false, "error": "无效的动作执行者"}

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
			_execute_enemy_ai()
			
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
			# 这部分通常在选择行动后直接调用execute_action
			print("执行选择的行动...")
			
			# TODO: 实现execute_action逻辑

# 注册战斗场景中的角色
func _register_characters() -> void:
	# 查找战斗场景中的所有角色
	var player_area = get_node_or_null("../PlayerArea")
	var enemy_area = get_node_or_null("../EnemyArea")
	
	if player_area:
		for child in player_area.get_children():
			if child is Character:
				character_registry.register_character(child, true)
				_subscribe_to_character_signals(child)
	
	if enemy_area:
		for child in enemy_area.get_children():
			if child is Character:
				character_registry.register_character(child, false)
				_subscribe_to_character_signals(child)
	
	print("已注册 ", character_registry.get_player_team(true).size(), " 名玩家角色和 ", character_registry.get_enemy_team(false).size(), " 名敌人")

# 开始战斗
func _start_battle() -> void:
	print("战斗开始!")

	# 自动查找并注册战斗场景中的角色
	_register_characters()
	
	if character_registry.get_player_team(true).is_empty() or character_registry.get_enemy_team(false).is_empty():
		push_error("无法开始战斗：缺少玩家或敌人!")
		return
	
	state_manager.change_state(BattleStateManager.BattleState.BATTLE_START)

## 订阅角色信号
func _subscribe_to_character_signals(character : Character) -> void:
	if not character.character_defeated.is_connected(_on_character_defeated):
		character.character_defeated.connect(_on_character_defeated)
	#TODO 链接其他信号

# 角色死亡信号处理函数
func _on_character_defeated(character: Character) -> void:
	print_rich("[color=purple]" + character.character_name + " 已被击败![/color]")
	# 检查战斗是否结束
	combat_rules.check_battle_end_conditions()

# 下一个回合
func _next_turn() -> void:
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
	
	# 回合开始时重置防御状态
	next_character.reset_turn_flags()
	next_character.combat_component.on_turn_start()
	# 判断是玩家还是敌人的回合
	if character_registry.is_player_character(next_character):
		state_manager.change_state(BattleStateManager.BattleState.PLAYER_TURN)
	else:
		state_manager.change_state(BattleStateManager.BattleState.ENEMY_TURN)

# 执行敌人AI
func _execute_enemy_ai() -> void:
	var enemy_character = turn_order_manager.current_character
	if not enemy_character or character_registry.is_player_character(enemy_character):
		push_error("Invalid enemy character for AI execution")
		return
	
	# 简单AI：随机选择一个玩家角色攻击
	var valid_targets = get_valid_enemy_targets(enemy_character)
	if valid_targets.is_empty():
		print("敌人没有有效目标，跳过行动")
		state_manager.change_state(BattleStateManager.BattleState.ROUND_END)
		return
	
	# 随机选择一个目标
	var target = valid_targets[randi() % valid_targets.size()]
	
	# 执行基本攻击
	state_manager.change_state(BattleStateManager.BattleState.ACTION_EXECUTION)
	var result = await execute_action(CharacterCombatComponent.ActionType.ATTACK, enemy_character, target)
	var damage = result.get("damage", 0)
	
	# 发送敌人行动执行信号
	enemy_action_executed.emit(enemy_character, target, damage)
	
	# 等待一段时间后结束回合
	await get_tree().create_timer(1.0).timeout
	state_manager.change_state(BattleStateManager.BattleState.ROUND_END)

## 更新当前角色的回合结束状态
func _update_current_character_turn_end() -> void:
	var current_character = turn_order_manager.current_character
	if is_instance_valid(current_character) and current_character.combat_component:
		print_rich("[color=yellow]更新角色 %s 的状态持续时间[/color]" % current_character.character_name)
		await current_character.combat_component.on_turn_end()
