# 技能系统接口约定

`CharacterCombatComponent` 使用**鸭子类型（Duck Typing）**设计，不依赖具体的技能系统实现。任何技能系统只要实现了约定的方法，就可以与战斗组件配合使用。

## 必需的接口方法

技能系统需要提供以下方法（可以通过父节点或技能组件访问）：

### 属性/状态管理
- `get_restricted_action_tags() -> Array[String]` - 获取动作限制标签
- `can_perform_action_category(category: StringName) -> bool` - 检查是否可以执行特定类别的动作

### 技能管理
- `is_skill_available(skill: SkillData) -> bool` - 检查技能是否可用
- `has_enough_mp_for_skill(skill: SkillData) -> bool` - 检查是否有足够的MP使用技能
- `get_available_skills() -> Array` - 获取可用技能列表
- `add_skill(skill: SkillData) -> void` - 添加技能（可选）

### 资源管理
- `consume_hp(amount: float) -> bool` - 消耗生命值
- `restore_hp(amount: float) -> float` - 恢复生命值
- `use_mp(amount: float) -> bool` - 使用魔法值（可选，如果技能系统不管理MP）

### 状态效果管理（可选）
- `process_active_statuses(battle_manager: BattleManager) -> void` - 处理活跃状态效果
- `update_status_durations() -> void` - 更新状态持续时间

### 信号（可选）
- `attribute_current_value_changed` - 属性当前值改变信号
- `action_tags_changed` - 动作限制标签改变信号

## 访问方式

战斗组件会按以下顺序尝试访问技能系统：

1. 父节点的 `get_skill_component()` 方法（如果存在）
2. 父节点的 `skill_component` 属性（如果存在）
3. 父节点本身（如果父节点实现了技能系统接口）

## 使用示例

```gdscript
# 你的技能系统类只需要实现约定的方法
extends Node
class_name MySkillSystem

var _restricted_tags: Array[String] = []
var _skills: Array[SkillData] = []
var _current_hp: float = 100.0
var _current_mp: float = 50.0

func get_restricted_action_tags() -> Array[String]:
    return _restricted_tags

func can_perform_action_category(category: StringName) -> bool:
    return not _restricted_tags.has(category) and not _restricted_tags.has("any_action")

func is_skill_available(skill: SkillData) -> bool:
    # 实现技能可用性检查
    return skill in _skills

func has_enough_mp_for_skill(skill: SkillData) -> bool:
    return _current_mp >= skill.mp_cost

func get_available_skills() -> Array:
    return _skills.filter(func(s): return has_enough_mp_for_skill(s))

func consume_hp(amount: float) -> bool:
    _current_hp -= amount
    return true

func restore_hp(amount: float) -> float:
    _current_hp += amount
    return amount
```

