# scripts/core/battle_manager.gd
extends Node
class_name BattleManager

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

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

## 当前选中的技能
var current_selected_skill : SkillData = null

# 信号
signal battle_state_changed(new_state)
signal turn_changed(character)
signal battle_ended(is_victory)
# 添加额外信号用于与UI交互
signal player_action_required(character) # 通知UI玩家需要行动
signal enemy_action_executed(attacker, target, damage) # 敌人执行了行动
signal character_stats_changed(character) # 角色状态变化

func _ready():
	set_state(BattleState.IDLE)

# 设置战斗状态
func set_state(new_state: BattleState):
	if current_state == new_state:
		return
		
	print("战斗状态转换: ", BattleState.keys()[current_state], " -> ", BattleState.keys()[new_state])
	current_state = new_state
	emit_signal("battle_state_changed", current_state)
	
	# 处理进入新状态时的逻辑
	match current_state:
		BattleState.IDLE:
			# 重置战斗相关变量
			start_battle()
			
		BattleState.BATTLE_START:
			# 战斗初始化
			build_turn_queue()
			set_state(BattleState.ROUND_START)
			
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
			# 重置当前回合角色标记
			if current_turn_character:
				current_turn_character.reset_turn_flags()

			# 回合结束处理
			if not check_battle_end_condition():
				set_state(BattleState.ROUND_START)
				
		BattleState.VICTORY:
			print("战斗胜利!")
			emit_signal("battle_ended", true)
			
		BattleState.DEFEAT:
			print("战斗失败...")
			emit_signal("battle_ended", false)

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
	
	set_state(BattleState.BATTLE_START)

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
	set_state(BattleState.ACTION_EXECUTION)
	
	# 执行选择的行动
	match action_type:
		"attack":
			if target and target is Character:
				execute_attack(current_turn_character, target)
			else:
				print("错误：攻击需要选择有效目标")
				set_state(BattleState.PLAYER_TURN) # 返回选择状态
				return
		"defend":
			execute_defend(current_turn_character)
		_:
			print("未知行动类型: ", action_type)
			set_state(BattleState.PLAYER_TURN)
			return
	
	# 行动结束后转入回合结束
	set_state(BattleState.ROUND_END)

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
		set_state(BattleState.ACTION_EXECUTION)
		print(current_turn_character.character_name, " 选择攻击 ", target.character_name)
		execute_attack(current_turn_character, target)
		set_state(BattleState.ROUND_END)
	else:
		print("敌人找不到可攻击的目标")
		set_state(BattleState.ROUND_END)

# 执行攻击
func execute_attack(attacker: Character, target: Character):
	if attacker == null or target == null:
		return
		
	print(attacker.character_name, " 攻击 ", target.character_name)
	
	# 简单的伤害计算
	var damage = target.take_damage(attacker.attack - target.defense)
	
	# 发出敌人行动执行信号
	if enemy_characters.has(attacker):
		enemy_action_executed.emit(attacker, target, damage)
		
	# 发出角色状态变化信号
	character_stats_changed.emit(target)

	# 显示伤害数字
	spawn_damage_number(target.global_position, damage, Color.RED)
	
	print_rich("[color=red]" + target.character_name + " 受到 " + str(damage) + " 点伤害![/color]")

# 执行防御
func execute_defend(character: Character):
	if character == null:
		return

	print(character.character_name, " 选择防御，受到的伤害将减少")
	character.set_defending(true)
	
	# 发出角色状态变化信号
	character_stats_changed.emit(character)

## 执行技能 - 由BattleScene调用
func execute_skill(caster: Character, targets: Array[Character], skill_data: SkillData) -> void:
	print(caster.character_name + "使用技能：" + skill_data.skill_name)

	# 消耗MP
	if !caster.use_mp(skill_data.mp_cost):
		print("错误：MP不足，无法释放技能！")
		return
	
	# 发出角色状态变化信号
	character_stats_changed.emit(caster)
	
	# 根据技能类型执行不同的效果
	match skill_data.effect_type:
		SkillData.EffectType.DAMAGE:
			_execute_damage_skill(caster, targets, skill_data)
		SkillData.EffectType.HEAL:
			_execute_heal_skill(caster, targets, skill_data)
		SkillData.EffectType.APPLY_STATUS:
			_execute_status_skill(caster, targets, skill_data)
		SkillData.EffectType.CONTROL:
			_execute_control_skill(caster, targets, skill_data)
		SkillData.EffectType.SPECIAL:
			_execute_special_skill(caster, targets, skill_data)
		_:
			print("未处理的技能效果类型： ", skill_data.effect_type)
	# 技能执行完毕，进入行动执行状态
	set_state(BattleState.ACTION_EXECUTION)

# 构建回合队列
func build_turn_queue():
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
func next_turn():
	if turn_queue.is_empty():
		print("回合结束，重新构建回合顺序")
		build_turn_queue()
		
	if turn_queue.is_empty():
		print("没有可行动的角色")
		check_battle_end_condition()
		return
		
	current_turn_character = turn_queue.pop_front()
	print("当前行动者: ", current_turn_character.character_name)
	emit_signal("turn_changed", current_turn_character)
	
	# 根据当前行动者是玩家还是敌人，设置相应状态
	if player_characters.has(current_turn_character):
		set_state(BattleState.PLAYER_TURN)
	else:
		set_state(BattleState.ENEMY_TURN)

# 检查战斗结束条件
func check_battle_end_condition() -> bool:
	# 检查玩家是否全部阵亡
	var all_players_defeated = true
	for player in player_characters:
		if player.current_hp > 0:
			all_players_defeated = false
			break
			
	if all_players_defeated:
		set_state(BattleState.DEFEAT)
		return true
		
	# 检查敌人是否全部阵亡
	var all_enemies_defeated = true
	for enemy in enemy_characters:
		if enemy.current_hp > 0:
			all_enemies_defeated = false
			break
			
	if all_enemies_defeated:
		set_state(BattleState.VICTORY)
		return true
		
	return false

# 添加和管理角色
func add_player_character(character: Character):
	if not player_characters.has(character):
		player_characters.append(character)
		print("添加玩家角色: ", character.character_name)

func add_enemy_character(character: Character):
	if not enemy_characters.has(character):
		enemy_characters.append(character)
		print("添加敌人角色: ", character.character_name)

func remove_character(character: Character):
	if player_characters.has(character):
		player_characters.erase(character)
	if enemy_characters.has(character):
		enemy_characters.erase(character)
	if turn_queue.has(character):
		turn_queue.erase(character)
		
	print(character.character_name, " 已从战斗中移除")
	check_battle_end_condition()

## 生成伤害数字
func spawn_damage_number(position: Vector2, amount: int, color : Color) -> void:
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = position + Vector2(0, -50)
	damage_number.show_number(str(amount), color)

# 伤害类技能
func _execute_damage_skill(caster: Character, targets: Array[Character], skill: SkillData):
	for target in targets:
		if target.current_hp <= 0:
			continue
		
		# 计算基础伤害
		var base_damage = skill.power
		
		# 可以根据角色属性进行调整
		# 例如: base_damage += caster.magic_attack * 0.5
		
		# 应用伤害
		var damage_dealt = target.take_damage(base_damage)
		
		# 显示伤害数字
		spawn_damage_number(target.global_position, damage_dealt, Color.RED)
		
		# 发出角色状态变化信号
		character_stats_changed.emit(target)
		
		print(target.character_name + " 受到 " + str(damage_dealt) + " 点伤害")

# 治疗类技能
func _execute_heal_skill(caster: Character, targets: Array[Character], skill: SkillData):
	for target in targets:
		if target.current_hp <= 0:  # 不能治疗已死亡的角色
			continue
		
		# 计算基础治疗量
		var base_heal = skill.power
		
		# 可以根据角色属性进行调整
		# 例如: base_heal += caster.magic_attack * 0.3
		
		# 应用治疗
		var heal_amount = target.heal(base_heal)
		
		# 显示治疗数字
		spawn_damage_number(target.global_position, heal_amount, Color.GREEN)
		
		# 发出角色状态变化信号
		character_stats_changed.emit(target)
		
		print(target.character_name + " 恢复了 " + str(heal_amount) + " 点生命值")

# 状态类技能
func _execute_status_skill(caster: Character, targets: Array[Character], skill: SkillData) -> void:
	pass

func _execute_control_skill(caster: Character, targets: Array[Character], skill: SkillData) -> void:
	pass

func _execute_special_skill(caster: Character, targets: Array[Character], skill: SkillData) -> void:
	pass

# 获取有效的敌方目标列表（过滤掉已倒下的角色）
func get_valid_enemy_targets() -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for enemy in enemy_characters:
		if enemy.is_alive():
			valid_targets.append(enemy)
	
	return valid_targets

# 获取有效的友方目标列表
# include_self: 是否包括施法者自己
func get_valid_ally_targets(include_self: bool = false) -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for ally in player_characters:
		if ally.is_alive() && (include_self || ally != current_turn_character):
			valid_targets.append(ally)
	
	return valid_targets

# 判断角色是否为玩家角色
func is_player_character(character: Character) -> bool:
	return player_characters.has(character)

## 订阅角色信号
func _subscribe_to_character_signals(character : Character) -> void:
	if !character.character_died.is_connected(_on_character_died):
		character.character_died.connect(_on_character_died)
	
	#TODO 链接其他信号

# 角色死亡信号处理函数
func _on_character_died(character: Character) -> void:
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
