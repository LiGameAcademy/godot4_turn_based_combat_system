extends Node
class_name BattleManager

# 战斗状态枚举
enum BattleState {
	IDLE,           				# 战斗未开始或已结束的空闲状态
	BATTLE_START,   				# 战斗初始化阶段
	ROUND_START,    				# 回合开始，处理回合初效果，决定行动者
	PLAYER_TURN,    				# 等待玩家输入并执行玩家行动
	ENEMY_TURN,     				# AI 决定并执行敌人行动
	ACTION_EXECUTION, 				# 正在执行某个角色的具体行动
	ROUND_END,      				# 回合结束，处理回合末效果，检查胜负
	VICTORY,        				# 战斗胜利
	DEFEAT          				# 战斗失败
}

# 当前战斗状态
var current_state: BattleState = BattleState.IDLE

# 战斗参与者
var player_characters: Array[Character] = []
var enemy_characters: Array[Character] = []

# 回合顺序管理
var turn_queue: Array = []
var current_turn_character: Character = null

# 技能系统和视觉效果系统
var skill_system: SkillSystem
var visual_effects: BattleVisualEffects

# 信号
signal battle_state_changed(new_state)
signal turn_changed(character)
signal battle_ended(is_victory)
# 添加额外信号用于与UI交互
signal player_action_required(character) # 通知UI玩家需要行动
signal enemy_action_executed(attacker, target, damage) # 敌人执行了行动
#signal character_stats_changed(character) # 角色状态变化

func _ready():
	# 创建视觉效果系统
	visual_effects = BattleVisualEffects.new()
	add_child(visual_effects)
	
	# 创建技能系统
	skill_system = SkillSystem.new(self, visual_effects)
	add_child(skill_system)
	
	# 连接技能系统信号
	skill_system.skill_executed.connect(_on_skill_executed)
	
	# 设置初始状态
	_set_state(BattleState.IDLE)

# 开始战斗
func start_battle():
	print("战斗开始!")

	# 清空角色列表
	player_characters.clear()
	enemy_characters.clear()

	# 自动查找并注册战斗场景中的角色
	register_characters()
	
	if player_characters.is_empty() or enemy_characters.is_empty():
		push_error("无法开始战斗：缺少玩家或敌人!")
		return
	
	_set_state(BattleState.BATTLE_START)

# 注册战斗场景中的角色
func register_characters():
	# 查找战斗场景中的所有角色
	var player_area = get_node_or_null("../PlayerArea")
	var enemy_area = get_node_or_null("../EnemyArea")
	
	if player_area:
		for child in player_area.get_children():
			if child is Character:
				add_player_character(child)
				_subscribe_to_character_signals(child)
	
	if enemy_area:
		for child in enemy_area.get_children():
			if child is Character:
				add_enemy_character(child)
				_subscribe_to_character_signals(child)
	
	print("已注册 ", player_characters.size(), " 名玩家角色和 ", enemy_characters.size(), " 名敌人")

# 玩家选择行动 - 由BattleScene调用
func player_select_action(action_type: String, target = null):
	if current_state != BattleState.PLAYER_TURN:
		return
		
	print("玩家选择行动: ", action_type)
	
	# 设置为行动执行状态
	_set_state(BattleState.ACTION_EXECUTION)
	
	# 执行选择的行动
	match action_type:
		"attack":
			if target and target is Character:
				await execute_attack(current_turn_character, target)
			else:
				print("错误：攻击需要选择有效目标")
				_set_state(BattleState.PLAYER_TURN) # 返回选择状态
				return
		"defend":
			await execute_defend(current_turn_character)
		_:
			print("未知行动类型: ", action_type)
			_set_state(BattleState.PLAYER_TURN)
			return
	
	# 行动结束后转入回合结束
	_set_state(BattleState.ROUND_END)

# 执行敌人AI
func execute_enemy_ai():
	if current_state != BattleState.ENEMY_TURN or current_turn_character == null:
		return
		
	# 简单的AI逻辑：总是攻击第一个存活的玩家角色
	var target = null
	for player in player_characters:
		if player.current_hp > 0:
			target = player
			break
			
	if target:
		_set_state(BattleState.ACTION_EXECUTION)
		print(current_turn_character.character_name, " 选择攻击 ", target.character_name)
		await execute_attack(current_turn_character, target)
		_set_state(BattleState.ROUND_END)
	else:
		print("敌人找不到可攻击的目标")
		_set_state(BattleState.ROUND_END)

# 执行攻击
func execute_attack(attacker: Character, target: Character) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		push_warning("BattleManager: execute_attack - 无效的攻击者或目标。")
		return

	if not is_instance_valid(attacker.combat_component) or \
	   not attacker.combat_component.has_method("perform_basic_attack"):
		push_error("BattleManager: 攻击者 '%s' 或其 CombatComponent 无法执行 perform_basic_attack." % attacker.character_name)
		return

	print("BattleManager: %s 准备对 %s 执行基础攻击..." % [attacker.character_name, target.character_name])
	
	var attack_results = await attacker.combat_component.perform_basic_attack(target)

	# BattleManager 可能仍然关心某些高级别的结果，例如AI需要知道攻击是否成功或造成了多少伤害
	# SkillSystem.execute_skill 返回的结果结构需要约定好
	if attack_results and not attack_results.has("error"):
		var target_specific_results = attack_results.get(target) # SkillSystem 返回的结果是以目标为键的字典
		if target_specific_results:
			var damage_dealt_to_target = 0
			# 遍历该目标受到的所有效果结果，查找伤害值
			# 假设伤害效果的结果中包含 "damage_dealt" 键
			for effect_key in target_specific_results:
				if effect_key == "damage":
					damage_dealt_to_target = target_specific_results[effect_key]
					break # 通常基础攻击主要是一个伤害效果

			if enemy_characters.has(attacker): # 如果是敌人发起的攻击
				enemy_action_executed.emit(attacker, target, damage_dealt_to_target) # 保留这个信号，如果AI或其他系统需要
			
			# print_rich("[BattleManager] %s 对 %s 造成了 %d 点伤害 (通过基础攻击)。" % [attacker.character_name, target.character_name, damage_dealt_to_target])
	elif attack_results and attack_results.has("error"):
		print_rich("[BattleManager] %s 的基础攻击失败: %s" % [attacker.character_name, attack_results.error])

	# 注意：
	# 1. visual_effects.spawn_damage_number 现在应该由 DamageEffectProcessor 在其 process_effect 方法中调用。
	# 2. character_stats_changed 信号现在由 Character.gd 在其 _on_attribute_current_value_changed 方法中发出，
	#    当它监听到来自 SkillComponent -> AttributeSet 的属性变化时。
	#    BattleManager 不再需要直接在此处发出此信号。

# 执行防御
func execute_defend(character: Character):
	if not is_instance_valid(character):
		return

	if not is_instance_valid(character.combat_component):
		push_error("BattleManager: 角色 '%s' 没有 CombatComponent 来执行防御。" % character.character_name)
		return

	print("BattleManager: %s 选择防御。" % character.character_name)
	await character.combat_component.set_defending(true)

	# 防御的视觉效果 (如举盾动画/图标) 和相关的状态变化信号 (defense_state_changed)
	# 现在由 CombatComponent.set_defending -> Character.show_defense_indicator 负责处理。
	# BattleManager 主要负责接收防御指令并发起调用。
	# 原有的 visual_effects.play_defend_effect(character) 调用可以移至 Character.show_defense_indicator 或由 CombatComponent 的信号触发。

## 执行技能 - 由BattleScene调用
func execute_skill(caster: Character, skill_data: SkillData, custom_targets: Array = []) -> void:
	# 检查状态
	if current_state != BattleState.PLAYER_TURN and current_state != BattleState.ACTION_EXECUTION:
		print("错误：当前状态不允许使用技能")
		return
	
	# 获取技能目标 - 现在由SkillSystem处理
	var targets = skill_system.get_targets_for_skill(caster, skill_data) if custom_targets.is_empty() else custom_targets
	if targets.is_empty() and skill_data.target_type != SkillData.TargetType.SELF:
		print("错误：没有找到有效目标")
		return
	
	# 设置为行动执行状态
	_set_state(BattleState.ACTION_EXECUTION)
	
	# 委托给技能系统处理
	await skill_system.execute_skill(caster, skill_data, targets)
	
	# 技能执行完毕，进入回合结束阶段
	_set_state(BattleState.ROUND_END)

# 构建回合队列
func build_turn_queue() -> void:
	turn_queue.clear()
	
	# 简单实现：所有存活角色按速度排序
	var all_characters = []
	
	for player in player_characters:
		if player.current_hp > 0:
			all_characters.append(player)
			
	for enemy in enemy_characters:
		if enemy.current_hp > 0:
			all_characters.append(enemy)
	
	# 按速度从高到低排序
	all_characters.sort_custom(func(a, b): return a.speed > b.speed)
	
	turn_queue = all_characters
	print("回合顺序已生成: ", turn_queue.size(), " 个角色")

# 下一个回合
func next_turn() -> void:
	if turn_queue.is_empty():
		print("回合结束，重新构建回合顺序")
		build_turn_queue()
		
	if turn_queue.is_empty():
		print("没有可行动的角色")
		check_battle_end_condition()
		return
		
	current_turn_character = turn_queue.pop_front()
	print("当前行动者: ", current_turn_character.character_name)
	turn_changed.emit(current_turn_character)
	
	await current_turn_character.process_turn_start()
	# 根据当前行动者是玩家还是敌人，设置相应状态
	if player_characters.has(current_turn_character):
		_set_state(BattleState.PLAYER_TURN)
	else:
		_set_state(BattleState.ENEMY_TURN)

# 检查战斗结束条件
func check_battle_end_condition() -> bool:
	# 检查玩家是否全部阵亡
	var all_players_defeated = true
	for player in player_characters:
		if player.current_hp > 0:
			all_players_defeated = false
			break
			
	if all_players_defeated:
		_set_state(BattleState.DEFEAT)
		return true
		
	# 检查敌人是否全部阵亡
	var all_enemies_defeated = true
	for enemy in enemy_characters:
		if enemy.current_hp > 0:
			all_enemies_defeated = false
			break
			
	if all_enemies_defeated:
		_set_state(BattleState.VICTORY)
		return true
		
	return false

# 添加和管理角色
func add_player_character(character: Character) -> void:
	if player_characters.has(character):
		push_warning("角色 '%s' 已存在，无法重复添加" % character.character_name)
		return
	
	player_characters.append(character)
	print("添加玩家角色: ", character.character_name)
	character.initialize_battle_context(self)

func add_enemy_character(character: Character) -> void:
	if enemy_characters.has(character):
		push_warning("角色 '%s' 已存在，无法重复添加" % character.character_name)
		return
	
	enemy_characters.append(character)
	print("添加敌人角色: ", character.character_name)
	character.initialize_battle_context(self)

func remove_character(character: Character):
	if player_characters.has(character):
		player_characters.erase(character)
	if enemy_characters.has(character):
		enemy_characters.erase(character)
	if turn_queue.has(character):
		turn_queue.erase(character)
		
	print(character.character_name, " 已从战斗中移除")
	check_battle_end_condition()

# 判断角色是否为玩家角色
func is_player_character(character: Character) -> bool:
	return player_characters.has(character)

# 添加回合结束时处理状态效果的方法
func process_round_end() -> void:
	print_rich("[color=aqua]回合结束，处理状态效果...[/color]")

	await current_turn_character.process_turn_end()	

	# 检查战斗是否结束
	check_battle_end_condition()
	
	# 如果战斗未结束，开始新回合
	if current_state != BattleState.VICTORY and current_state != BattleState.DEFEAT:
		_set_state(BattleState.ROUND_START)

## 订阅角色信号
func _subscribe_to_character_signals(character : Character) -> void:
	if !character.character_defeated.is_connected(_on_character_defeated):
		character.character_defeated.connect(_on_character_defeated)
	
	#TODO 链接其他信号

# 处理技能执行信号
func _on_skill_executed(_caster, _targets, skill_data, _results):
	print("技能执行完成: ", skill_data.skill_name)
	# 可以在这里添加技能执行后的额外处理

# 角色死亡信号处理函数
func _on_character_defeated(character: Character) -> void:
	print_rich("[color=purple]" + character.character_name + " 已被击败![/color]")
	
	# 从相应列表中移除
	if player_characters.has(character):
		player_characters.erase(character)
	elif enemy_characters.has(character):
		enemy_characters.erase(character)
	
	# 从回合队列中移除
	if turn_queue.has(character):
		turn_queue.erase(character)
	
	# 如果当前行动者死亡，需要特殊处理
	if current_turn_character == character:
		print("当前行动者 " + character.character_name + " 已阵亡。")
	
	# 检查战斗是否结束
	check_battle_end_condition()

# 设置战斗状态
func _set_state(new_state: BattleState):
	if current_state == new_state:
		return
		
	print("战斗状态转换: ", BattleState.keys()[current_state], " -> ", BattleState.keys()[new_state])
	current_state = new_state
	battle_state_changed.emit(current_state)
	
	# 处理进入新状态时的逻辑
	match current_state:
		BattleState.IDLE:
			# 重置战斗相关变量
			start_battle()
			
		BattleState.BATTLE_START:
			# 战斗初始化
			build_turn_queue()
			_set_state(BattleState.ROUND_START)
			
		BattleState.ROUND_START:
			# 回合开始处理，确定行动者
			next_turn()

		BattleState.PLAYER_TURN:
			# 通知UI需要玩家输入
			print("玩家回合：等待输入...")
			player_action_required.emit(current_turn_character)
			
		BattleState.ENEMY_TURN:
			# 执行敌人AI
			print("敌人回合：", current_turn_character.character_name, " 思考中...")
			# 延迟一下再执行AI，避免敌人行动过快
			await get_tree().create_timer(1.0).timeout
			execute_enemy_ai()
			
		BattleState.ACTION_EXECUTION:
			# 执行选择的行动
			# 这部分通常在选择行动后直接调用execute_action
			pass
			
		BattleState.ROUND_END:
			# 处理回合结束效果
			process_round_end()
			
		BattleState.VICTORY:
			print("战斗胜利!")
			battle_ended.emit(true)
			
		BattleState.DEFEAT:
			print("战斗失败...")
			battle_ended.emit(false)
