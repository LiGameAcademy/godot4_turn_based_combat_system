# GameplayAttribute 属性资源

本目录包含使用 `GameplayAttribute` 类定义的属性资源，用于 `godot_ability_system`。

## 已创建的属性资源

### 1. 基础属性

#### `attack_power.tres` - 攻击力
- **属性ID**: `AttackPower`
- **显示名称**: "攻击力"
- **描述**: "角色的物理攻击力，影响对敌人造成的伤害"
- **最小值**: 负无穷
- **最大值**: 正无穷

#### `defense_power.tres` - 防御力
- **属性ID**: `DefensePower`
- **显示名称**: "防御力"
- **描述**: "角色的物理防御力，减少受到的物理伤害"
- **最小值**: 负无穷
- **最大值**: 正无穷

#### `speed.tres` - 速度
- **属性ID**: `Speed`
- **显示名称**: "速度"
- **描述**: "角色的行动速度，影响战斗中的行动顺序"
- **最小值**: 负无穷
- **最大值**: 正无穷

### 2. 生命值相关属性

#### `max_health.tres` - 最大生命值
- **属性ID**: `MaxHealth`
- **显示名称**: "最大生命值"
- **描述**: "角色的最大生命值上限"
- **最小值**: 1.0
- **最大值**: 正无穷

#### `current_health.tres` - 当前生命值
- **属性ID**: `CurrentHealth`
- **显示名称**: "当前生命值"
- **描述**: "角色当前的生命值"
- **最小值**: 负无穷
- **最大值**: 正无穷

### 3. 魔法值相关属性

#### `max_mana.tres` - 最大魔法值
- **属性ID**: `MaxMana`
- **显示名称**: "最大魔法值"
- **描述**: "角色的最大魔法值上限"
- **最小值**: 负无穷
- **最大值**: 正无穷

#### `current_mana.tres` - 当前魔法值
- **属性ID**: `CurrentMana`
- **显示名称**: "当前魔法值"
- **描述**: "角色当前的魔法值"
- **最小值**: 负无穷
- **最大值**: 正无穷

## 与旧版 SkillAttribute 的对应关系

| 旧版 (SkillAttribute) | 新版 (GameplayAttribute) | 说明 |
|----------------------|-------------------------|------|
| `attribute_name` | `attribute_id` | 属性唯一标识符 |
| `display_name` | `attribute_display_name` | 显示名称 |
| `description` | `attribute_description` | 属性描述 |
| `min_value` | `min_value` | 最小值 |
| `max_value` | `max_value` | 最大值 |
| `base_value` | - | 基础值在 `GameplayAttributeSet` 中设置 |
| `can_be_negative` | - | 通过 `min_value` 控制（如 `min_value = 0.0`） |

## 使用方法

### 在 GameplayAttributeSet 中使用

```gdscript
# 加载属性资源
var attack_attr = load("res://addons/godot_ability_system/scripts/attributes/attack_power.tres")
var defense_attr = load("res://addons/godot_ability_system/scripts/attributes/defense_power.tres")

# 创建属性集
var attribute_set = GameplayAttributeSet.new()

# 添加属性并设置初始值
attribute_set.attributes[attack_attr] = 10.0
attribute_set.attributes[defense_attr] = 5.0
```

### 在组件中初始化

```gdscript
@onready var vital_component: GameplayVitalAttributeComponent = %GameplayVitalAttributeComponent

func _ready():
	var attribute_set = GameplayAttributeSet.new()
	
	# 加载属性资源
	var max_health_attr = load("res://addons/godot_ability_system/scripts/attributes/max_health.tres")
	var attack_attr = load("res://addons/godot_ability_system/scripts/attributes/attack_power.tres")
	
	# 设置初始值
	attribute_set.attributes[max_health_attr] = 100.0
	attribute_set.attributes[attack_attr] = 10.0
	
	# 初始化组件
	vital_component.initialize([attribute_set], [])
```

## 注意事项

1. **基础值设置**: `GameplayAttribute` 资源本身不包含 `base_value`，基础值在 `GameplayAttributeSet` 中设置
2. **属性ID**: 确保属性ID与系统中使用的ID一致（如 `AttackPower`、`MaxHealth` 等）
3. **最小值限制**: `MaxHealth` 的最小值设置为 1.0，确保生命值不会为 0 或负数
4. **资源路径**: 所有资源位于 `addons/godot_ability_system/scripts/attributes/` 目录下

## 相关文档

- [GameplayAttribute 类定义](../gameplay_attribute.gd)
- [GameplayAttributeSet 使用指南](../gameplay_attribute_set.gd)
- [属性系统文档](../../docs/attribute_system.md)
