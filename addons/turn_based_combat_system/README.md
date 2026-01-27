# Turn Based Combat System Plugin

一个功能完整的回合制战斗系统框架插件，适用于 Godot 4。

## 功能特性

### 核心系统
- **战斗管理器（BattleManager）**：管理战斗流程和状态
- **状态管理器（BattleStateManager）**：战斗状态机
- **回合管理器（TurnOrderManager）**：管理回合顺序
- **战斗规则管理器（CombatRuleManager）**：战斗规则和胜负判断
- **角色注册管理器（BattleCharacterRegistryManager）**：管理参战角色

### 技能系统
- **技能系统（SkillSystem）**：技能执行核心逻辑
- **技能效果系统**：支持多种技能效果类型
- **状态效果系统**：Buff/Debuff 管理

### 角色组件
- **战斗组件（CharacterCombatComponent）**：战斗逻辑
- **技能组件（CharacterSkillComponent）**：技能管理
- **AI组件（CharacterAIComponent）**：AI行为

### 资源系统
- **角色数据（CharacterData）**：角色配置资源
- **技能数据（SkillData）**：技能配置资源
- **状态数据（SkillStatusData）**：状态效果配置
- **战斗数据（BattleData）**：战斗配置

## 安装

1. 将 `addons/turn_based_combat_system` 目录复制到你的项目的 `addons/` 目录
2. 在 Godot 编辑器中，打开 `项目 > 项目设置 > 插件`
3. 启用 "Turn Based Combat System" 插件

## 使用说明

### 基本使用

```gdscript
# 在你的战斗场景中
@onready var battle_manager: BattleManager = $BattleManager

func _ready():
    # 初始化战斗
    var battle_data = load("res://battle_data.tres")
    battle_manager.start_battle()
```

### 添加角色到战斗

```gdscript
# 创建角色并添加到战斗
var character = preload("res://scenes/characters/character.tscn").instantiate()
character.character_data = load("res://character_data.tres")
battle_manager.add_character(character, true)  # true表示玩家队伍
```

## 注意事项

⚠️ **重要**：此插件提供核心战斗逻辑系统，但以下内容需要项目自己实现：
- Character 场景和脚本（项目特定的视觉表现）
- UI 系统（战斗界面、菜单等）
- 动画和特效资源
- 音效和背景音乐

插件通过信号系统和接口与项目代码交互，保持核心逻辑的独立性。

## 版本

当前版本：1.0.0

## 许可证

MIT License

