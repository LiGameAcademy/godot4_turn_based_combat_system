# 战斗角色接口约定

插件使用**鸭子类型（Duck Typing）**设计，不依赖具体的类定义。任何 Node 类型的对象只要实现了约定的属性和方法，就可以作为战斗角色使用。

## 必需的属性/方法

### 属性（可通过 getter 方法或直接属性访问）

- `character_name: StringName` - 角色名称
- `is_alive: bool` - 是否存活
- `speed: float` - 速度（用于回合顺序）
- `current_hp: float` - 当前生命值
- `current_mp: float` - 当前魔法值
- `element: int` - 元素属性
- `can_action: bool` - 能否行动

### 必需的方法

- `execute_action(action_type: int, target: Node = null, params: Dictionary = {}) -> Dictionary` - 执行行动
- `take_damage(base_damage: float, source: Node, element: int, is_melee: bool = false) -> float` - 受到伤害
- `heal(amount: float) -> float` - 治疗
- `use_mp(amount: float) -> void` - 使用魔法值
- `on_turn_start(battle_manager: Node) -> void` - 回合开始回调
- `on_turn_end(battle_manager: Node) -> void` - 回合结束回调

### 可选的信号

- `character_defeated` - 角色被击败时发出

### 可选的方法

- `initialize_battle(battle_manager: Node, cast_marker: Node2D = null) -> void` - 初始化战斗（由战斗系统调用）
- `get_skill_component() -> Node` - 获取技能组件（如果使用组件系统）
- `get_combat_component() -> Node` - 获取战斗组件（如果使用组件系统）
- `get_ai_component() -> Node` - 获取AI组件（如果使用组件系统）
- `spawn_damage_number(damage: float, color: Color = Color.RED, prefix: String = "") -> void` - 生成伤害数字（用于视觉效果）

## 使用示例

```gdscript
# 你的角色类只需要实现约定的方法和属性
extends Node2D

var character_name: StringName = "Hero"
var is_alive: bool = true
var speed: float = 100.0
var current_hp: float = 100.0
var current_mp: float = 50.0
var element: int = 0
var can_action: bool = true

signal character_defeated

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
    current_hp += amount
    return amount

func use_mp(amount: float) -> void:
    current_mp -= amount

func on_turn_start(battle_manager: Node) -> void:
    # 回合开始逻辑
    pass

func on_turn_end(battle_manager: Node) -> void:
    # 回合结束逻辑
    pass
```

## 插件内部实现

插件内部使用 `has_method()` 和属性检查来访问这些方法和属性，确保兼容性：

```gdscript
# 插件内部代码示例
func _get_character_name(character: Node) -> String:
    if character.has_method("get_character_name"):
        return character.get_character_name()
    elif "character_name" in character:
        return character.character_name
    return "Unknown"
```

这种设计允许你的角色类以任何方式实现这些接口，只要满足约定即可。

