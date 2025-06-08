extends Node
class_name BattleManager

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

# 战斗参与者
var player_characters: Array[Character] = []
var enemy_characters: Array[Character] = []

# 回合顺序管理
var turn_queue: Array = []
var current_turn_character: Character = null

# 简单的战斗标记
var is_player_turn = false     # 当前是否是玩家回合
var battle_finished = false    # 战斗是否结束
var is_victory = false         # 战斗结果是否为胜利

# 信号
signal turn_changed(character)
signal battle_ended(is_victory)
signal battle_info_logged(text)

# 查找战斗场景中的角色
func find_characters() -> void:
	# 查找战斗场景中的所有角色
	var player_area = get_node_or_null("PlayerArea")
	var enemy_area = get_node_or_null("EnemyArea")
	
	if player_area:
		for child in player_area.get_children():
			if child is Character:
				add_player_character(child)
	
	if enemy_area:
		for child in enemy_area.get_children():
			if child is Character:
				add_enemy_character(child)
	
	log_battle_info("[color=yellow][战斗系统][/color] 已注册 [color=blue][b]{0}[/b][/color] 名玩家角色和 [color=red][b]{1}[/b][/color] 名敌人".format([player_characters.size(), enemy_characters.size()]))

# 开始战斗
func start_battle() -> void:
	log_battle_info("[color=yellow][b]===== 战斗开始! =====[/b][/color]")
	
	if player_characters.is_empty() or enemy_characters.is_empty():
		push_error("无法开始战斗：缺少玩家或敌人!")
		return
	
	# 初始化回合队列
	build_turn_queue()
	
	# 开始第一个角色的回合
	next_turn()

# 构建回合队列
func build_turn_queue() -> void:
	# 清空当前队列
	turn_queue.clear()
	
	# 将所有存活的角色添加到队列中
	for character in player_characters:
		if character.current_hp > 0:
			turn_queue.append(character)
			
	for character in enemy_characters:
		if character.current_hp > 0:
			turn_queue.append(character)
	
	# 根据速度属性排序
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)
	
	log_battle_info("[color=yellow][战斗系统][/color] 回合队列已建立: [color=green][b]{0}[/b][/color] 个角色".format([turn_queue.size()]))

# 切换到下一个角色的回合
func next_turn() -> void:
	# 检查战斗是否结束
	if battle_finished:
		return
		
	# 如果队列为空，重新构建
	if turn_queue.is_empty():
		build_turn_queue()
		
	# 仍然为空，说明没有可行动角色
	if turn_queue.is_empty():
		end_battle(false) # 失败
		return
		
	# 获取当前回合的角色
	current_turn_character = turn_queue.pop_front()
	
	# 检查角色是否存活
	if current_turn_character.current_hp <= 0:
		# 角色已阵亡，跳过其回合
		next_turn()
		return

	# 判断是玩家还是敌人回合
	is_player_turn = current_turn_character in player_characters
	# 发出回合变化信号
	turn_changed.emit(current_turn_character)
	
	if is_player_turn:
		# 玩家回合
		log_battle_info("[color=blue][玩家回合][/color] [color=cyan][b]{0}[/b][/color] 的行动".format([current_turn_character.character_name]))
	else:
		# 敌人回合
		log_battle_info("[color=red][敌人回合][/color] [color=orange][b]{0}[/b][/color] 的行动".format([current_turn_character.character_name]))
		
		# 延迟一下再执行AI，避免敌人行动过快
		await get_tree().create_timer(1.0).timeout
		execute_enemy_ai()
	
# 结束战斗
func end_battle(is_win: bool) -> void:
	battle_finished = true
	is_victory = is_win
	
	if is_win:
		log_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
	else:
		log_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
	
	# 发出战斗结束信号
	battle_ended.emit(is_win)

# 玩家选择行动
func player_select_action(action_type: String, target = null) -> void:
	# 检查是否是玩家回合
	if not is_player_turn or battle_finished:
		return
		
	print("玩家选择行动: ", action_type)
	
	# 执行选择的行动
	match action_type:
		"attack":
			if target and target is Character:
				execute_attack(current_turn_character, target)
			else:
				# 默认选择第一个敌人作为目标
				var default_target = null
				for enemy in enemy_characters:
					if enemy.current_hp > 0:
						default_target = enemy
						break
						
				if default_target:
					execute_attack(current_turn_character, default_target)
				else:
					print("错误：没有可用的目标")
					return
		"defend":
			execute_defend(current_turn_character)
		_:
			print("未知行动类型: ", action_type)
			return
	
	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
		
	# 进入下一个角色的回合
	next_turn()

# 执行敌人AI
func execute_enemy_ai() -> void:
	# 检查是否是敌人回合
	if is_player_turn or battle_finished or current_turn_character == null:
		return
		
	# 简单的AI逻辑：总是攻击第一个存活的玩家角色
	var target = null
	for player in player_characters:
		if player.current_hp > 0:
			target = player
			break
			
	if target:
		log_battle_info("[color=orange][b]{0}[/b][/color] 选择攻击 [color=blue][b]{1}[/b][/color]".format([current_turn_character.character_name, target.character_name]))
		execute_attack(current_turn_character, target)
	else:
		log_battle_info("[color=red][错误][/color] 敌人找不到可攻击的目标")
		
	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
		
	# 进入下一个角色的回合
	next_turn()

# 执行攻击
func execute_attack(attacker: Character, target: Character) -> void:
	log_battle_info("[color=purple][战斗行动][/color] [color=orange][b]{0}[/b][/color] 攻击 [color=cyan][b]{1}[/b][/color]".format([attacker.character_name, target.character_name]))
	
	var damage : int = attacker.attack - target.defense

	var final_damage = target.take_damage(damage)

	# 显示伤害数字
	spawn_damage_number(target.global_position, final_damage, Color.RED)

	# 检查战斗是否结束
	check_battle_end_condition()
	
# 执行防御
func execute_defend(character: Character) -> void:
	if character == null:
		return

	log_battle_info("[color=purple][战斗行动][/color] [color=cyan][b]{0}[/b][/color] 选择[color=teal][防御][/color]，受到的伤害将减少".format([character.character_name]))
	# TODO: 实现防御逻辑，可能是添加临时buff或设置状态
	character.set_defending(true)

# 检查战斗结束条件
func check_battle_end_condition() -> bool:
	# 如果战斗已结束，直接返回
	if battle_finished:
		return true
		
	# 检查玩家是否全部阵亡
	var all_players_defeated = true
	for player in player_characters:
		if player.current_hp > 0:
			all_players_defeated = false
			break
			
	# 检查敌人是否全部阵亡
	var all_enemies_defeated = true
	for enemy in enemy_characters:
		if enemy.current_hp > 0:
			all_enemies_defeated = false
			break
			
	# 判断战斗结果
	if all_players_defeated:
		# 玩家全部阵亡，战斗失败
		end_battle(false)
		return true
		
	if all_enemies_defeated:
		# 敌人全部阵亡，战斗胜利
		end_battle(true)
		return true
		
	return false

# 添加和管理角色
func add_player_character(character: Character) -> void:
	if not player_characters.has(character):
		player_characters.append(character)
		log_battle_info("[color=blue][玩家注册][/color] 添加角色: [color=cyan][b]{0}[/b][/color]".format([character.character_name]))

func add_enemy_character(character: Character) -> void:
	if not enemy_characters.has(character):
		enemy_characters.append(character)
		log_battle_info("[color=red][敌人注册][/color] 添加角色: [color=orange][b]{0}[/b][/color]".format([character.character_name]))

func remove_character(character: Character) -> void:
	if player_characters.has(character):
		player_characters.erase(character)
	if enemy_characters.has(character):
		enemy_characters.erase(character)
	if turn_queue.has(character):
		turn_queue.erase(character)
		
	log_battle_info("[color=gray][b]{0}[/b] 已从战斗中移除[/color]".format([character.character_name]))
	check_battle_end_condition()

## 生成伤害数字
func spawn_damage_number(position: Vector2, amount: int, color : Color) -> void:
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = position + Vector2(0, -50)
	damage_number.show_number(str(amount), color)

## 战斗日志
func log_battle_info(text: String) -> void:
	print_rich(text)
	battle_info_logged.emit(text)
