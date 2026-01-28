# 资源配置文档

本文档描述当前项目中 `resources/` 目录下实现的所有配置资源。

## 目录结构

```
resources/
├── battle_data/          # 战斗数据配置
├── characters_data/      # 角色数据配置
├── skill_attributes/     # 技能属性定义
├── skill_effects/        # 技能效果定义
├── skill_status/         # 状态效果定义
├── skills/              # 技能数据配置
└── materials/           # 材质资源（视觉效果）
```

---

## 1. 战斗数据 (battle_data/)

### 1.1 已实现配置

#### `forest_encounter.tres` - 森林遭遇战
- **战斗标题**: "森林遭遇战"
- **背景音乐**: `assets/audio/music/kill and life.wav`
- **敌方角色**:
  - 哥布林 (位置: 0, 0)
  - 蘑菇怪 (位置: 200, 0)
- **玩家角色**:
  - 刺客 (位置: 0, 0)
  - 水晶重击者 (位置: 200, 0)
- **战斗规则**:
  - 最大回合数: 99
  - 允许逃跑: 是
  - 是否为Boss战: 否
- **奖励**:
  - 经验值: 50
  - 金币: 25
  - 道具奖励: 无

### 1.2 配置结构

`BattleData` 资源包含以下配置项：
- `battle_title`: 战斗标题
- `battle_music`: 背景音乐资源
- `enemy_data_list`: 敌方角色数据字典（角色数据 -> 位置）
- `player_data_list`: 玩家角色数据字典（角色数据 -> 位置）
- `max_turn_count`: 最大回合数
- `defeat_scene`: 失败场景路径
- `victory_scene`: 胜利场景路径
- `exp_reward`: 经验值奖励
- `gold_reward`: 金币奖励
- `item_rewards`: 道具奖励列表
- `is_boss_battle`: 是否为Boss战
- `allow_escape`: 是否允许逃跑
- `special_conditions`: 特殊条件字典
- `battle_description`: 战斗描述

---

## 2. 角色数据 (characters_data/)

### 2.1 已实现角色

#### 玩家角色

1. **`player_assassin.tres` - 刺客**
   - **名称**: "勇者"
   - **描述**: "一位勇敢的冒险者，善于使用剑术和基础魔法。"
   - **元素属性**: 水 (water)
   - **属性集**: 包含以下属性
     - MaxHealth: 最大生命值
     - MaxMana: 最大魔法值
     - CurrentHealth: 当前生命值
     - CurrentMana: 当前魔法值
     - AttackPower: 攻击力
     - DefensePower: 防御力
     - Speed: 速度
   - **技能列表**:
     - 火球术 (fireball)
     - 小治疗 (minor_heal)
     - 沉默 (silence)
     - 眩晕 (stun)
   - **攻击技能**: 普通攻击
   - **防御技能**: 防御
   - **动画库**: `assets/animations/hero/animation_library_assassin.res`
   - **图标**: `assets/textures/icons/assassin.tres`

2. **`player_crystal_mauler.tres` - 水晶重击者**
   - **名称**: "格罗姆尼尔"
   - **描述**: "来自地底深城的坚毅矮人，他的战锤能粉碎岩石，他的意志如水晶般坚不可摧。作为团队的先锋，他总是站在最前线，为同伴筑起一道可靠的屏障。"
   - **元素属性**: 土 (earth)
   - **AI行为**: 平衡型 (balanced)
     - 攻击权重: 1.0
     - 技能攻击权重: 1.0
     - 技能支援权重: 0.5
     - 技能治疗权重: 0.5
     - 目标低血量权重: 1.5
     - 目标高威胁权重: 1.0
     - 治疗低血量权重: 2.0
     - 自我保护权重: 1.0
   - **属性**:
     - MaxHealth: 220.0
     - MaxMana: 90.0
     - AttackPower: 18.0
     - DefensePower: 30.0
     - Speed: 6.0
   - **技能列表**:
     - 符文护盾 (runic_ward)
     - 粉碎战锤 (shattering_maul)
     - 石肤祝福 (stoneskin_blessing)
     - 反击 (counter_attack)
   - **攻击技能**: 普通攻击
   - **防御技能**: 防御
   - **动画库**: `assets/animations/hero/animation_library_crystal_mauler.res`
   - **图标**: `assets/textures/icons/crystal_mauler.tres`

#### 敌方角色

1. **`enemy_goblin_data.tres` - 哥布林**
   - **名称**: "哥布林"
   - **描述**: "常见的低级怪物，弱小但行动迅速。"
   - **元素属性**: 土 (earth)
   - **AI行为**: 攻击型 (aggressive)
     - 攻击权重: 1.0
     - 技能攻击权重: 1.0
     - 技能支援权重: 0.5
     - 技能治疗权重: 0.5
     - 目标低血量权重: 1.5
     - 目标高威胁权重: 1.0
     - 治疗低血量权重: 2.0
     - 自我保护权重: 0.0
   - **属性**:
     - MaxHealth: 80.0
     - MaxMana: 20.0
     - AttackPower: 8.0
     - DefensePower: 2.0
     - MagicAttack: 5.0
     - MagicDefense: 2.0
     - Speed: 8.0
   - **技能列表**:
     - 懦弱闪避 (cowardly_dodge)
     - 恶毒打击 (vicious_strike)
     - 反击 (counter_attack)
   - **攻击技能**: 普通攻击
   - **防御技能**: 防御
   - **动画库**: `assets/animations/enemy/animation_library_goblin.res`
   - **图标**: `assets/textures/icons/goblin.tres`
   - **精灵偏移**: (0, 75)

2. **`enemy_mushroom_data.tres` - 蘑菇怪**
   - **名称**: "蘑菇怪"
   - **描述**: "一片古老菌毯的延伸体，会散播各种影响战局的孢子。单独存在时很脆弱，但成群出现时则非常麻烦。"
   - **元素属性**: 土 (earth)
   - **AI行为**: 平衡型 (balanced)
     - 攻击权重: 1.0
     - 技能攻击权重: 1.0
     - 技能支援权重: 0.5
     - 技能治疗权重: 0.5
     - 目标低血量权重: 1.5
     - 目标高威胁权重: 1.0
     - 治疗低血量权重: 2.0
     - 自我保护权重: 1.0
   - **属性**:
     - MaxHealth: 150.0
     - MaxMana: 50.0
     - AttackPower: 5.0
     - DefensePower: 12.0
     - Speed: 7.0
   - **技能列表**:
     - 滋养孢子 (nurturing_spores)
     - 孢子云 (spore_cloud)
   - **攻击技能**: 普通攻击
   - **防御技能**: 防御
   - **动画库**: `assets/animations/enemy/animation_library_mushroom.res`
   - **图标**: `assets/textures/icons/mushroom.tres`
   - **精灵偏移**: (0, 75)

### 2.2 配置结构

`CharacterData` 资源包含以下配置项：
- `character_name`: 角色名称
- `description`: 角色描述
- `attribute_set_resource`: 属性集资源（`SkillAttributeSet`）
- `element`: 元素属性 (0: 无, 1: 火, 2: 水, 3: 土, 4: 光)
- `ai_behavior`: AI行为配置（`AIBehavior`）
- `skills`: 技能列表（`Array[SkillData]`）
- `attack_skill`: 攻击技能（`SkillData`）
- `defense_skill`: 防御技能（`SkillData`）
- `animation_library`: 动画库资源
- `sprite_offset`: 精灵偏移位置
- `icon`: 角色图标

---

## 3. 技能属性 (skill_attributes/)

### 3.1 已实现属性

1. **`attack_power.tres` - 攻击力**
   - 属性名: `AttackPower`
   - 显示名: "攻击力"
   - 基础值: 10.0
   - 最小值: 负无穷
   - 最大值: 正无穷
   - 可为负: 否

2. **`defense_power.tres` - 防御力**
   - 属性名: `DefensePower`
   - 显示名: "防御力"
   - 基础值: 5.0
   - 最小值: 负无穷
   - 最大值: 正无穷
   - 可为负: 否

3. **`current_health.tres` - 当前生命值**
   - 属性名: `CurrentHealth`
   - 显示名: "当前生命值"
   - 基础值: 0.0
   - 最小值: 负无穷
   - 最大值: 正无穷
   - 可为负: 否

4. **`current_mana.tres` - 当前魔法值**
   - 属性名: `CurrentMana`
   - 显示名: "当前魔法值"
   - 基础值: 0.0
   - 最小值: 负无穷
   - 最大值: 正无穷
   - 可为负: 否

5. **`max_health.tres` - 最大生命值**
   - 属性名: `MaxHealth`
   - 显示名: "最大生命值"
   - 基础值: 100.0
   - 最小值: 1.0
   - 最大值: 正无穷
   - 可为负: 否
   - 注意: 此属性为场景本地资源 (`resource_local_to_scene = true`)

6. **`max_mana.tres` - 最大魔法值**
   - 属性名: `MaxMana`
   - 显示名: "最大魔法值"
   - 基础值: 50.0
   - 最小值: 负无穷
   - 最大值: 正无穷
   - 可为负: 否

7. **`speed.tres` - 速度**
   - 属性名: `Speed`
   - 显示名: "速度"
   - 基础值: 10.0
   - 最小值: 负无穷
   - 最大值: 正无穷
   - 可为负: 否

### 3.2 配置结构

`SkillAttribute` 资源包含以下配置项：
- `attribute_name`: 属性内部名称（StringName）
- `display_name`: 显示名称
- `description`: 描述
- `base_value`: 基础值
- `min_value`: 最小值
- `max_value`: 最大值
- `can_be_negative`: 是否可以为负数

---

## 4. 技能效果 (skill_effects/)

### 4.1 已实现效果

1. **`fireball_damage.tres` - 火球伤害效果**
   - 效果类型: 伤害效果 (`DamageEffect`)
   - 基础伤害: 25
   - 伤害元素: 火 (fire)
   - 攻击力缩放: 1.2
   - 视觉效果: `fire_impact`
   - 音效: `fire_explosion`
   - 用于火球术技能

2. **`burn_dot_damage.tres` - 燃烧持续伤害效果**
   - 效果类型: 持续伤害效果 (`DamageEffect`)
   - 基础伤害: 8
   - 伤害元素: 火 (fire)
   - 攻击力缩放: 0.4
   - 是否为持续伤害: 是
   - 视觉效果: `fire_dot`
   - 音效: `fire_burn`
   - 用于燃烧状态

### 4.2 效果类型

项目实现了以下技能效果类型（位于 `scripts/resources/skill_effect_data/`）：

1. **`damage_effect.gd` - 伤害效果**
   - 基础伤害值
   - 攻击力缩放
   - 防御力缩放
   - 随机伤害范围
   - 元素属性

2. **`heal_effect.gd` - 治疗效果**
   - 治疗量
   - 治疗缩放

3. **`apply_status_effect.gd` - 应用状态效果**
   - 要应用的状态
   - 应用概率
   - 持续时间覆盖
   - 叠加层数

4. **`modifiy_damage_effect.gd` - 修改伤害效果**
   - 伤害修改比例
   - 伤害修改类型

5. **`redirect_damage_effect.gd` - 转移伤害效果**
   - 伤害转移目标
   - 转移比例

6. **`counter_attack_effect.gd` - 反击效果**
   - 反击技能
   - 反击条件

7. **`multi_strike_effect.gd` - 多段攻击效果**
   - 攻击段数
   - 每段伤害比例

8. **`dispel_effect.gd` - 驱散效果**
   - 驱散状态类型
   - 驱散数量

9. **`special_effect.gd` - 特殊效果**
   - 自定义效果逻辑

### 4.3 配置结构

所有效果继承自 `SkillEffect`，包含以下通用配置：
- `disable`: 是否禁用
- `visual_effect`: 视觉效果标识符
- `sound_effect`: 音效标识符
- `description_format`: 描述格式
- `target_override`: 目标覆盖类型
- `element`: 元素属性
- `pre_cast_delay`: 释放前延迟
- `post_cast_delay`: 释放后延迟
- `sub_effects`: 子效果数组
- `conditions`: 执行条件数组

---

## 5. 状态效果 (skill_status/)

### 5.1 已实现状态

1. **`stun.tres` - 眩晕**
   - 状态ID: `stun`
   - 状态名称: "眩晕"
   - 状态类型: DEBUFF (减益)
   - 持续时间: 3 回合
   - 持续时间类型: TURNS (回合数)
   - 最大叠加层数: 1
   - 叠加行为: REFRESH_DURATION (刷新持续时间)
   - 行动限制: `["any_action"]` (禁止所有行动)
   - 图标: `assets/textures/icons/status/stun.svg`

2. **`silence.tres` - 沉默**
   - 状态ID: `silence`
   - 状态名称: "沉默"
   - 状态类型: NEUTRAL (中性)
   - 持续时间: 3 回合
   - 持续时间类型: TURNS
   - 最大叠加层数: 1
   - 叠加行为: REFRESH_DURATION
   - 行动限制: `["magic_skill"]` (禁止魔法技能)
   - 描述: "无法使用任何需要消耗魔法值的技能。"
   - 图标: `assets/textures/icons/status/silence.svg`

3. **`attack_up.tres` - 攻击提升**
   - 状态ID: `attack_up`
   - 状态名称: "攻击提升"
   - 状态类型: BUFF (增益)
   - 持续时间: 3 回合
   - 持续时间类型: TURNS
   - 最大叠加层数: 1
   - 叠加行为: REFRESH_DURATION
   - 属性修改器: 攻击力 +5.0 (加法操作)
   - 描述: "攻击力得到强化。"
   - 图标: `assets/textures/icons/status/attack_up.svg`

4. **`defense_up.tres` - 防御提升**
   - 状态ID: `defense_up`
   - 状态名称: "防御提升"
   - 状态类型: BUFF (增益)
   - 持续时间: 3 回合
   - 持续时间类型: TURNS
   - 最大叠加层数: 1
   - 叠加行为: REFRESH_DURATION
   - 属性修改器: 防御力 ×1.2 (乘法操作，20%提升)
   - 描述: "大地的力量增强了你的防御。"
   - 图标: `assets/textures/icons/status/defend_up.svg`

5. **`defense_down.tres` - 防御下降**
   - 状态ID: `defense_down`
   - 状态名称: "防御下降"
   - 状态类型: DEBUFF (减益)
   - 持续时间: 3 回合
   - 持续时间类型: TURNS
   - 最大叠加层数: 1
   - 叠加行为: REFRESH_DURATION
   - 属性修改器: 防御力 ×0.8 (乘法操作，20%降低)
   - 描述: "孢子侵蚀了护甲，防御力大幅降低。"

6. **`bleed.tres` - 流血**
   - 状态ID: `bleed`
   - 状态名称: "流血"
   - 状态类型: DEBUFF (减益)
   - 持续时间: 3 回合
   - 持续时间类型: TURNS
   - 最大叠加层数: 1
   - 叠加行为: REFRESH_DURATION
   - 持续效果: 每回合造成 5 点伤害（无攻击力缩放，10%随机范围）
   - 图标: `assets/textures/icons/status/bleeding.svg`

7. **`ignite.tres` - 点燃**
   - 状态ID: `ignite`
   - 状态名称: "点燃"
   - 状态类型: DEBUFF (减益)
   - 持续时间: 3 回合
   - 持续时间类型: TURNS
   - 最大叠加层数: 1
   - 叠加行为: ADD_DURATION (增加持续时间)
   - 持续效果: 每回合造成 1 点火焰伤害（10%随机范围）
   - 描述: "每回合受到火焰伤害。"
   - 图标: `assets/textures/icons/status/ignite.svg`

8. **`regeneration.tres` - 再生**
   - 状态ID: `regeneration`
   - 状态名称: "再生"
   - 状态类型: NEUTRAL (中性)
   - 持续时间: 3 回合
   - 持续时间类型: TURNS
   - 最大叠加层数: 1
   - 叠加行为: REFRESH_DURATION
   - 持续效果: 每回合治疗 10 点生命值（无治疗力缩放）
   - 描述: "生命力缓慢地恢复。"

9. **`dodge.tres` - 狡猾闪躲**
   - 状态ID: `dodge`
   - 状态名称: "狡猾闪躲"
   - 状态类型: BUFF (增益)
   - 持续时间: 2 回合
   - 持续时间类型: TURNS
   - 最大叠加层数: 1
   - 叠加行为: REFRESH_DURATION
   - 属性修改器: 速度 +20.0 (加法操作)
   - 描述: "变得极其警觉和敏捷，速度大幅提升。"
   - 图标: `assets/textures/icons/status/dodge.svg`

10. **`defend.tres` - 防御**
    - 状态ID: `defend`
    - 状态名称: "防御"
    - 状态类型: NEUTRAL (中性)
    - 持续时间: 3 回合
    - 持续时间类型: TURNS
    - 最大叠加层数: 1
    - 叠加行为: REFRESH_DURATION
    - 触发效果: 受到伤害时，伤害减少 50%（最小 1，最大 9999）
    - 触发事件: `["on_damage_taken"]`
    - 图标: `assets/textures/icons/status/defend.svg`

11. **`counter_attack.tres` - 反击**
    - 状态ID: `counter_attack`
    - 状态名称: "反击"
    - 状态类型: BUFF (增益)
    - 持续时间: 无限（直到被移除）
    - 持续时间类型: INFINITE
    - 最大叠加层数: 1
    - 叠加行为: NO_STACK (不可叠加)
    - 是否隐藏: 是（不在UI显示）
    - 触发效果: 受到伤害后，50%概率对攻击者进行反击（使用普通攻击）
    - 触发事件: `["on_damage_taken_completed"]`
    - 触发回合数: 3
    - 触发总数: 无限 (-1)

### 5.2 配置结构

`SkillStatusData` 资源包含以下配置项：

**基础信息**:
- `status_id`: 状态唯一ID
- `status_name`: 状态显示名称
- `description`: 详细描述
- `icon`: UI图标
- `is_hidden_from_ui`: 是否隐藏状态效果

**状态类型**:
- `status_type`: 状态类型 (BUFF/DEBUFF/NEUTRAL)
- `duration`: 默认持续回合数
- `duration_type`: 持续时间类型 (TURNS/INFINITE/COMBAT_LONG)
- `max_stacks`: 最大叠加层数
- `stack_behavior`: 叠加行为

**效果配置**:
- `attribute_modifiers`: 属性修改器数组
- `initial_effects`: 初始效果数组（应用时触发）
- `ongoing_effects`: 持续效果数组（每回合触发）
- `end_effects`: 结束效果数组（移除时触发）

**状态交互**:
- `overrides_states`: 此状态应用时会移除的目标状态ID列表
- `resisted_by_states`: 如果目标拥有这些状态之一，则此状态无法应用

**触发条件**:
- `trigger_on_events`: 触发事件列表
- `trigger_effects`: 触发时执行的效果
- `trigger_turns`: 回合触发次数
- `trigger_count`: 触发总数

**行动限制**:
- `restricted_action_categories`: 限制的行动类别列表

---

## 6. 技能数据 (skills/)

### 6.1 已实现技能

1. **`attack.tres` - 普通攻击**
   - 技能ID: `attack`
   - 技能名称: "普通攻击"
   - 技能类型: ACTIVE (主动)
   - 是否近战: 是
   - MP消耗: 0
   - 目标类型: ENEMY_SINGLE (敌方单体)
   - 行动类别: `["any_action"]`

2. **`fireball.tres` - 火球术**
   - 技能ID: `fireball`
   - 技能名称: "火球术"
   - 技能类型: ACTIVE
   - 是否近战: 否
   - MP消耗: 8
   - 目标类型: ENEMY_SINGLE
   - 行动类别: `["any_action", "magic_skill"]`
   - 效果:
     - 伤害效果（基础伤害 10，攻击力缩放 1.0）
     - 应用状态效果（点燃状态）
   - 施法动画: `projectile_cast`

3. **`defend.tres` - 防御**
   - 技能ID: `defend`
   - 技能名称: "防御"
   - 技能类型: ACTIVE
   - 是否近战: 否
   - MP消耗: 0
   - 目标类型: SELF (施法者自己)
   - 行动类别: `["any_action"]`
   - 效果: 应用防御状态（提高防御力）
   - 施法动画: `defend`

4. **`minor_heal.tres` - 初级治疗**
   - 技能ID: `minor_heal`
   - 技能名称: "初级治疗"
   - 技能类型: ACTIVE
   - 是否近战: 是
   - MP消耗: 5
   - 目标类型: ALLY_SINGLE_INC_SELF (我方单体，含自己)
   - 行动类别: `["any_action", "magic_skill"]`
   - 效果:
     - 治疗效果（治疗量 10，治疗力缩放 0.5）
     - 应用状态效果（攻击提升状态）

5. **`silence.tres` - 沉默**
   - 技能ID: `silence`
   - 技能名称: "沉默"
   - 技能类型: ACTIVE
   - 是否近战: 是
   - MP消耗: 5
   - 目标类型: ENEMY_SINGLE
   - 行动类别: `["any_action", "magic_skill"]`
   - 效果: 应用沉默状态（禁止魔法技能）

6. **`stun.tres` - 眩晕**
   - 技能ID: `stun`
   - 技能名称: "眩晕"
   - 技能类型: ACTIVE
   - 是否近战: 是
   - MP消耗: 5
   - 目标类型: ENEMY_SINGLE
   - 行动类别: `["any_action", "magic_skill"]`
   - 效果: 应用眩晕状态（禁止所有行动）

7. **`counter_attack.tres` - 反击**
   - 技能ID: `counter_attack`
   - 技能名称: "反击"
   - 技能类型: PASSIVE (被动技能)
   - 是否近战: 是
   - MP消耗: 0
   - 目标类型: ENEMY_SINGLE
   - 行动类别: `["any_action"]`
   - 被动效果: 学习时应用反击状态

8. **`cowardly_dodge.tres` - 狡猾闪躲**
   - 技能ID: `cowardly_dodge`
   - 技能名称: "狡猾闪躲"
   - 技能类型: ACTIVE
   - 是否近战: 否
   - MP消耗: 4
   - 目标类型: SELF (施法者自己)
   - 行动类别: `["magic_skill"]`
   - 效果: 应用闪避状态（速度提升）
   - 描述: "进入高度警觉状态，大幅提升速度，持续2回合。"
   - 施法动画: `attack`

9. **`vicious_strike.tres` - 恶毒突刺**
   - 技能ID: `vicious_strike`
   - 技能名称: "恶毒突刺"
   - 技能类型: ACTIVE
   - 是否近战: 是
   - MP消耗: 5
   - 目标类型: ENEMY_SINGLE
   - 行动类别: `["any_action", "basic_attack", "physical_attack"]`
   - 效果:
     - 伤害效果（基础伤害 5，无攻击力缩放）
     - 应用状态效果（流血状态，100%概率）
   - 描述: "用生锈的匕首刺向敌人，造成少量伤害，并有很高几率使其流血。"
   - 施法动画: `attack`

10. **`shattering_maul.tres` - 粉碎战锤**
    - 技能ID: `shattering_maul`
    - 技能名称: "粉碎战锤"
    - 技能类型: ACTIVE
    - 是否近战: 是
    - MP消耗: 5
    - 目标类型: ENEMY_SINGLE
    - 行动类别: `["any_action", "any_skill"]`
    - 效果:
      - 伤害效果（基础伤害 0，攻击力缩放 0.5，防御力缩放 1.2）
      - 应用状态效果（眩晕状态，50%概率）
      - 多段攻击效果（2段，伤害倍率 1.2 和 1.0）
    - 描述: "用灌注了大地之力的战锤猛击敌人，造成基于攻击与防御的伤害，并有50%几率使其眩晕一回合。"
    - 施法动画: `attack_3`

11. **`nurturing_spores.tres` - 滋养孢子**
    - 技能ID: `nurturing_spores`
    - 技能名称: "滋养孢子"
    - 技能类型: ACTIVE
    - 是否近战: 否
    - MP消耗: 15
    - 目标类型: ALLY_SINGLE_INC_SELF (我方单体，含自己)
    - 行动类别: `["any_action", "magic_skill", "any_skill"]`
    - 效果:
      - 治疗效果（治疗量 25，无治疗力缩放）
      - 应用状态效果（再生状态）
    - 描述: "为一名友方单位注入生命孢子，立即恢复其生命，并在后续几回合持续恢复。"
    - 施法动画: `attack`

12. **`spore_cloud.tres` - 孢子迷雾**
    - 技能ID: `spore_cloud`
    - 技能名称: "孢子迷雾"
    - 技能类型: ACTIVE
    - 是否近战: 否
    - MP消耗: 12
    - 目标类型: ENEMY_ALL (敌方全体)
    - 行动类别: `["any_action", "magic_skill", "any_skill"]`
    - 效果: 应用状态效果（防御下降状态，100%概率）
    - 描述: "向所有敌人喷射削弱孢子，降低他们的防御力"
    - 施法动画: `attack`

13. **`runic_ward.tres` - 符文守护**
    - 技能ID: `runic_ward`
    - 技能名称: "符文守护"
    - 技能类型: ACTIVE
    - 是否近战: 是
    - MP消耗: 5
    - 目标类型: ALLY_SINGLE (我方单体，不含自己)
    - 行动类别: `["any_action", "any_skill"]`
    - 效果: 待实现（伤害转移效果）
    - 描述: "为一名队友刻下守护符文，在接下来2回合内，为其承受大部分受到的伤害。"
    - 施法动画: `defend`

14. **`stoneskin_blessing.tres` - 石肤祝福**
    - 技能ID: `stoneskin_blessing`
    - 技能名称: "石肤祝福"
    - 技能类型: ACTIVE
    - 是否近战: 否
    - MP消耗: 5
    - 目标类型: ALLY_ALL_INC_SELF (我方全体，含自己)
    - 行动类别: `["any_action", "any_skill"]`
    - 效果: 应用状态效果（防御提升状态）
    - 描述: "向大地祈祷，使我方全体获得岩石般的坚韧，防御力提升，持续3回合。"
    - 施法动画: `defend`

### 6.2 配置结构

`SkillData` 资源包含以下配置项：

**基础信息**:
- `skill_id`: 内部ID（StringName）
- `skill_name`: UI显示名称
- `skill_type`: 技能类型 (ACTIVE/PASSIVE)
- `description`: 技能描述
- `is_melee`: 是否是近战
- `icon`: 技能图标

**消耗与目标**:
- `mp_cost`: 魔法消耗
- `target_type`: 目标类型（见下方枚举）
- `target_count`: 目标数量（仅对多目标类型有效）
- `can_target_dead`: 是否可以对死亡目标施放

**效果**:
- `effects`: 主动技能施放时的直接效果数组
- `action_categories`: 所属行动类别数组

**被动效果**:
- `status_to_apply_when_learned`: 学习时应用的状态（仅对 PASSIVE 类型有效）

**视觉与音效**:
- `cast_animation`: 施法动画名
- `pre_cast_delay`: 释放前延迟
- `post_cast_delay`: 释放后延迟

**目标类型枚举**:
- `NONE`: 无需目标
- `ENEMY_SINGLE`: 敌方单体
- `ENEMY_ALL`: 敌方全体
- `ALLY_SINGLE`: 我方单体（不含自己）
- `ALLY_ALL`: 我方全体（不含自己）
- `SELF`: 施法者自己
- `ALLY_SINGLE_INC_SELF`: 我方单体（含自己）
- `ALLY_ALL_INC_SELF`: 我方全体（含自己）
- `ENEMY_RANDOM`: 敌方随机
- `ALLY_RANDOM`: 我方随机（不含自己）
- `ALLY_RANDOM_INC_SELF`: 我方随机（含自己）

---

## 7. 材质资源 (materials/)

### 7.1 已实现材质

1. **`darken_material.tres` - 变暗材质**
   - 用于视觉效果（如角色死亡、受击等）

2. **`glow_material.tres` - 发光材质**
   - 用于视觉效果（如技能释放、状态效果等）

---

## 配置统计

### 已实现配置数量

- **战斗数据**: 1 个
- **角色数据**: 4 个（2 个玩家角色，2 个敌方角色）
- **技能属性**: 7 个
- **技能效果**: 2 个（示例，实际效果在技能中内嵌配置）
- **状态效果**: 11 个
- **技能数据**: 14 个
- **材质资源**: 2 个

### 配置覆盖范围

✅ **已实现**:
- 基础战斗配置
- 角色属性系统
- 技能系统（主动/被动）
- 状态效果系统（Buff/Debuff）
- 技能效果系统（伤害、治疗、状态应用等）
- AI行为配置

⚠️ **可扩展**:
- 更多战斗场景配置
- 更多角色配置
- 更多技能效果类型
- 更多状态效果类型
- 道具系统配置
- 装备系统配置

---

## 使用建议

1. **创建新角色**: 复制现有角色数据文件，修改属性值和技能列表
2. **创建新技能**: 参考 `fireball.tres`，配置技能效果和目标类型
3. **创建新状态**: 参考 `stun.tres`，配置状态类型、持续时间和效果
4. **创建新战斗**: 参考 `forest_encounter.tres`，配置参战角色和奖励

---

## 相关文档

- [技能系统文档](../addons/turn_based_combat_system/docs/)
- [角色使用指南](../addons/turn_based_combat_system/docs/CHARACTER_USAGE.md)
- [技能系统接口](../addons/turn_based_combat_system/docs/SKILL_SYSTEM_INTERFACE.md)
