extends Node2D
class_name CharacterIntegrationExample

## 业务层角色集成示例
## 展示如何集成 turn_based_combat_system 和 godot_ability_system 两个插件

# turn_based_combat_system 组件
@onready var combat_component: CharacterCombatComponent = $CharacterCombatComponent

# godot_ability_system 组件
@onready var ability_component: GameplayAbilityComponent = $GameplayAbilityComponent
@onready var vital_component: GameplayVitalAttributeComponent = $GameplayVitalAttributeComponent
@onready var attribute_component: GameplayAttributeComponent = $GameplayAttributeComponent
@onready var status_component: GameplayStatusComponent = $GameplayStatusComponent

# 适配器
@onready var adapter: AbilitySystemAdapter = $AbilitySystemAdapter

# 实现 turn_based_combat_system 需要的接口属性
var character_name: StringName = "Hero"
var is_alive: bool:
	get:
		if not vital_component:
			return true
		return vital_component.get_vital_value(&"Health") > 0
var speed: float:
	get:
		if not attribute_component:
			return 100.0
		return attribute_component.get_value(&"Speed", 100.0)
var current_hp: float:
	get:
		if not vital_component:
			return 100.0
		return vital_component.get_vital_value(&"Health")
var current_mp: float:
	get:
		if not vital_component:
			return 50.0
		return vital_component.get_vital_value(&"Mana")
var element: int = 0
var can_action: bool:
	get:
		return combat_component.can_action if combat_component else true

signal character_defeated

func _ready() -> void:
	# 初始化适配器（自动查找组件）
	# 适配器会在 _ready 中自动连接组件
	
	# 初始化战斗组件
	if combat_component:
		combat_component.initialize()

## 实现接口方法：执行行动
func execute_action(action_type: int, target: Node = null, params: Dictionary = {}) -> Dictionary:
	if not combat_component:
		return {"success": false, "error": "Combat component not found"}
	return await combat_component.execute_action(action_type, target, params)

## 实现接口方法：受到伤害
func take_damage(base_damage: float, source: Node, element: int, is_melee: bool = false) -> float:
	if not combat_component:
		return 0.0
	return await combat_component.take_damage(base_damage, source, element, is_melee)

## 实现接口方法：治疗
func heal(amount: float) -> float:
	if not combat_component:
		return 0.0
	return combat_component.heal(amount)

## 实现接口方法：使用魔法值
func use_mp(amount: float) -> void:
	if adapter:
		adapter.use_mp(amount)
	elif vital_component:
		vital_component.modify_vital(&"Mana", -amount)

## 实现接口方法：回合开始
func on_turn_start(battle_manager: Node) -> void:
	if combat_component:
		combat_component.on_turn_start(battle_manager)

## 实现接口方法：回合结束
func on_turn_end(battle_manager: Node) -> void:
	if combat_component:
		combat_component.on_turn_end(battle_manager)

## 实现接口方法：初始化战斗
func initialize_battle(battle_manager: Node, cast_marker: Node2D = null) -> void:
	# 可以在这里添加战斗初始化逻辑
	pass

## 提供技能组件访问（适配器会通过这个访问）
func get_skill_component() -> Node:
	return adapter

## 初始化角色数据
func initialize_character(
	character_name_str: String,
	attribute_set: GameplayAttributeSet,
	health_vital: GameplayVital,
	mana_vital: GameplayVital,
	abilities: Array[GameplayAbilityDefinition] = []
) -> void:
	character_name = character_name_str
	
	# 初始化 godot_ability_system 组件
	if vital_component:
		vital_component.initialize([attribute_set], [health_vital, mana_vital])
	
	if attribute_component:
		attribute_component.initialize([attribute_set])
	
	# 学习技能
	if ability_component:
		for ability_def in abilities:
			ability_component.learn_ability(ability_def)
	
	# 连接生命值耗尽信号
	if vital_component:
		if not vital_component.vital_depleted.is_connected(_on_health_depleted):
			vital_component.vital_depleted.connect(_on_health_depleted)

## 生命值耗尽处理
func _on_health_depleted(vital_id: StringName) -> void:
	if vital_id == &"Health" or vital_id == &"HP":
		character_defeated.emit()

