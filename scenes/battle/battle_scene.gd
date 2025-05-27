extends Node2D
class_name BattleScene

@onready var battle_manager: BattleManager = %BattleManager

# UI引用
@onready var battle_info_label : RichTextLabel = $BattleUI/BattleInfo
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
	battle_manager.state_manager.state_changed.connect(_on_battle_state_changed)
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.player_action_required.connect(_on_player_action_required)
	battle_manager.enemy_action_executed.connect(_on_enemy_action_executed)

	# 启动战斗
	battle_manager._start_battle()

# 处理BattleManager发出的信号
func _on_battle_state_changed(_old_state: BattleStateManager.BattleState, new_state: BattleStateManager.BattleState) -> void:
	match new_state:
		BattleStateManager.BattleState.PLAYER_TURN:
			# 当玩家回合开始时，战斗管理器会通过player_action_required信号通知
			pass
		BattleStateManager.BattleState.ENEMY_TURN:
			# 隐藏所有UI菜单
			_hide_all_menus()
			update_battle_info("敌人回合...")
		BattleStateManager.BattleState.VICTORY:
			update_battle_info("战斗胜利！")
		BattleStateManager.BattleState.DEFEAT:
			update_battle_info("战斗失败...")

func _on_turn_changed(character: Character) -> void:
	update_battle_info(character.character_name + " 的回合")
	
	# 更新角色状态显示等

func _on_battle_ended(_is_victory: bool) -> void:
	# 隐藏所有战斗UI
	_hide_all_menus()
	
	# 可以在这里处理战斗结束后的逻辑，如显示结算界面等

func _on_player_action_required(character: Character) -> void:
	_show_action_menu()
	update_battle_info("%s 的回合，请选择行动" % character.character_name)

func _on_enemy_action_executed(attacker: Character, target: Character, damage: int) -> void:
	update_battle_info(attacker.character_name + " 对 " + target.character_name + " 造成了 " + str(damage) + " 点伤害!")

# UI信号处理函数
func _on_action_menu_attack_pressed() -> void:
	if battle_manager.state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		# 选择第一个存活的敌人作为目标
		var caster : Character = battle_manager.turn_order_manager.current_character
		var valid_targets = battle_manager.get_valid_enemy_targets(caster)
		if !valid_targets.is_empty():
			var target = valid_targets[0] # 这里简化为直接选择第一个敌人
			battle_manager.execute_action(CharacterCombatComponent.ActionType.ATTACK, caster, target)
		else:
			update_battle_info("没有可攻击的目标！")

func _on_action_menu_defend_pressed() -> void:
	if battle_manager.state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		battle_manager.execute_action(CharacterCombatComponent.ActionType.DEFEND, battle_manager.turn_order_manager.current_character)

func _on_skill_button_pressed() -> void:
	if battle_manager.state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		_open_skill_menu()

func _on_item_button_pressed() -> void:
	if battle_manager.state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		update_battle_info("物品功能尚未实现")

## 处理技能选择
func _on_skill_selected(skill: SkillData) -> void:
	current_selected_skill = skill

	var caster : Character = battle_manager.turn_order_manager.current_character
	# 根据技能目标类型决定下一步操作
	match skill.target_type:
		SkillData.TargetType.SELF, \
		SkillData.TargetType.ENEMY_ALL, \
		SkillData.TargetType.ALLY_ALL, \
		SkillData.TargetType.ALLY_ALL_INC_SELF:
			# 自动目标技能，直接执行
			var params = {"skill": skill, "targets": []}
			battle_manager.execute_action(CharacterCombatComponent.ActionType.SKILL, caster, null, params)
			
		SkillData.TargetType.ENEMY_SINGLE:
			# 显示敌人目标选择菜单
			var valid_targets := battle_manager.get_valid_enemy_targets(caster)
			if not valid_targets.is_empty():
				target_selection_menu.show_targets(valid_targets)
			else:
				update_battle_info("没有可选择的敌方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALLY_SINGLE:
			# 显示我方(不含自己)目标选择菜单
			var valid_targets = battle_manager.get_valid_ally_targets(caster, false)
			if !valid_targets.is_empty():
				target_selection_menu.show_targets(valid_targets)
			else:
				update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALLY_SINGLE_INC_SELF:  # 处理包含自己的单体友方目标选择
			# 显示我方(含自己)目标选择菜单
			var valid_targets = battle_manager.get_valid_ally_targets(caster, true)
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
func _on_target_selected(target: Character) -> void:
	# 确保有选中的技能
	if current_selected_skill == null:
		push_error("选择了目标但没有当前技能")
		_show_action_menu()
		return
	
	# 覆盖技能的默认目标逻辑，强制使用玩家选择的目标
	var caster : Character = battle_manager.turn_order_manager.current_character
	var targets : Array[Character] = [target]
	var params = {"skill": current_selected_skill, "targets": targets}
	battle_manager.execute_action(CharacterCombatComponent.ActionType.SKILL, caster, null, params)

# 当玩家取消目标选择时调用
func _on_target_selection_cancelled() -> void:
	# 返回技能选择菜单
	current_selected_skill = null
	_open_skill_menu()

# 更新战斗信息文本
func update_battle_info(text: String) -> void:
	if not battle_info_label:
		return
	if not battle_info_label.text.is_empty():
		battle_info_label.text += "\n"
	battle_info_label.text += text

# UI辅助功能
func _show_action_menu() -> void:
	_hide_all_menus() # 假设这是你隐藏其他UI元素的方法
	
	if not action_menu: # 假设 action_menu 是你的行动菜单节点
		return
	var current_character: Character =  battle_manager.turn_order_manager.current_character
	if is_instance_valid(current_character):
		var can_use_any_special_skill : bool = current_character.has_enough_mp_for_any_skill()
		action_menu.set_skill_button_enabled(can_use_any_special_skill) # 假设菜单有此方法
	else:
		action_menu.set_skill_button_enabled(false) # 没有当前角色则禁用
	
	action_menu.visible = true
	action_menu.setup_default_focus() # 假设菜单有此方法

func _open_skill_menu() -> void:
	_hide_all_menus()
	
	var current_character : Character = battle_manager.turn_order_manager.current_character
	if skill_select_menu and current_character:
		if current_character and current_character.character_data:
			skill_select_menu.show_menu(current_character.character_data.skills, current_character)
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
