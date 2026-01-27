# 插件集成指南

本指南说明如何在业务层集成 `turn_based_combat_system` 和 `godot_ability_system` 两个插件。

## 架构概览

```
业务层 (Character)
    ├── turn_based_combat_system 组件
    │   └── CharacterCombatComponent (战斗逻辑)
    │
    ├── godot_ability_system 组件
    │   ├── GameplayAbilityComponent (技能管理)
    │   ├── GameplayVitalAttributeComponent (生命值/魔法值)
    │   ├── GameplayAttributeComponent (属性管理)
    │   └── GameplayStatusComponent (状态管理)
    │
    └── 适配器层
        └── AbilitySystemAdapter (桥接两个系统)
```

## 集成步骤

### 1. 在角色场景中添加组件

在你的 Character 场景中添加以下节点结构：

```
Character (Node2D)
├── GameplayAbilityComponent (godot_ability_system)
├── GameplayVitalAttributeComponent (godot_ability_system)
├── GameplayAttributeComponent (godot_ability_system)
├── GameplayStatusComponent (godot_ability_system)
├── CharacterCombatComponent (turn_based_combat_system)
└── AbilitySystemAdapter (适配器)
```

### 2. 配置适配器

在 `AbilitySystemAdapter` 中配置引用的组件：

```gdscript
# 在编辑器中设置，或通过代码设置
@onready var adapter: AbilitySystemAdapter = $AbilitySystemAdapter
adapter.ability_component = $GameplayAbilityComponent
adapter.vital_component = $GameplayVitalAttributeComponent
adapter.attribute_component = $GameplayAttributeComponent
adapter.status_component = $GameplayStatusComponent
```

### 3. 在 Character 类中实现接口

你的 Character 类需要实现 `turn_based_combat_system` 需要的接口：

```gdscript
extends Node2D
class_name Character

# 组件引用
@onready var combat_component: CharacterCombatComponent = $CharacterCombatComponent
@onready var ability_component: GameplayAbilityComponent = $GameplayAbilityComponent
@onready var vital_component: GameplayVitalAttributeComponent = $GameplayVitalAttributeComponent
@onready var adapter: AbilitySystemAdapter = $AbilitySystemAdapter

# 实现接口属性
var character_name: StringName = "Hero"
var is_alive: bool:
    get:
        return vital_component.get_vital_value(&"Health") > 0
var speed: float:
    get:
        return attribute_component.get_value(&"Speed", 100.0)
var current_hp: float:
    get:
        return vital_component.get_vital_value(&"Health")
var current_mp: float:
    get:
        return vital_component.get_vital_value(&"Mana")
var element: int = 0
var can_action: bool:
    get:
        return combat_component.can_action

signal character_defeated

# 实现接口方法
func execute_action(action_type: int, target: Node = null, params: Dictionary = {}) -> Dictionary:
    return await combat_component.execute_action(action_type, target, params)

func take_damage(base_damage: float, source: Node, element: int, is_melee: bool = false) -> float:
    return await combat_component.take_damage(base_damage, source, element, is_melee)

func heal(amount: float) -> float:
    return combat_component.heal(amount)

func use_mp(amount: float) -> void:
    adapter.use_mp(amount)

func on_turn_start(battle_manager: Node) -> void:
    combat_component.on_turn_start(battle_manager)

func on_turn_end(battle_manager: Node) -> void:
    combat_component.on_turn_end(battle_manager)

func initialize_battle(battle_manager: Node, cast_marker: Node2D = null) -> void:
    # 初始化战斗相关逻辑
    pass

# 提供技能组件访问（适配器会通过这个访问）
func get_skill_component() -> Node:
    return adapter
```

### 4. 初始化组件

在 Character 的 `_ready()` 中初始化：

```gdscript
func _ready() -> void:
    # 初始化 godot_ability_system 组件
    var attribute_set = load("res://your_attribute_set.tres")
    vital_component.initialize([attribute_set], [health_vital, mana_vital])
    
    # 学习技能
    var fireball_ability = load("res://abilities/fireball.tres")
    ability_component.learn_ability(fireball_ability)
    
    # 初始化战斗组件
    combat_component.initialize()
```

### 5. 技能数据映射（可选）

如果你需要同时使用旧的 `SkillData` 和新的 `GameplayAbilityDefinition`，可以在适配器中建立映射：

```gdscript
# 在适配器中
func map_skill_data(skill_data: Resource, ability_def: GameplayAbilityDefinition) -> void:
    if skill_data.has_method("get") and skill_data.get("skill_id"):
        var skill_id = skill_data.get("skill_id")
        _skill_data_map[skill_id] = ability_def
```

## 数据转换

### SkillData -> GameplayAbilityDefinition

如果需要将旧的 `SkillData` 转换为 `GameplayAbilityDefinition`，可以创建一个转换工具：

```gdscript
# 工具脚本
static func convert_skill_to_ability(skill_data: Resource) -> GameplayAbilityDefinition:
    var ability_def = GameplayAbilityDefinition.new()
    ability_def.ability_id = skill_data.skill_id
    ability_def.ability_name = skill_data.skill_name
    ability_def.description = skill_data.description
    
    # 添加Cost特性（如果技能有MP消耗）
    if skill_data.mp_cost > 0:
        var cost_feature = VitalCost.new()
        cost_feature.vital_id = &"Mana"
        cost_feature.amount = skill_data.mp_cost
        ability_def.features.append(cost_feature)
    
    # 转换技能效果到GameplayEffect
    # ... 转换逻辑
    
    return ability_def
```

## 注意事项

1. **Vital ID 约定**：
   - 生命值：使用 `"Health"` 或 `"HP"`
   - 魔法值：使用 `"Mana"` 或 `"MP"`
   - 可以在适配器中配置自定义ID

2. **属性ID约定**：
   - 速度：使用 `"Speed"`
   - 攻击力：使用 `"AttackPower"` 或 `"Attack"`
   - 防御力：使用 `"DefensePower"` 或 `"Defense"`

3. **信号连接**：
   - 适配器会自动连接必要的信号
   - 确保组件在 `_ready()` 时已正确初始化

4. **状态限制**：
   - 通过状态标签控制动作限制
   - 状态需要有 `"block_action"` 或 `"any_action"` 标签才会限制动作

## 完整示例

参考 `examples/character_with_both_systems.tscn` 查看完整示例。

