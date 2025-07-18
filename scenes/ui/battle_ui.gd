extends CanvasLayer
class_name BattleUI

# UI组件引用
@onready var battle_log_panel: BattleLogPanel = $BattleLogPanel
@onready var action_menu: ActionMenu = $ActionMenu
@onready var skill_select_menu: SkillSelectMenu = $SkillSelectMenu
@onready var target_selection_menu: TargetSelectionMenu = $TargetSelectionMenu
@onready var _character_detail_panel : CharacterDetailPanel = $CharacterDetailPanel
@onready var turn_order_indicator: TurnOrderIndicator = $TurnOrderIndicator

# 信号
signal action_attack_pressed						## 攻击动作按下
signal action_defend_pressed
signal action_skill_pressed
signal action_item_pressed
signal skill_selected(skill: SkillData)
signal skill_selection_cancelled
signal target_selected(target: Character)
signal target_selection_cancelled

func _ready() -> void:
	# 确保UI组件已正确引用
	if !battle_log_panel:
		push_error("BattleUI: BattleInfo label not found")
	
	if !skill_select_menu:
		push_error("BattleUI: SkillSelectMenu not found")
	else:
		# 连接技能选择菜单信号
		skill_select_menu.skill_selected.connect(_on_skill_selected)
		skill_select_menu.skill_selection_cancelled.connect(_on_skill_selection_cancelled)
		skill_select_menu.hide()
	
	if !target_selection_menu:
		push_error("BattleUI: TargetSelectionMenu not found") 
	else:
		# 连接目标选择菜单信号
		target_selection_menu.target_selected.connect(_on_target_selected)
		target_selection_menu.target_selection_cancelled.connect(_on_target_selection_cancelled)
		target_selection_menu.hide()
	
	if !action_menu:
		push_error("BattleUI: ActionMenu not found")
		
	# 初始化时重置UI状态
	reset()

## 重置UI状态
func reset() -> void:
	# 隐藏所有菜单
	hide_all_menus()
	
	# 清除战斗日志
	if battle_log_panel:
		battle_log_panel.clear_log()
	
	# 重置回合顺序指示器
	if turn_order_indicator:
		turn_order_indicator.update_turn_order([], -1)

	# 连接行动菜单信号
	action_menu.attack_pressed.connect(_on_action_menu_attack_pressed)
	action_menu.defend_pressed.connect(_on_action_menu_defend_pressed)
	action_menu.skill_pressed.connect(_on_action_menu_skill_pressed)
	action_menu.item_pressed.connect(_on_action_menu_item_pressed)
	action_menu.hide()
	
	if !battle_log_panel:
		push_error("BattleUI: BattleLogPanel not found")
	
	if !turn_order_indicator:
		push_error("BattleUI: TurnOrderIndicator not found")

# UI显示和隐藏方法
func show_action_menu(current_character) -> void:
	hide_all_menus() # 先隐藏其他菜单
	
	if not action_menu:
		return
	
	if is_instance_valid(current_character):
		var can_use_any_special_skill: bool = current_character.has_enough_mp_for_any_skill()
		action_menu.set_skill_button_enabled(can_use_any_special_skill)
	else:
		action_menu.set_skill_button_enabled(false)
	
	action_menu.visible = true
	action_menu.setup_default_focus()

## 显示技能选择菜单
func show_skill_menu(character: Character) -> bool:
	hide_all_menus()
	
	if skill_select_menu and character:
		if character and character.character_data:
			var character_data: CharacterData = character.character_data
			var skills: Array[SkillData] = character_data.skills
			skill_select_menu.show_menu(skills, character.current_mp)
			return true
	
	return false

## 显示目标选择菜单
func show_target_selection(targets: Array[Character]) -> bool:
	if target_selection_menu and not targets.is_empty():
		target_selection_menu.show_targets(targets)
		return true
	
	return false

## 隐藏所有菜单
func hide_all_menus() -> void:
	if action_menu:
		action_menu.visible = false
	
	if skill_select_menu:
		skill_select_menu.visible = false
	
	if target_selection_menu:
		target_selection_menu.visible = false

## 战斗信息显示
func update_battle_info(text: String) -> void:
	if not battle_log_panel:
		return
	
	battle_log_panel.log_system(text)

# 更新回合顺序显示
func update_turn_order(characters: Array, current_character_index: int) -> void:
	if turn_order_indicator:
		turn_order_indicator.update_turn_order(characters, current_character_index)

# 战斗日志相关方法
func log_attack(attacker_name: String, target_name: String, damage: int) -> void:
	if battle_log_panel:
		battle_log_panel.log_attack(attacker_name, target_name, damage)


func log_defend(character_name: String) -> void:
	if battle_log_panel:
		battle_log_panel.log_defend(character_name)


func log_skill(caster_name: String, skill_name: String, target_names: Array, effect_description: String = "") -> void:
	if battle_log_panel:
		battle_log_panel.log_skill(caster_name, skill_name, target_names, effect_description)


func log_damage(target_name: String, damage: int, source: String = "") -> void:
	if battle_log_panel:
		battle_log_panel.log_damage(target_name, damage, source)


func log_heal(target_name: String, amount: int, source: String = "") -> void:
	if battle_log_panel:
		battle_log_panel.log_heal(target_name, amount, source)

# 角色详情面板相关方法
func show_character_details(character: Character) -> void:
	if not _character_detail_panel:
		_character_detail_panel = $CharacterDetailPanel
	# 显示角色详情
	_character_detail_panel.show_character_details(character)

func _on_character_detail_panel_closed() -> void:
	pass

# 处理UI信号并转发给BattleScene
func _on_action_menu_attack_pressed() -> void:
	action_attack_pressed.emit()

func _on_action_menu_defend_pressed() -> void:
	action_defend_pressed.emit()

func _on_action_menu_skill_pressed() -> void:
	action_skill_pressed.emit()

func _on_action_menu_item_pressed() -> void:
	action_item_pressed.emit()

func _on_skill_selected(skill: SkillData) -> void:
	skill_selected.emit(skill)

func _on_skill_selection_cancelled() -> void:
	skill_selection_cancelled.emit()

func _on_target_selected(target: Character) -> void:
	target_selected.emit(target)

func _on_target_selection_cancelled() -> void:
	target_selection_cancelled.emit()
