# 快速开始指南

## 5分钟集成两个插件

### 步骤 1: 创建角色场景

1. 创建新的场景，根节点为 `Node2D`，命名为 `Character`
2. 添加以下子节点：
   - `GameplayAbilityComponent` (godot_ability_system)
   - `GameplayVitalAttributeComponent` (godot_ability_system)
   - `GameplayAttributeComponent` (godot_ability_system)
   - `GameplayStatusComponent` (godot_ability_system)
   - `CharacterCombatComponent` (turn_based_combat_system)
   - `AbilitySystemAdapter` (适配器)

### 步骤 2: 配置适配器

在 `AbilitySystemAdapter` 节点的导出属性中，设置组件引用：
- `ability_component` -> `GameplayAbilityComponent`
- `vital_component` -> `GameplayVitalAttributeComponent`
- `attribute_component` -> `GameplayAttributeComponent`
- `status_component` -> `GameplayStatusComponent`

### 步骤 3: 实现 Character 脚本

```gdscript
extends Node2D
class_name Character

# 组件引用
@onready var combat_component: CharacterCombatComponent = $CharacterCombatComponent
@onready var ability_component: GameplayAbilityComponent = $GameplayAbilityComponent
@onready var vital_component: GameplayVitalAttributeComponent = $GameplayVitalAttributeComponent
@onready var adapter: AbilitySystemAdapter = $AbilitySystemAdapter

# 接口属性
var character_name: StringName = "Hero"
var is_alive: bool:
    get: return vital_component.get_vital_value(&"Health") > 0
var speed: float:
    get: return 100.0  # 从属性组件获取
var current_hp: float:
    get: return vital_component.get_vital_value(&"Health")
var current_mp: float:
    get: return vital_component.get_vital_value(&"Mana")
var element: int = 0
var can_action: bool:
    get: return combat_component.can_action

signal character_defeated

# 接口方法
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
    pass

func get_skill_component() -> Node:
    return adapter

func _ready() -> void:
    # 初始化组件
    combat_component.initialize()
    
    # 连接生命值耗尽信号
    if not vital_component.vital_depleted.is_connected(_on_health_depleted):
        vital_component.vital_depleted.connect(_on_health_depleted)

func _on_health_depleted(vital_id: StringName) -> void:
    if vital_id == &"Health":
        character_defeated.emit()
```

### 步骤 4: 在战斗中使用

```gdscript
# 在 BattleScene 中
var character = preload("res://character.tscn").instantiate()
character.character_name = "Hero"
battle_manager.add_character(character, true)  # true表示玩家队伍
```

完成！现在你的角色已经集成了两个插件。

## 详细说明

更多详细信息请参考：
- [集成指南](INTEGRATION_GUIDE.md) - 完整的集成说明
- [技能系统接口](SKILL_SYSTEM_INTERFACE.md) - 接口约定
- [角色接口](CHARACTER_INTERFACE.md) - 角色接口约定

