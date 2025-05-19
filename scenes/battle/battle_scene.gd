extends Node2D
class_name BattleScene

@onready var battle_manager: BattleManager = %BattleManager

# UI引用
@onready var battle_info_label : Label = $BattleUI/BattleInfo
@onready var skill_select_menu: SkillSelectMenu = $BattleUI/SkillSelectMenu
@onready var target_selection_menu: TargetSelectionMenu = $BattleUI/TargetSelectionMenu
@onready var action_menu: ActionMenu = $BattleUI/ActionMenu

# 当前选中的技能，用于BattleScene内部状态管理
var current_selected_skill: SkillData = null

func _ready() -> void:
	# 确保UI组件已正确引用
	if !battle_info_label:
		push_error("BattleScene: BattleInfo label not found")
	
	if !skill_select_menu:
		push_error("BattleScene: SkillSelectMenu not found")
	else:
		# 连接技能选择菜单信号
		skill_select_menu.skill_selected.connect(_on_skill_selected)
		skill_select_menu.skill_selection_cancelled.connect(_on_skill_selection_cancelled)
		skill_select_menu.hide()
	
	if !target_selection_menu:
		push_error("BattleScene: TargetSelectionMenu not found") 
	else:
		# 连接目标选择菜单信号
		target_selection_menu.target_selected.connect(_on_target_selected)
		target_selection_menu.target_selection_cancelled.connect(_on_target_selection_cancelled)
		target_selection_menu.hide()
	
	if !action_menu:
		push_error("BattleScene: ActionMenu not found")
	else:
		# 连接行动菜单信号
		action_menu.attack_pressed.connect(_on_action_menu_attack_pressed)
		action_menu.defend_pressed.connect(_on_action_menu_defend_pressed)
		action_menu.skill_pressed.connect(_on_skill_button_pressed)
		action_menu.item_pressed.connect(_on_item_button_pressed)
		action_menu.hide()
	
	# 连接BattleManager信号
	battle_manager.battle_state_changed.connect(_on_battle_state_changed)
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.player_action_required.connect(_on_player_action_required)
	battle_manager.enemy_action_executed.connect(_on_enemy_action_executed)
	battle_manager.character_stats_changed.connect(_on_character_stats_changed)
	
	# 启动战斗
	battle_manager.start_battle()

# 处理BattleManager发出的信号
func _on_battle_state_changed(new_state: BattleManager.BattleState) -> void:
	match new_state:
		BattleManager.BattleState.PLAYER_TURN:
			# 当玩家回合开始时，战斗管理器会通过player_action_required信号通知
			pass
		BattleManager.BattleState.ENEMY_TURN:
			# 隐藏所有UI菜单
			_hide_all_menus()
			update_battle_info("敌人回合...")
		BattleManager.BattleState.VICTORY:
			update_battle_info("战斗胜利！")
		BattleManager.BattleState.DEFEAT:
			update_battle_info("战斗失败...")

func _on_turn_changed(character: Character) -> void:
	update_battle_info(character.character_name + " 的回合")
	
	# 更新角色状态显示等

func _on_battle_ended(is_victory: bool) -> void:
	if is_victory:
		update_battle_info("战斗胜利！")
	else:
		update_battle_info("战斗失败...")
	
	# 隐藏所有战斗UI
	_hide_all_menus()
	
	# 可以在这里处理战斗结束后的逻辑，如显示结算界面等

func _on_player_action_required(character: Character) -> void:
	_show_action_menu()
	update_battle_info("%s 的回合，请选择行动" % character.character_name)

func _on_enemy_action_executed(attacker: Character, target: Character, damage: int) -> void:
	update_battle_info(attacker.character_name + " 对 " + target.character_name + " 造成了 " + str(damage) + " 点伤害!")

func _on_character_stats_changed(_character: Character) -> void:
	# 更新角色状态显示
	# 此处只是示例，实际实现需要根据UI设计来
	pass

# UI信号处理函数
func _on_action_menu_attack_pressed() -> void:
	if battle_manager.current_state == BattleManager.BattleState.PLAYER_TURN:
		# 选择第一个存活的敌人作为目标
		var valid_targets = battle_manager.skill_system.get_valid_enemy_targets(battle_manager.current_turn_character)
		if !valid_targets.is_empty():
			var target = valid_targets[0] # 这里简化为直接选择第一个敌人
			battle_manager.player_select_action("attack", target)
		else:
			update_battle_info("没有可攻击的目标！")

func _on_action_menu_defend_pressed() -> void:
	if battle_manager.current_state == BattleManager.BattleState.PLAYER_TURN:
		battle_manager.player_select_action("defend")

func _on_skill_button_pressed() -> void:
	if battle_manager.current_state == BattleManager.BattleState.PLAYER_TURN:
		_open_skill_menu()

func _on_item_button_pressed() -> void:
	if battle_manager.current_state == BattleManager.BattleState.PLAYER_TURN:
		update_battle_info("物品功能尚未实现")

func _on_skill_selected(skill: SkillData) -> void:
	current_selected_skill = skill
	
	# 根据技能目标类型决定下一步操作
	match skill.target_type:
		SkillData.TargetType.SELF, \
		SkillData.TargetType.ALL_ENEMIES, \
		SkillData.TargetType.ALL_ALLIES, \
		SkillData.TargetType.ALL_ALLIES_EXCEPT_SELF:
			# 自动目标技能，直接执行
			battle_manager.execute_skill(battle_manager.current_turn_character, skill)
			
		SkillData.TargetType.SINGLE_ENEMY:
			# 显示敌人目标选择菜单
			var valid_targets = battle_manager.skill_system.get_valid_enemy_targets(battle_manager.current_turn_character)
			if !valid_targets.is_empty():
				target_selection_menu.show_targets(valid_targets)
			else:
				update_battle_info("没有可选择的敌方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.SINGLE_ALLY:
			# 显示我方(不含自己)目标选择菜单
			var valid_targets = battle_manager.skill_system.get_valid_ally_targets(battle_manager.current_turn_character, false)
			if !valid_targets.is_empty():
				target_selection_menu.show_targets(valid_targets)
			else:
				update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALL:  # 处理包含自己的单体友方目标选择
			# 显示我方(含自己)目标选择菜单
			var valid_targets = battle_manager.skill_system.get_valid_ally_targets(battle_manager.current_turn_character, true)
			if !valid_targets.is_empty():
				target_selection_menu.show_targets(valid_targets)
			else:
				update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		
		_:
			update_battle_info("未处理的目标类型: " + str(skill.target_type))
			_on_skill_selection_cancelled()

func _on_skill_selection_cancelled() -> void:
	# 重置当前选中的技能
	current_selected_skill = null
	
	# 返回到玩家行动选择状态
	_show_action_menu()

# 当玩家选择了技能目标时调用
func _on_target_selected(_target: Character) -> void:
	# 确保有选中的技能
	if current_selected_skill == null:
		push_error("选择了目标但没有当前技能")
		_show_action_menu()
		return
	
	# 创建一个单体目标数组
	var skill_copy = current_selected_skill.duplicate()
	
	# 覆盖技能的默认目标逻辑，强制使用玩家选择的目标
	battle_manager.execute_skill(
		battle_manager.current_turn_character, 
		skill_copy
	)

# 当玩家取消目标选择时调用
func _on_target_selection_cancelled() -> void:
	# 返回技能选择菜单
	current_selected_skill = null
	_open_skill_menu()

# 更新战斗信息文本
func update_battle_info(text: String) -> void:
	if battle_info_label:
		battle_info_label.text = text

# UI辅助功能
func _show_action_menu() -> void:
	_hide_all_menus()
	
	# 在显示行动菜单前，检查技能按钮状态
	if action_menu:
		var current_character = battle_manager.current_turn_character
		if current_character:
			# 使用辅助方法从Character类中获取状态
			var has_enough_mp_for_any_skill = current_character.has_enough_mp_for_any_skill()
			action_menu.set_skill_button_enabled(has_enough_mp_for_any_skill)
		
		action_menu.visible = true
		action_menu.setup_default_focus()

func _open_skill_menu() -> void:
	_hide_all_menus()
	
	if skill_select_menu and battle_manager.current_turn_character:
		var character = battle_manager.current_turn_character
		if character and character.character_data and character.character_data.skills:
			skill_select_menu.show_menu(character.character_data.skills, character)
		else:
			update_battle_info("该角色没有技能")
			_show_action_menu()

func _hide_all_menus() -> void:
	if action_menu:
		action_menu.visible = false
	
	if skill_select_menu:
		skill_select_menu.visible = false
	
	if target_selection_menu:
		target_selection_menu.visible = false
