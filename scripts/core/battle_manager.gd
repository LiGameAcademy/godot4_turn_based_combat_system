# scripts/core/battle_manager.gd
extends Node
class_name BattleManager

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")
# 预加载UI实例
const SKILL_SELECT_MENU_SCENE := preload("res://scenes/ui/skill_select_menu.tscn")
const TARGET_SELECTION_MENU_SCENE := preload("res://scenes/ui/target_selection_menu.tscn")
const ACTION_MENU_SCENE := preload("res://scenes/ui/action_menu.tscn")

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

# 引用UI实例
var skill_select_menu: SkillSelectMenu
var target_selection_menu: TargetSelectionMenu
var action_menu: ActionMenu

## 当前选中的技能
var current_selected_skill : SkillData = null

# 信号
signal battle_state_changed(new_state)
signal turn_changed(character)
signal battle_ended(is_victory)

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
			# 激活玩家输入界面
			print("玩家回合：等待输入...")
			show_action_ui(true)  # 显示行动按钮
			
		BattleState.ENEMY_TURN:
			# 执行敌人AI
			print("敌人回合：", current_turn_character.character_name, " 思考中...")
			show_action_ui(false)  # 隐藏行动按钮
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

# 玩家选择行动
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
	
	# 更新UI信息
	update_battle_info(attacker.character_name + " 对 " + target.character_name + " 造成了 " + str(damage) + " 点伤害!")

	# 显示伤害数字
	spawn_damage_number(target.global_position, damage, Color.RED)
	
	print_rich("[color=red]" + target.character_name + " 受到 " + str(damage) + " 点伤害![/color]")

# 执行防御
func execute_defend(character: Character):
	if character == null:
		return

	print(character.character_name, " 选择防御，受到的伤害将减少")
	character.set_defending(true)
	
	# 更新UI信息
	update_battle_info(character.character_name + " 进入防御状态，将受到减少的伤害!")

## 执行技能
func execute_skill(caster: Character, targets: Array[Character], skill_data: SkillData) -> void:
	print(caster.character_name + "使用技能：" + skill_data.skill_name)

	# 消耗MP
	if !caster.use_mp(skill_data.mp_cost):
		print("错误：MP不足，无法释放技能！")
		return
	
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

func show_action_ui(visible: bool):
	if action_menu:
		action_menu.visible = visible

func update_battle_info(text: String):
	var info_label = get_node_or_null("../BattleUI/BattleInfo")
	if info_label:
		info_label.text = text

## 生成伤害数字
func spawn_damage_number(position: Vector2, amount: int, color : Color) -> void:
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = position + Vector2(0, -50)
	damage_number.show_number(str(amount), color)

func _initialize_ui() -> void:
	# 实例化并配置技能选择菜单
	skill_select_menu = SKILL_SELECT_MENU_SCENE.instantiate()
	add_child(skill_select_menu)
	skill_select_menu.skill_selected.connect(_on_skill_selected)
	skill_select_menu.skill_selection_cancelled.connect(_on_skill_selection_cancelled)
	skill_select_menu.hide()

	# 实例化并配置目标选择菜单
	target_selection_menu = TARGET_SELECTION_MENU_SCENE.instantiate()
	add_child(target_selection_menu)
	target_selection_menu.target_selected.connect(_on_target_selected)
	target_selection_menu.target_selection_cancelled.connect(_on_target_selection_cancelled)
	target_selection_menu.hide()

	# 实例化单独的ActionMenu场景
	action_menu = ACTION_MENU_SCENE.instantiate()
	var battle_ui = get_node_or_null("../BattleUI")
	if battle_ui:
		battle_ui.add_child(action_menu)
		# 设置位置和大小
		action_menu.anchor_left = 0.726
		action_menu.anchor_top = 0.764
		action_menu.anchor_right = 1.0
		action_menu.anchor_bottom = 1.0
		action_menu.hide()

		action_menu.attack_pressed.connect(_on_action_menu_attack_pressed)
		action_menu.defend_pressed.connect(_on_action_menu_defend_pressed)
		action_menu.skill_pressed.connect(_on_skill_button_pressed)
		action_menu.item_pressed.connect(_on_item_button_pressed)

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
		
		print(target.character_name + " 恢复了 " + str(heal_amount) + " 点生命值")

# 状态类技能
func _execute_status_skill(caster: Character, targets: Array[Character], skill: SkillData) -> void:
	pass

func _execute_control_skill(caster: Character, targets: Array[Character], skill: SkillData) -> void:
	pass

func _execute_special_skill(caster: Character, targets: Array[Character], skill: SkillData) -> void:
	pass

# 获取有效的敌方目标列表（过滤掉已倒下的角色）
func _get_valid_enemy_targets() -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for enemy in enemy_characters:
		if enemy.is_alive():
			valid_targets.append(enemy)
	
	return valid_targets

# 获取有效的友方目标列表
# include_self: 是否包括施法者自己
func _get_valid_ally_targets(include_self: bool) -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for ally in player_characters:
		if ally.is_alive() && (include_self || ally != current_turn_character):
			valid_targets.append(ally)
	
	return valid_targets

# 打开技能选择菜单
func _open_skill_menu() -> void:
	if current_turn_character == null || current_state != BattleState.PLAYER_TURN:
		return
		
	skill_select_menu.show_menu(current_turn_character.character_data.skills, current_turn_character.current_mp)

# 显示玩家行动菜单
func _show_action_menu() -> void:
	# 确保当前是玩家角色的回合
	if current_turn_character == null || !_is_player_character(current_turn_character):
		return
		
	# 隐藏其他可能显示的菜单
	if skill_select_menu:
		skill_select_menu.hide()
	if target_selection_menu:
		target_selection_menu.hide()
		
	# 显示行动菜单并更新状态
	if action_menu:
		# 更新菜单状态
		_update_action_menu_state()
		# 显示菜单
		action_menu.show()
		# 获取焦点
		action_menu.grab_focus()
		
	# 设置状态为玩家回合
	set_state(BattleState.PLAYER_TURN)
	
	# 显示当前角色的回合提示
	print_rich("[color=yellow]%s 的回合，请选择行动[/color]" % current_turn_character.character_name)
	
# 更新行动菜单状态
func _update_action_menu_state() -> void:
	# 这个辅助方法用于更新行动菜单上各按钮的状态
	# 例如，如果角色MP为0，可能需要禁用"技能"按钮
	
	if action_menu:
		# 示例：根据MP是否足够来启用/禁用技能按钮
		var has_enough_mp_for_any_skill = false
		
		for skill in current_turn_character.character_data.skills:
			if current_turn_character.current_mp >= skill.mp_cost:
				has_enough_mp_for_any_skill = true
				break
				
		action_menu.set_skill_button_enabled(has_enough_mp_for_any_skill)
		
		# 示例：根据是否有物品来启用/禁用物品按钮
		var has_usable_items = false # 这里需要根据实际的物品系统来实现
		action_menu.set_item_button_enabled(has_usable_items)

# 判断角色是否为玩家角色
func _is_player_character(character: Character) -> bool:
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

func _on_skill_selected(skill : SkillData) -> void:
	current_selected_skill = skill

	# 根据技能目标类型决定下一步操作
	match skill.target_type:
		SkillData.TargetType.SELF:
			# 自身技能无需选择目标
			execute_skill(current_turn_character, [current_turn_character], skill)
		
		SkillData.TargetType.ENEMY_SINGLE:
			# 显示敌人目标选择菜单
			var valid_targets = _get_valid_enemy_targets()
			target_selection_menu.show_targets(valid_targets)
		
		SkillData.TargetType.ENEMY_ALL:
			# 群体敌人技能无需选择目标
			execute_skill(current_turn_character, _get_valid_enemy_targets(), skill)
		
		SkillData.TargetType.ALLY_SINGLE:
			# 显示我方(不含自己)目标选择菜单
			var valid_targets = _get_valid_ally_targets(false)
			target_selection_menu.show_targets(valid_targets)
		
		SkillData.TargetType.ALLY_SINGLE_INC_SELF:
			# 显示我方(含自己)目标选择菜单
			var valid_targets = _get_valid_ally_targets(true)
			target_selection_menu.show_targets(valid_targets)
		
		SkillData.TargetType.ALLY_ALL:
			# 群体我方(不含自己)技能
			execute_skill(current_turn_character, _get_valid_ally_targets(false), skill)
		
		SkillData.TargetType.ALLY_ALL_INC_SELF:
			# 群体我方(含自己)技能
			execute_skill(current_turn_character, _get_valid_ally_targets(true), skill)
		
		_:
			print("未处理的目标类型: ", skill.target_type)
			_on_skill_selection_cancelled()

func _on_skill_selection_cancelled() -> void:
	# 重置当前选中的技能
	current_selected_skill = null
	
	# 返回到玩家行动选择状态
	_show_action_menu()
	
	# 设置状态为玩家回合
	set_state(BattleState.PLAYER_TURN)

# 当玩家选择了技能目标时调用
func _on_target_selected(target: Character) -> void:
	# 确保有选中的技能
	if current_selected_skill == null:
		push_error("选择了目标但没有当前技能")
		return
	
	# 单体技能处理
	if current_selected_skill.target_type == SkillData.TargetType.ENEMY_SINGLE || \
	   current_selected_skill.target_type == SkillData.TargetType.ALLY_SINGLE || \
	   current_selected_skill.target_type == SkillData.TargetType.ALLY_SINGLE_INC_SELF:
		execute_skill(current_turn_character, [target], current_selected_skill)
	else:
		push_error("非单体技能不应该调用单体目标选择")

# 当玩家取消目标选择时调用
func _on_target_selection_cancelled() -> void:
	# 返回技能选择菜单
	current_selected_skill = null
	_open_skill_menu()

# 添加按钮信号处理函数
func _on_action_menu_attack_pressed() -> void:
	# 处理攻击按钮
	if current_state == BattleState.PLAYER_TURN:
		# 选择第一个存活的敌人作为目标
		var target = null
		for enemy in enemy_characters:
			if enemy.is_alive():
				target = enemy
				break
				
		if target:
			player_select_action("attack", target)

func _on_action_menu_defend_pressed() -> void:
	# 处理防御按钮
	if current_state == BattleState.PLAYER_TURN:
		player_select_action("defend")

func _on_skill_button_pressed() -> void:
	# 处理技能按钮
	if current_state == BattleState.PLAYER_TURN:
		_open_skill_menu()

func _on_item_button_pressed() -> void:
	# 处理物品按钮（将来实现）
	if current_state == BattleState.PLAYER_TURN:
		print("物品功能尚未实现")
