# 迁移指南

## 从项目代码迁移到插件

本指南说明如何将现有项目中的引用从原始路径迁移到插件路径。

## 文件路径对照表

### 核心战斗系统
| 原始路径 | 插件路径 |
|---------|---------|
| `scripts/core/battle/battle_manager.gd` | `addons/turn_based_combat_system/core/battle/battle_manager.gd` |
| `scripts/core/battle/battle_state_manager.gd` | `addons/turn_based_combat_system/core/battle/battle_state_manager.gd` |
| `scripts/core/battle/turn_order_manager.gd` | `addons/turn_based_combat_system/core/battle/turn_order_manager.gd` |
| `scripts/core/battle/combat_rule_manager.gd` | `addons/turn_based_combat_system/core/battle/combat_rule_manager.gd` |
| `scripts/core/battle/battle_character_registry_manager.gd` | `addons/turn_based_combat_system/core/battle/battle_character_registry_manager.gd` |
| `scripts/core/battle/battle_visual_effects.gd` | `addons/turn_based_combat_system/core/battle/battle_visual_effects.gd` |

### 技能系统
| 原始路径 | 插件路径 |
|---------|---------|
| `scripts/autoload/skill_system.gd` | `addons/turn_based_combat_system/systems/skill_system.gd` |

### 资源定义
| 原始路径 | 插件路径 |
|---------|---------|
| `scripts/resources/*.gd` | `addons/turn_based_combat_system/resources/*.gd` |

### 上下文
| 原始路径 | 插件路径 |
|---------|---------|
| `scripts/contexts/*.gd` | `addons/turn_based_combat_system/contexts/*.gd` |

## 迁移步骤

### 1. 启用插件
在 Godot 编辑器中启用插件：
- 打开 `项目 > 项目设置 > 插件`
- 启用 "Turn Based Combat System"

### 2. 更新 Autoload 设置
如果项目使用了 `SkillSystem` 作为 Autoload：
- 打开 `项目 > 项目设置 > Autoload`
- 将 `SkillSystem` 的路径更新为：`addons/turn_based_combat_system/systems/skill_system.gd`

### 3. 更新场景引用
检查所有场景文件（.tscn）中的脚本引用：
- 如果场景中直接引用了脚本路径，需要更新为插件路径
- 注意：如果使用 `class_name`，通常不需要更新路径，Godot 会自动解析

### 4. 更新代码中的 preload/load
检查代码中所有使用 `preload()` 或 `load()` 的地方：
```gdscript
# 旧代码
const BattleManager = preload("res://scripts/core/battle/battle_manager.gd")

# 新代码（如果使用插件）
const BattleManager = preload("res://addons/turn_based_combat_system/core/battle/battle_manager.gd")
```

### 5. 测试
- 运行项目，确保所有功能正常
- 检查控制台是否有错误信息
- 测试战斗系统的基本功能

## 注意事项

⚠️ **重要提示**：

1. **保留原始文件**：在确认插件工作正常之前，建议保留原始文件作为备份
2. **class_name 自动解析**：如果代码中使用了 `class_name`，Godot 会自动找到类定义，通常不需要更新路径
3. **场景文件**：场景文件中的脚本引用可能需要手动更新
4. **资源文件**：`.tres` 资源文件中的脚本引用可能需要更新

## 回滚

如果迁移后出现问题，可以：
1. 禁用插件
2. 恢复使用原始路径的文件
3. 检查并修复问题后重新迁移

