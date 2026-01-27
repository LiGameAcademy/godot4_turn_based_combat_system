# 角色类使用指南

插件提供了 `BaseCombatCharacter` 作为基础角色类，业务层可以选择：

1. **继承 `BaseCombatCharacter`** - 快速启动，适合大多数情况
2. **实现自己的角色类** - 完全自定义，只需实现接口约定（鸭子类型）

## 方式一：继承 BaseCombatCharacter（推荐快速启动）

### 优点
- 快速集成，开箱即用
- 已实现所有必需的接口方法
- 包含完整的组件系统集成
- 包含UI、动画、交互等完整功能

### 使用示例

```gdscript
# 业务层：scenes/characters/my_character.gd
extends BaseCombatCharacter
class_name MyCharacter

# 可以重写方法来自定义行为
func _ready() -> void:
    super._ready()
    # 添加自定义初始化逻辑

func execute_action(action_type: CharacterCombatComponent.ActionType, target: Node = null, params: Dictionary = {}) -> void:
    # 可以添加自定义逻辑
    print("执行自定义行动逻辑")
    # 调用父类方法
    await super.execute_action(action_type, target, params)
```

### 场景设置

1. 创建新场景，根节点为 `Node2D`
2. 将脚本设置为继承 `BaseCombatCharacter`
3. 添加必要的子节点（参考 `BaseCombatCharacter` 的场景结构）

## 方式二：实现自己的角色类（完全自定义）

### 优点
- 完全控制角色实现
- 不依赖插件提供的具体实现
- 可以集成任何技能系统
- 符合鸭子类型设计哲学

### 接口要求

你的角色类需要实现以下接口（参考 `CHARACTER_INTERFACE.md`）：

```gdscript
# 业务层：scenes/characters/custom_character.gd
extends Node2D
class_name CustomCharacter

# 必需的属性
var character_name: StringName = "Hero"
var is_alive: bool = true
var speed: float = 100.0
var current_hp: float = 100.0
var current_mp: float = 50.0
var element: int = 0
var can_action: bool = true

signal character_defeated

# 必需的方法
func execute_action(action_type: int, target: Node = null, params: Dictionary = {}) -> Dictionary:
    # 实现行动逻辑
    return {"success": true}

func take_damage(base_damage: float, source: Node, element: int, is_melee: bool = false) -> float:
    # 实现伤害处理
    current_hp -= base_damage
    if current_hp <= 0:
        is_alive = false
        character_defeated.emit()
    return base_damage

func heal(amount: float) -> float:
    # 实现治疗逻辑
    current_hp = min(current_hp + amount, max_hp)
    return amount

func use_mp(amount: float) -> void:
    current_mp -= amount

func on_turn_start(battle_manager: Node) -> void:
    # 回合开始逻辑
    pass

func on_turn_end(battle_manager: Node) -> void:
    # 回合结束逻辑
    pass

# 可选方法
func initialize_battle(battle_manager: Node, cast_marker: Node2D = null) -> void:
    # 初始化战斗
    pass

func get_skill_component() -> Node:
    # 返回技能系统组件（如果使用组件系统）
    return null
```

### 集成 godot_ability_system

如果使用 `godot_ability_system`，可以配合 `AbilitySystemAdapter`：

```gdscript
extends Node2D
class_name CustomCharacterWithGAS

# godot_ability_system 组件
@onready var ability_component: GameplayAbilityComponent = $GameplayAbilityComponent
@onready var vital_component: GameplayVitalAttributeComponent = $GameplayVitalAttributeComponent
@onready var attribute_component: GameplayAttributeComponent = $GameplayAttributeComponent

# 适配器
@onready var adapter: AbilitySystemAdapter = $AbilitySystemAdapter

# 战斗组件
@onready var combat_component: CharacterCombatComponent = $CharacterCombatComponent

# 实现接口属性
var character_name: StringName = "Hero"
var is_alive: bool:
    get: return vital_component.get_vital_value(&"Health") > 0
var speed: float:
    get: return attribute_component.get_value(&"Speed", 100.0)
var current_hp: float:
    get: return vital_component.get_vital_value(&"Health")
var current_mp: float:
    get: return vital_component.get_vital_value(&"Mana")
var element: int = 0
var can_action: bool:
    get: return combat_component.can_action

signal character_defeated

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
```

## BaseCombatCharacter 的功能

`BaseCombatCharacter` 提供了以下功能：

### 组件系统
- `CharacterCombatComponent` - 战斗逻辑
- `CharacterSkillComponent` - 技能管理（旧系统）
- `CharacterAIComponent` - AI行为

### UI系统
- `CharacterInfoContainer` - 角色信息显示
- `StateIndicator` - 状态指示器

### 交互系统
- 鼠标悬停高亮
- 点击选择
- 伤害数字显示

### 动画系统
- 动画播放
- 动画库管理

### 移动系统
- 移动到目标
- 移动到施法位置
- 返回原位

## 选择建议

- **使用 `BaseCombatCharacter`** 如果：
  - 需要快速启动
  - 使用插件提供的技能系统（`CharacterSkillComponent`）
  - 需要完整的UI和交互功能

- **实现自己的角色类** 如果：
  - 需要完全自定义的实现
  - 使用第三方技能系统（如 `godot_ability_system`）
  - 需要特殊的架构设计
  - 希望最小化对插件的依赖

## 参考文档

- [角色接口约定](CHARACTER_INTERFACE.md) - 完整的接口定义
- [技能系统接口](SKILL_SYSTEM_INTERFACE.md) - 技能系统接口约定

