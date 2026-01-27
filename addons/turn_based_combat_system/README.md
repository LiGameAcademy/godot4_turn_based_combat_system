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

#### 方式一：使用 BaseCombatCharacter（推荐快速启动）

```gdscript
# 创建角色并添加到战斗
var character = preload("res://scenes/characters/base_combat_character.tscn").instantiate()
character.character_data = load("res://character_data.tres")
battle_manager.add_character(character, true)  # true表示玩家队伍
```

#### 方式二：实现自己的角色类（完全自定义）

```gdscript
# 你的角色类只需要实现接口约定（鸭子类型）
var character = preload("res://scenes/characters/my_character.tscn").instantiate()
battle_manager.add_character(character, true)
```

详细说明请参考 [角色使用指南](docs/CHARACTER_USAGE.md)

## 接口约定

插件使用**鸭子类型（Duck Typing）**设计，不依赖具体的类定义：

1. **战斗角色接口**：任何 Node 类型的对象只要实现了约定的属性和方法，就可以作为战斗角色使用
   - 详细约定请参考：[docs/CHARACTER_INTERFACE.md](docs/CHARACTER_INTERFACE.md)

2. **技能系统接口**：`CharacterCombatComponent` 不依赖具体的技能系统实现，可以通过任何实现了技能系统接口的组件工作
   - 详细约定请参考：[docs/SKILL_SYSTEM_INTERFACE.md](docs/SKILL_SYSTEM_INTERFACE.md)

### 快速开始

你的角色类需要实现以下核心方法：
- `execute_action()` - 执行行动
- `take_damage()` - 受到伤害
- `heal()` - 治疗
- `on_turn_start()` - 回合开始
- `on_turn_end()` - 回合结束

以及必要的属性：`character_name`, `is_alive`, `speed`, `current_hp`, `current_mp`, `element`, `can_action`

## 注意事项

⚠️ **重要**：此插件提供核心战斗逻辑系统，但以下内容需要项目自己实现：
- Character 场景和脚本（项目特定的视觉表现）
- UI 系统（战斗界面、菜单等）
- 动画和特效资源
- 音效和背景音乐

插件通过信号系统和鸭子类型与项目代码交互，保持核心逻辑的独立性，对业务层完全非侵入。

## 版本

当前版本：1.0.0

## 许可证

MIT License

