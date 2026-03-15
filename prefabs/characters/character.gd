extends Node2D

@onready var character_combat_component: CharacterCombatComponent = %CharacterCombatComponent
@onready var character_ai_component: CharacterAIComponent = %CharacterAIComponent
@onready var gas_skill_component_adapter: GAS_SkillComponentAdapter = $GAS_SkillComponentAdapter

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var state_indicator: StateIndicator = $StateIndicator
@onready var sprite_2d: Sprite2D = %Sprite2D
@onready var character_click_area: Area2D = %CharacterClickArea
@onready var character_info_container: CharacterInfoContainer = %CharacterInfoContainer

## 目标偏移量
@export var target_move_offset : Vector2 = Vector2(80, 0)

@export var is_player : bool = true
var _character_data : CharacterData
var _original_position : Vector2 = Vector2.ZERO		## 原始位置
var _cast_marker : Marker2D

signal character_clicked(character : Node)

func _ready() -> void:
	_setup_animations()
	if state_indicator:
		state_indicator.hide()
	sprite_2d.position += _character_data.sprite_offset
	if not is_player:
		sprite_2d.flip_h = true

	_original_position = global_position

	# 设置鼠标交互
	_setup_character_click_area()

	character_combat_component.action_started.connect(_on_action_started)
	character_combat_component.action_executed.connect(_on_action_executed)

func setup(character_data : CharacterData) -> void:
	_character_data = character_data

func initialize(battle_manager: BattleManager, cast_marker: Marker2D) -> void:
	_init_components(battle_manager)
	character_info_container.initialize(self)
	_cast_marker = cast_marker

	var health_vital : HealthVital = gas_skill_component_adapter.get_attribute_vital("health")
	health_vital.damage_applied.connect(
		func(damage_info: GameplayDamageInfo, _final_damage: float) -> void:
			play_animation("hit")
			await animation_player.animation_finished
			AbilityEventBus.trigger_game_event("damage_received_after_hit", {
				"damage_info": damage_info
		})
	)

func get_combat_component() -> CharacterCombatComponent:
	return character_combat_component

func get_skill_component() -> SkillComponentInterface:
	return gas_skill_component_adapter

func get_ai_component() -> CharacterAIComponent:
	return character_ai_component
	
func get_character_name() -> String:
	return _character_data.character_name

func get_icon() -> Texture2D:
	return _character_data.icon

## 是否闲置
func is_idle() -> bool:
	return animation_player.current_animation == "idle"

func play_animation(animation_name: String, _animation_speed: float = 1.0) -> void:
	print("%s 播放动画：%s" % [_character_data.character_name, animation_name])
	
	# 检查是否有对应的动画
	if animation_player.has_animation(animation_name):
		# 直接播放动画
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
	await move_to(_cast_marker.global_position)

## 返回
func move_back() -> void:
	await move_to(_original_position)

## 移动到
func move_to(target_position: Vector2) -> void:
	var tween : Tween = create_tween()
	tween.tween_property(self, "global_position", target_position, 0.2)
	await tween.finished

## 设置角色动画库
func _setup_animations() -> void:
	if animation_player:
		animation_player.remove_animation_library(&"")
		animation_player.add_animation_library(&"", _character_data.animation_library)
		animation_player.play(&"idle")
	else:
		push_error("找不到AnimationPlayer组件，无法设置动画")

## 设置角色点击区域和鼠标交互
func _setup_character_click_area() -> void:
	if not character_click_area:
		push_error("Character: 找不到CharacterClickArea节点")
		return
	
	# 连接鼠标信号
	character_click_area.mouse_entered.connect(_on_character_mouse_entered)
	character_click_area.mouse_exited.connect(_on_character_mouse_exited)
	character_click_area.input_event.connect(_on_character_input_event)

## 初始化组件
func _init_components(battle_manager: BattleManager) -> void:
	if not is_instance_valid(character_combat_component):
		push_error("战斗组件未初始化！")
		return
	if not is_instance_valid(gas_skill_component_adapter):
		push_error("技能适配器未初始化！")
		return
	
	var attack_skill_id = _character_data.attack_skill.ability_id if is_instance_valid(_character_data.attack_skill) else ""
	var defense_skill_id = _character_data.defense_skill.ability_id if is_instance_valid(_character_data.defense_skill) else ""
	var initial_skills := _character_data.initial_skills.duplicate(true)
	initial_skills.append(_character_data.attack_skill)
	initial_skills.append(_character_data.defense_skill)
	character_combat_component.initialize(_character_data.element, attack_skill_id, defense_skill_id)
	gas_skill_component_adapter.initialize(_character_data.attribute_sets, _character_data.vitals, initial_skills)
	character_ai_component.initialize(battle_manager)

#region --- 信号处理 ---
## 当鼠标进入角色区域
func _on_character_mouse_entered() -> void:
	# 改变鼠标光标
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	
	# 添加高亮效果
	sprite_2d.modulate = Color(1.2, 1.2, 1.2)

## 当鼠标离开角色区域
func _on_character_mouse_exited() -> void:
	# 恢复默认光标
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	# 移除高亮效果
	sprite_2d.modulate = Color.WHITE

## 处理角色区域的输入事件
func _on_character_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# 检测鼠标左键点击
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 发射点击信号
		character_clicked.emit(self)

## 当动作开始执行时
func _on_action_started(_action_type: CharacterCombatComponent.ActionType, _target: Node, _params: Dictionary) -> void:
	z_index = 128

## 当动作执行完成时
func _on_action_executed(_action_type: CharacterCombatComponent.ActionType, _target: Node, _result: Dictionary) -> void:
	z_index = 0
#endregion
