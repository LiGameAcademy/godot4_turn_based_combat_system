extends Node2D
class_name Character

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

# 引用场景中的节点
@onready var character_rect := $Container/CharacterRect
@onready var state_indicator : StateIndicator = $StateIndicator
# 组件引用
@onready var combat_component: CharacterCombatComponent = %CharacterCombatComponent
@onready var skill_component: CharacterSkillComponent = %CharacterSkillComponent
@onready var ai_component: CharacterAIComponent = %CharacterAIComponent
@onready var character_info_container : CharacterInfoContainer = %CharacterInfoContainer
@onready var sprite_2d : Sprite2D = %Sprite2D
@onready var animation_player : AnimationPlayer = %AnimationPlayer
@onready var character_click_area: Area2D = %CharacterClickArea

@export var character_data: CharacterData
@export var is_player : bool = true

#region --- 常用属性的便捷Getter ---
var current_hp: float:
	get: return skill_component.get_attribute_current_value(&"CurrentHealth") if skill_component else 0.0
	set(value): assert(false, "cannot set current_hp")
var max_hp: float:
	get: return skill_component.get_attribute_current_value(&"MaxHealth") if skill_component else 0.0
	set(value): assert(false, "cannot set max_hp")
var current_mp: float:
	get: return skill_component.get_attribute_current_value(&"CurrentMana") if skill_component else 0.0
	set(value): assert(false, "cannot set current_mp")
var max_mp: float:
	get: return skill_component.get_attribute_current_value(&"MaxMana") if skill_component else 0.0
	set(value): assert(false, "cannot set max_mp")
var attack_power: float:
	get: return skill_component.get_attribute_current_value(&"AttackPower") if skill_component else 0.0
	set(value): assert(false, "cannot set attack_power")
var defense_power: float:
	get: return skill_component.get_attribute_current_value(&"DefensePower") if skill_component else 0.0
	set(value): assert(false, "cannot set defense_power")
var speed: float:
	get: return skill_component.get_attribute_current_value(&"Speed") if skill_component else 0.0
	set(value): assert(false, "cannot set speed")
var magic_attack : float:
	get: return skill_component.get_attribute_current_value(&"MagicAttack") if skill_component else 0.0
	set(value): assert(false, "cannot set magic_attack")
var magic_defense : float:
	get: return skill_component.get_attribute_current_value(&"MagicDefense") if skill_component else 0.0
	set(value): assert(false, "cannot set magic_defense")
var character_name : StringName:
	get: return character_data.character_name if character_data else "" 
	set(value): assert(false, "cannot set character_name")
#endregion

# 属性委托给战斗组件
var is_alive : bool = true:							## 生存状态标记
	get: return current_hp > 0
var element: int:									## 元素类型
	get : return combat_component.element
var can_action: bool = true:
	get: 
		if not combat_component:
			push_error("战斗组件未初始化！")
			return false
		return combat_component.can_action

# 信号 - 这些信号将转发组件的信号
signal character_defeated																														## 当角色死亡时触发
signal character_clicked(character)

func _ready() -> void:
	if state_indicator:
		state_indicator.hide()
	sprite_2d.position += character_data.sprite_offset
	if not is_player:
		sprite_2d.flip_h = true
	
	# 设置鼠标交互
	_setup_character_click_area()

## 初始化角色
func initialize(battle_manager: BattleManager) -> void:
	if character_data:
		_initialize_from_data(character_data)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")
	# 初始化组件
	_init_components(battle_manager)

	# 初始化UI显示
	character_info_container.initialize(self)
	_setup_animations()

	print("%s initialized. HP: %.1f/%.1f, Attack: %.1f" % [character_data.character_name, current_hp, max_hp, attack_power])

## 玩家选择行动
func execute_action(action_type: CharacterCombatComponent.ActionType, target: Character = null, params: Dictionary = {}) -> void:
	if not combat_component:
		return
	combat_component.execute_action(action_type, target, params)

## 生成伤害数字
func spawn_damage_number(amount: float, color : Color, prefix : String = "") -> void:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -50)
	damage_number.show_damage(amount, false, color, prefix)

## 伤害处理方法
func take_damage(base_damage: float) -> float:
	if not combat_component:
		return 0.0
	var result = combat_component.take_damage(base_damage)
	spawn_damage_number(result, Color.RED)
	return result

## 治疗处理方法
func heal(amount: float) -> float:
	if not combat_component:
		return 0.0
	var result = combat_component.heal(amount)
	spawn_damage_number(result, Color.GREEN)
	return result

## 开始回合
func on_turn_start(battle_manager : BattleManager) -> void:
	if combat_component:
		combat_component.on_turn_start(battle_manager)

## 结束回合
func on_turn_end(battle_manager : BattleManager) -> void:
	if combat_component:
		combat_component.on_turn_end(battle_manager)

## 是否足够释放技能MP
func has_enough_mp_for_any_skill() -> bool:
	if skill_component:
		return skill_component.has_enough_mp_for_any_skill()
	return false

## 检查是否有足够的MP使用指定技能
func has_enough_mp_for_skill(skill: SkillData) -> bool:
	if skill_component:
		return skill_component.has_enough_mp_for_skill(skill)
	return false

## 使用MP
func use_mp(amount: float) -> bool:
	if skill_component:
		return skill_component.use_mp(amount)
	return false

## 恢复MP
func restore_mp(amount: float) -> float:
	if skill_component:
		return skill_component.restore_mp(amount)
	return 0.0

## 播放动画
func play_animation(animation_name: String) -> void:
	print("%s 播放动画：%s" % [character_name, animation_name])
	
	# 检查是否有对应的动画
	if animation_player.has_animation(animation_name):
		# 直接播放动画
		animation_player.play(animation_name)
		await animation_player.animation_finished
		animation_player.play(&"idle")
	else:
		push_warning("动画 %s 不存在" % animation_name)
		
## 应用技能状态
func apply_skill_status(status_instance: SkillStatusData, source_character: Character, effect_data_from_skill: SkillEffectData) -> Dictionary:
	if skill_component:
		return skill_component.apply_status(status_instance, source_character, effect_data_from_skill)
	return {"applied_successfully": false, "reason": "invalid_status_template"}

## 获取技能组件
func get_skill_component() -> CharacterSkillComponent:
	return skill_component

## 获取AI组件
func get_ai_component() -> CharacterAIComponent:
	return ai_component

## 初始化组件
func _init_components(battle_manager: BattleManager) -> void:
	if not combat_component:
		push_error("战斗组件未初始化！")
		return
	if not skill_component:
		push_error("技能组件未初始化！")
		return
	
	combat_component.initialize(character_data.element, character_data.attack_skill, character_data.defense_skill)

	# 连接组件信号
	if not combat_component.character_defeated.is_connected(_on_character_defeated):
		combat_component.character_defeated.connect(_on_character_defeated)

	ai_component.initialize(battle_manager)

## 初始化玩家数据
func _initialize_from_data(data: CharacterData) -> void:
	# 保存数据引用
	character_data = data
	ai_component.behavior_resource = data.ai_behavior
	skill_component.initialize(character_data.attribute_set_resource, character_data.skills.duplicate(true))
	print(character_name + " 初始化完毕，HP: " + str(current_hp) + "/" + str(max_hp))

## 设置角色动画
func _setup_animations() -> void:
	if animation_player:
		animation_player.remove_animation_library(&"")
		animation_player.add_animation_library(&"", character_data.animation_library)
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

#region --- 信号处理 ---
## 当角色死亡时调用
func _on_character_defeated() -> void:
	if state_indicator:
		state_indicator.hide_indicator()
	modulate = Color(0.5, 0.5, 0.5, 0.5) # 变灰示例
	character_defeated.emit()

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
#endregion
