extends Node2D
class_name CharacterWithGAS

## 集成 godot_ability_system 和 turn_based_combat_system 的角色类
## 参考 base_combat_character.gd 的实现，但使用 godot_ability_system 作为底层系统

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

#region --- 组件引用 ---
# turn_based_combat_system 组件
@onready var combat_component: CharacterCombatComponent = %CharacterCombatComponent
@onready var ai_component: CharacterAIComponent = %CharacterAIComponent

# godot_ability_system 组件
@onready var ability_component: GameplayAbilityComponent = %GameplayAbilityComponent
@onready var vital_component: GameplayVitalAttributeComponent = %GameplayVitalAttributeComponent

# 适配器
@onready var adapter: AbilitySystemAdapter = %AbilitySystemAdapter

# UI 组件
@onready var state_indicator : StateIndicator = $StateIndicator
@onready var character_info_container : CharacterInfoContainer = %CharacterInfoContainer
@onready var sprite_2d : Sprite2D = %Sprite2D
@onready var animation_player : AnimationPlayer = %AnimationPlayer
@onready var character_click_area: Area2D = %CharacterClickArea
#endregion

#region --- 导出属性 ---
@export var character_data: CharacterDataWithGAS = null  ## 新版角色配置
@export var is_player : bool = true
## 目标偏移量
@export var target_move_offset : Vector2 = Vector2(80, 0)
#endregion

#region --- 内部变量 ---
var _original_position : Vector2 = Vector2.ZERO
var cast_marker : Marker2D
#endregion

#region --- 接口属性（turn_based_combat_system 需要） ---
var character_name : StringName:
	get:
		if character_data:
			return character_data.character_name
		return &""
	set(value): assert(false, "cannot set character_name")

var is_alive : bool:
	get: return current_hp > 0

var speed: float:
	get:
		if vital_component:
			return vital_component.get_value(&"Speed", 100.0)
		return 100.0
	set(value): assert(false, "cannot set speed")

var current_hp: float:
	get: 
		if vital_component:
			return vital_component.get_vital_value(&"health")
		return 0.0
	set(value): assert(false, "cannot set current_hp")

var current_mp: float:
	get: return vital_component.get_vital_value(&"mana") if vital_component else 0.0
	set(value): assert(false, "cannot set current_mp")

var element: int:
	get: return combat_component.element if combat_component else 0
	set(value): assert(false, "cannot set element")

var can_action: bool:
	get:
		if not combat_component:
			return false
		return combat_component.can_action
	set(value): assert(false, "cannot set can_action")
#endregion

#region --- 信号 ---
signal character_defeated
signal character_clicked(character)
#endregion

#region --- 生命周期 ---
func _ready() -> void:
	if state_indicator:
		state_indicator.hide()
	
	if is_instance_valid(character_data) and is_instance_valid(sprite_2d):
		sprite_2d.position += character_data.sprite_offset
	
	if not is_player and is_instance_valid(sprite_2d):
		sprite_2d.flip_h = true

	_original_position = global_position
	_setup_character_click_area()
	
	# 配置适配器（如果组件已准备好）
	if adapter:
		_configure_adapter()

## 初始化角色
func initialize(battle_manager: BattleManager, p_cast_marker: Marker2D) -> void:
	if not character_data:
		push_error("角色场景 " + name + " 没有分配CharacterDataWithGAS!")
		return
	
	# 初始化 godot_ability_system 组件
	_initialize_ability_system()
	
	# 初始化 turn_based_combat_system 组件
	_initialize_combat_system(battle_manager)
	
	# 初始化UI显示
	# 注意：CharacterInfoContainer 需要 BaseCombatCharacter 类型
	# 如果需要使用现有的 UI，可以让 CharacterWithGAS 继承 BaseCombatCharacter
	# 或者创建一个适配的 UI 组件
	if character_info_container:
		# 暂时注释掉，需要适配 UI 组件或修改 CharacterInfoContainer 支持鸭子类型
		# character_info_container.initialize(self)
		_update_ui_manually()
	_setup_animations()

	cast_marker = p_cast_marker

	print("%s initialized. HP: %.1f/%.1f, Attack: %.1f" % [
		character_name, 
		current_hp, 
		vital_component.get_vital_value(&"Health") if vital_component else 0.0,
		vital_component.get_value(&"AttackPower", 0.0) if vital_component else 0.0
	])
#endregion

#region --- 接口方法（turn_based_combat_system 需要） ---
## 执行动作
func execute_action(action_type: CharacterCombatComponent.ActionType, target: Node = null, params: Dictionary = {}) -> Dictionary:
	if not combat_component:
		return {"success": false, "error": "战斗组件未初始化"}
	z_index = 128
	var result = await combat_component.execute_action(action_type, target, params)
	z_index = 0
	return result

## 受到伤害
func take_damage(base_damage: float, source: Node, p_element: int, is_melee: bool = false) -> float:
	if not combat_component:
		return 0.0
	var result = await combat_component.take_damage(base_damage, source, p_element, is_melee)
	spawn_damage_number(result, Color.RED)
	return result

## 治疗
func heal(amount: float) -> float:
	if not combat_component:
		return 0.0
	var result = combat_component.heal(amount)
	spawn_damage_number(result, Color.GREEN)
	return result

## 使用魔法值
func use_mp(amount: float) -> void:
	if adapter:
		adapter.use_mp(amount)

## 回合开始
func on_turn_start(battle_manager: BattleManager) -> void:
	if combat_component:
		await combat_component.on_turn_start(battle_manager)

## 回合结束
func on_turn_end(battle_manager: BattleManager) -> void:
	if combat_component:
		combat_component.on_turn_end(battle_manager)

## 初始化战斗（接口方法，由战斗系统调用）
func initialize_battle(battle_manager: Node, p_cast_marker: Marker2D = null) -> void:
	initialize(battle_manager, p_cast_marker)

## 获取技能组件（适配器会通过这个访问）
func get_skill_component() -> Node:
	return adapter if adapter else null

## 获取战斗组件
func get_combat_component() -> Node:
	return combat_component

## 获取AI组件
func get_ai_component() -> Node:
	return ai_component
#endregion

#region --- 辅助方法 ---
## 生成伤害数字
func spawn_damage_number(amount: float, color : Color, prefix : String = "") -> void:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -50)
	damage_number.show_damage(amount, false, color, prefix)

## 播放动画
func play_animation(animation_name: String) -> void:
	if not animation_player:
		return
	
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		await animation_player.animation_finished
		animation_player.play(&"idle")
	else:
		push_warning("动画 %s 不存在" % animation_name)

## 移动到目标
func move_to_target(target: Node) -> void:
	var move_offset = target_move_offset * (1 if target.is_player else -1)
	await move_to(target.global_position + move_offset)

## 移动到施法位置
func move_to_cast_marker() -> void:
	if cast_marker:
		await move_to(cast_marker.global_position)

## 返回原位
func move_back() -> void:
	await move_to(_original_position)

## 移动到指定位置
func move_to(target_position: Vector2) -> void:
	var tween : Tween = create_tween()
	tween.tween_property(self, "global_position", target_position, 0.2)
	await tween.finished

## 获取角色名称（用于显示）
func get_character_name() -> String:
	return character_name
#endregion

#region --- 初始化方法 ---
## 初始化 godot_ability_system 组件
func _initialize_ability_system() -> void:
	# 优先使用 character_data_with_gas，否则使用 character_data
	if not character_data:
		return
	
	# 步骤1: 初始化 Vital 组件（包含属性功能，因为 GameplayVitalAttributeComponent 继承自 GameplayAttributeComponent）
	if vital_component:
		var attribute_sets: Array[GameplayAttributeSet] = []
		
		# 优先使用 CharacterDataWithGAS 中的属性集
		if character_data and character_data.attribute_set_resource:
			attribute_sets.append(character_data.attribute_set_resource)
		# 否则尝试加载预定义的 GameplayAttributeSet 资源
		else:
			var gameplay_attribute_set = _load_character_attribute_set()
			if gameplay_attribute_set:
				attribute_sets.append(gameplay_attribute_set)
		
		var vitals: Array[GameplayVital] = []
		
		# 创建 Health Vital
		var health_vital = _create_health_vital()
		if health_vital:
			vitals.append(health_vital)
		
		# 创建 Mana Vital
		var mana_vital = _create_mana_vital()
		if mana_vital:
			vitals.append(mana_vital)
		
		# 初始化 Vital 组件（传入属性集和 Vital 数组）
		vital_component.initialize(attribute_sets, vitals)
	
	# 步骤3: 初始化技能组件
	if ability_component:
		# 学习技能（需要将 SkillData 转换为 GameplayAbilityDefinition）
		# 或者直接使用 GameplayAbilityDefinition 资源
		var skills_to_learn = []
		if character_data and character_data.skills:
			skills_to_learn = character_data.skills
		for skill in skills_to_learn:
				# 如果有映射，使用映射的 GameplayAbilityDefinition
				if adapter and skill in adapter._skill_data_to_ability_map:
					var ability_def = adapter._skill_data_to_ability_map[skill]
					if ability_def is GameplayAbilityDefinition:
						ability_component.learn_ability(ability_def)

	# 状态组件会自动初始化，无需手动调用

## 初始化战斗系统组件
func _initialize_combat_system(battle_manager: BattleManager) -> void:
	if not combat_component:
		push_error("战斗组件未初始化！")
		return
	
	# 初始化战斗组件
	var attack_skill = character_data.get("attack_skill") if character_data else null
	var defense_skill = character_data.get("defense_skill") if character_data else null
	var element_value = character_data.get("element") if character_data else 0
	combat_component.initialize(element_value, attack_skill, defense_skill)
	
	# 连接组件信号
	if not combat_component.character_defeated.is_connected(_on_character_defeated):
		combat_component.character_defeated.connect(_on_character_defeated)
	
	# 初始化AI组件
	if ai_component:
		ai_component.initialize(battle_manager)
		if character_data:
			ai_component.behavior_resource = character_data.ai_behavior

## 配置适配器
func _configure_adapter() -> void:
	if not adapter:
		return
	
	# 配置适配器的组件引用
	# 注意：适配器会在 _ready() 中自动查找组件，但手动设置可以确保引用正确
	adapter.ability_component = ability_component
	adapter.vital_component = vital_component
	# status_component 会由适配器自动查找，无需手动设置
	
	# 如果需要，注册技能映射（将 SkillData 映射到 GameplayAbilityDefinition）
	# 这里假设有转换逻辑
	if character_data:
		_register_skill_mappings()

## 注册技能映射（如果需要兼容旧的 SkillData）
func _register_skill_mappings() -> void:
	if not adapter or not character_data:
		return
	
	# 这里需要将 SkillData 转换为 GameplayAbilityDefinition
	# 或者创建映射关系
	# 示例：
	# for skill in character_data.skills:
	#     var ability_def = _convert_skill_to_ability(skill)
	#     if ability_def:
	#         adapter.register_skill_mapping(skill, ability_def)
	pass

## 加载角色的 GameplayAttributeSet 资源
## 优先从 CharacterDataWithGAS 资源加载，否则根据角色名称映射
func _load_character_attribute_set() -> GameplayAttributeSet:
	# 优先使用 CharacterDataWithGAS
	if character_data and character_data.attribute_set_resource:
		return character_data.attribute_set_resource
	
	# 否则根据角色名称映射到对应的角色配置资源
	if not character_data:
		return null
	
	var character_name_lower = character_data.character_name.to_lower()
	var character_data_path: String = ""
	
	# 根据角色名称映射到角色配置资源
	match character_name_lower:
		"勇者":
			character_data_path = "res://resources/characters_data_with_gas/player_assassin_with_gas.tres"
		"格罗姆尼尔":
			character_data_path = "res://resources/characters_data_with_gas/player_crystal_mauler_with_gas.tres"
		"哥布林":
			character_data_path = "res://resources/characters_data_with_gas/enemy_goblin_with_gas.tres"
		"蘑菇怪":
			character_data_path = "res://resources/characters_data_with_gas/enemy_mushroom_with_gas.tres"
		_:
			# 如果找不到映射，返回 null，将使用转换逻辑
			return null
	
	# 加载角色配置资源并获取属性集
	if ResourceLoader.exists(character_data_path):
		var char_data = load(character_data_path) as CharacterDataWithGAS
		if char_data and char_data.attribute_set_resource:
			return char_data.attribute_set_resource
	
	return null

## 创建 Health Vital
func _create_health_vital() -> GameplayVital:
	# 使用 godot_ability_system 提供的 HealthVital 实现
	var health_vital := HealthVital.new()
	return health_vital

## 创建 Mana Vital
func _create_mana_vital() -> GameplayVital:
	# 使用 godot_ability_system 提供的 ManaVital 实现
	var mana_vital := ManaVital.new()
	return mana_vital

## 转换技能（将 SkillData 转换为 GameplayAbilityDefinition）
## 注意：这是一个辅助方法，实际项目中可能需要更复杂的转换逻辑
func _convert_skill_to_ability(_skill_data: Resource) -> GameplayAbilityDefinition:
	# 这里需要实现转换逻辑
	# 或者直接使用新的 GameplayAbilityDefinition 资源
	push_warning("CharacterWithGAS: 需要实现 SkillData 到 GameplayAbilityDefinition 的转换，或直接使用 GameplayAbilityDefinition 资源")
	return null

## 设置角色动画
func _setup_animations() -> void:
	if not animation_player:
		return
	
	if not character_data:
		return
	
	var anim_library = character_data.animation_library
	if anim_library:
		animation_player.remove_animation_library(&"")
		animation_player.add_animation_library(&"", anim_library)
		animation_player.play(&"idle")
	else:
		push_warning("找不到动画库，无法设置动画")

## 设置角色点击区域
func _setup_character_click_area() -> void:
	if not character_click_area:
		return
	
	character_click_area.mouse_entered.connect(_on_character_mouse_entered)
	character_click_area.mouse_exited.connect(_on_character_mouse_exited)
	character_click_area.input_event.connect(_on_character_input_event)
#endregion

#region --- 信号处理 ---
func _on_character_defeated() -> void:
	if state_indicator:
		state_indicator.hide_indicator()
	modulate = Color(0.5, 0.5, 0.5, 0.5)
	character_defeated.emit()

func _on_character_mouse_entered() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	if sprite_2d:
		sprite_2d.modulate = Color(1.2, 1.2, 1.2)

func _on_character_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if sprite_2d:
		sprite_2d.modulate = Color.WHITE

func _on_character_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		character_clicked.emit(self)

## 手动更新UI（如果 CharacterInfoContainer 不支持当前类型）
func _update_ui_manually() -> void:
	if not character_info_container:
		return
	
	# 更新名称
	if character_info_container.has_method("_update_name_display"):
		character_info_container._update_name_display()
	
	# 更新属性条
	if character_info_container.has_method("_update_attribute_bars"):
		character_info_container._update_attribute_bars()
#endregion
