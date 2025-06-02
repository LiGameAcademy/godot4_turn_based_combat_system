extends Node2D
class_name Character

# 组件引用
@onready var defense_indicator : DefenseIndicator = $DefenseIndicator
@onready var combat_component: CharacterCombatComponent = %CharacterCombatComponent
@onready var skill_component: CharacterSkillComponent = %CharacterSkillComponent
@onready var ai_component: CharacterAIComponent = %CharacterAIComponent
@onready var sprite_2d: Sprite2D = %Sprite2D
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var character_info_container: CharacterInfoContainer = %CharacterInfoContainer
@onready var character_click_area: Area2D = %CharacterClickArea

#region --- 常用属性的便捷Getter ---
var current_hp: float:
	get: return skill_component.get_current_value(&"CurrentHealth") if skill_component else 0.0
	set(value): assert(false, "cannot set current_hp")
var max_hp: float:
	get: return skill_component.get_current_value(&"MaxHealth") if skill_component else 0.0
	set(value): assert(false, "cannot set max_hp")
var current_mp: float:
	get: return skill_component.get_current_value(&"CurrentMana") if skill_component else 0.0
	set(value): assert(false, "cannot set current_mp")
var max_mp: float:
	get: return skill_component.get_current_value(&"MaxMana") if skill_component else 0.0
	set(value): assert(false, "cannot set max_mp")
var attack_power: float:
	get: return skill_component.get_current_value(&"AttackPower") if skill_component else 0.0
	set(value): assert(false, "cannot set attack_power")
var defense_power: float:
	get: return skill_component.get_current_value(&"DefensePower") if skill_component else 0.0
	set(value): assert(false, "cannot set defense_power")
var speed: float:
	get: return skill_component.get_current_value(&"Speed") if skill_component else 0.0
	set(value): assert(false, "cannot set speed")
var magic_attack : float:
	get: return skill_component.get_current_value(&"MagicAttack") if skill_component else 0.0
	set(value): assert(false, "cannot set magic_attack")
var magic_defense : float:
	get: return skill_component.get_current_value(&"MagicDefense") if skill_component else 0.0
	set(value): assert(false, "cannot set magic_defense")
var character_name : StringName:
	get: return character_data.character_name if character_data else "" 
	set(value): assert(false, "cannot set character_name")
#endregion

@export var character_data: CharacterData			## 角色数据
@export var is_player : bool = true

# 属性委托给战斗组件
var is_alive : bool = true:							## 生存状态标记
	get: return current_hp > 0
var element: int:									## 元素类型
	get : return combat_component.element

# 信号
signal character_clicked(character)
signal character_defeated

func _enter_tree() -> void:
	if not character_data:
		return
	# 初始化角色动画
	_setup_animations()
	%Sprite2D.position += character_data.sprite_offset

func _ready() -> void:
	# 初始化防御指示器
	defense_indicator.visible = false
	if not is_player:
		sprite_2d.flip_h = true
	
	# 设置鼠标交互
	_setup_character_click_area()

func setup(data: CharacterData) -> void:
	character_data = data

## 初始化角色
func initialize(battle_manager: BattleManager) -> void:
	# 初始化角色数据
	if character_data:
		_initialize_from_data(character_data, battle_manager)
	else:
		push_error("角色场景 " + name + " 没有分配CharacterData!")
	
	# 初始化角色信息容器
	if character_info_container:
		character_info_container.initialize(self)
	
	print("%s initialized. HP: %.1f/%.1f, Attack: %.1f" % [character_data.character_name, current_hp, max_hp, attack_power])

## 执行行动
## [param action_type] 行动类型
## [param target] 目标角色
## [param params] 行动参数
func execute_action(action_type: CharacterCombatComponent.ActionType, target : Character = null, params : Dictionary = {}) -> Dictionary:
	if combat_component:
		return await combat_component.execute_action(action_type, target, params)
	return {"success": false, "error": "战斗组件未初始化"}

## 伤害处理方法
func take_damage(base_damage: float, source: Variant = null) -> float:
	if combat_component:
		return combat_component.take_damage(base_damage, source)
	return 0.0

func heal(amount: float, source: Variant = null) -> float:
	if combat_component:
		return combat_component.heal(amount, source)
	return 0.0

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
func use_mp(amount: float, source: Variant = null) -> bool:
	if skill_component:
		return skill_component.use_mp(amount, source)
	return false

## 恢复MP
func restore_mp(amount: float, source: Variant = null) -> float:
	if skill_component:
		return skill_component.restore_mp(amount, source)
	return 0.0

## 播放动画
## [param animation_name] 动画名称
## [return] 返回一个信号，动画播放完成时会触发
func play_animation(animation_name: StringName) -> void:
	print("%s 播放动画：%s" % [character_name, animation_name])
	
	# 检查是否有对应的动画
	if animation_player.has_animation(animation_name):
		# 直接播放动画
		animation_player.play(animation_name)
		await animation_player.animation_finished
		animation_player.play(&"idle")
	else:
		push_warning("动画 %s 不存在" % animation_name)
		
## 设置角色点击区域和鼠标交互
func _setup_character_click_area() -> void:
	if not character_click_area:
		push_error("Character: 找不到CharacterClickArea节点")
		return
	
	# 连接鼠标信号
	character_click_area.mouse_entered.connect(_on_character_mouse_entered)
	character_click_area.mouse_exited.connect(_on_character_mouse_exited)
	character_click_area.input_event.connect(_on_character_input_event)

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

## 设置角色动画
func _setup_animations() -> void:
	if not character_data:
		return
	animation_player = %AnimationPlayer
	# 使用动画辅助类设置原型动画
	if animation_player:
		#var CharacterAnimations = load("res://scripts/core/character/character_animations.gd")
		#CharacterAnimations.setup_prototype_animations(animation_player)
		animation_player.remove_animation_library(&"")
		animation_player.add_animation_library(&"", character_data.animation_library)
		animation_player.play(&"idle")
	else:
		push_error("找不到AnimationPlayer组件，无法设置动画")

# 注意: UI更新现在由CharacterInfoContainer处理

#region --- 信号处理 ---
## 当状态被应用时调用
func _on_status_applied(status_instance: SkillStatusData):
	if not defense_indicator:
		return
	
	# 检查是否是防御状态
	if status_instance.status_id == &"defend":
		defense_indicator.show_indicator()
		print_rich("[color=cyan]%s 进入防御状态[/color]" % character_data.character_name)

## 当状态被移除时调用
func _on_status_removed(status_id: StringName, _status_instance_data_before_removal: SkillStatusData):
	if not defense_indicator:
		return
	
	# 检查是否是防御状态
	if status_id == &"defend":
		defense_indicator.hide_indicator()
		print_rich("[color=orange]%s 防御状态结束[/color]" % character_data.character_name)

func _on_character_defeated():
	if defense_indicator:
		defense_indicator.hide_indicator()
	modulate = Color(0.5, 0.5, 0.5, 0.5) # 变灰示例
	character_defeated.emit()

#endregion

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
	combat_component.character_defeated.connect(_on_character_defeated)
	
	# 连接状态事件信号
	skill_component.status_applied.connect(_on_status_applied)
	skill_component.status_removed.connect(_on_status_removed)

	ai_component.initialize(battle_manager)

## 初始化玩家数据
func _initialize_from_data(data: CharacterData, battle_manager: BattleManager) -> void:
	# 保存数据引用
	character_data = data
	
	skill_component.initialize(character_data.attribute_set_resource, character_data.skills)
	print(character_name + " 初始化完毕，HP: " + str(current_hp) + "/" + str(max_hp))
	
	# 初始化组件
	_init_components(battle_manager)
