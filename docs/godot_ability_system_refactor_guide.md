# 基于 godot_ability_system 的重构建议

本文档基于对 **godot_ability_system** 插件文档与当前 **godot4_turn_based_combat_system** 项目代码的分析，给出如何用该插件重构当前技能/属性/状态系统的建议。

---

## 一、概念映射总览

| 当前项目 | godot_ability_system | 说明 |
|----------|----------------------|------|
| `SkillAttributeSet` / `SkillAttribute` | `GameplayAttributeSet` / `GameplayAttribute` | 属性定义与属性集 |
| 当前生命/魔法用 Attribute 的 base_value | `GameplayVitalAttributeComponent` + Vital | 插件建议 HP/MP 用 Vital 管理 |
| `CharacterSkillComponent` | `GameplayAbilityComponent` + `GameplayAttributeComponent` + `GameplayStatusComponent` + `GameplayVitalAttributeComponent` | 当前一个组件拆成四个 |
| `SkillData` | `GameplayAbilityDefinition` | 技能定义；执行逻辑用行为树 |
| `SkillData.effects`（SkillEffect 数组） | 行为树中的 `AbilityNodeApplyEffect` + `GameplayEffect`（如 GEApplyDamage） | 效果由行为树节点 + 效果资源表达 |
| `SkillStatusData` | `GameplayStatusData` | 状态数据；叠加/持续用插件的 Stacking/Duration 策略 |
| `SkillEffect`（DamageEffect 等） | `GameplayEffect`（GEApplyDamage、GEModifyVital 等） | 效果系统一一对应 |
| `SkillAttributeModifier` | `GameplayAttributeModifier` | 属性修改器 |
| 回合结束 `update_status_durations()` | 自定义 `StatusDurationPolicy` 或业务层每回合驱散 | 插件当前仅实现 `DurationNaturalTime`，按回合需自实现或业务层处理 |
| `TBCombatSystem` 事件 | `AbilityEventBus` / 组件信号 | 可用事件总线或信号统一 |
| 目标类型（ENEMY_SINGLE 等） | 行为树内 `AbilityNodeTargetSearch` + 目标策略，或业务层先选目标再传入黑板 | 目标由策略或外部选择决定 |

---

## 二、架构差异与取舍

### 2.1 组件拆分

- **当前**：一个 `CharacterSkillComponent` 同时管属性、技能、状态、MP/HP。
- **插件**：  
  - `GameplayAttributeComponent`：普通属性（攻击、防御、速度等）  
  - `GameplayVitalAttributeComponent`：生命/魔法等资源  
  - `GameplayStatusComponent`：Buff/Debuff  
  - `GameplayAbilityComponent`：技能学习、激活、冷却  

**建议**：  
- 在角色场景下挂载上述四个组件，角色脚本只依赖“接口”或节点路径，不依赖当前单一技能组件。  
- 为兼容现有 `Character` 与战斗逻辑，可先做一层 **适配器**：保留一个“技能组件接口”，内部转发到四个插件组件（见下文“兼容层”）。

### 2.2 技能执行：从“效果数组”到“行为树”

- **当前**：`SkillData.effects` 存 `SkillEffect` 数组，`CharacterSkillComponent.execute_skill` 里顺序执行并处理目标。  
- **插件**：技能执行由 **行为树** 驱动，节点如：  
  `AbilityNodeApplyCost` → `AbilityNodePlayAnimation` → `AbilityNodeApplyEffect` → `AbilityNodeCommitCooldown` 等。

**建议**：  
- 每个“技能”对应一个 `GameplayAbilityDefinition`，其 `execution_tree` 用行为树描述：消耗、动画、对目标应用效果、冷却。  
- 现有每个 `SkillEffect` 迁移为插件中的 `GameplayEffect`（如 `GEApplyDamage`、`GEModifyVital`、`GEApplyStatus` 等），在行为树里用 `AbilityNodeApplyEffect` 引用这些效果。  
- 目标选择两种方式二选一或并存：  
  1）沿用当前：由 BattleManager/UI 先选好目标，把目标写入技能激活时的 context/黑板；行为树里从黑板读目标，再应用效果。  
  2）用插件的 `AbilityNodeTargetSearch` + 目标策略，在行为树内部按“敌/友/自身”等规则搜索目标。

### 2.3 属性与 Vital（HP/MP）

- **当前**：`SkillAttributeSet` 中用 `SkillAttribute` 表示 CurrentHealth/MaxHealth、CurrentMana/MaxMana，并在 Set 内做 clamp、同步。  
- **插件**：  
  - 普通属性：`GameplayAttributeSet` + `GameplayAttributeComponent`。  
  - 生命/魔法：推荐用 `GameplayVitalAttributeComponent` + `GameplayVital`（如 health、mana）。

**建议**：  
- 攻击/防御/速度等迁移到 `GameplayAttributeSet` + `GameplayAttributeComponent`。  
- HP/MP 迁移到 `GameplayVitalAttributeComponent`，便于与 `CostFeature`、`AbilityNodeApplyCost`、`GEModifyVital` 等对接。  
- 若暂时不想拆 Vital，可继续用属性组件模拟：用两个 Attribute（如 current_health / max_health），在 `GameplayAttributeSet` 的 `on_attribute_changed` 里做与当前类似的 clamp 和同步逻辑。

### 2.4 状态系统（Buff/Debuff）

- **当前**：`SkillStatusData` 含叠加行为、持续回合、初始/持续/结束效果、事件触发、行动限制等。  
- **插件**：`GameplayStatusData` + 叠加策略（如 `StackingRefreshDuration`、`StackingIntensity`）+ 持续策略（当前仅 **`DurationNaturalTime`** 已实现）+ `apply_effects`/`remove_effects`/`features`（如 `FeaturePeriodicEffects`、`FeatureEventListener`）。

**建议**：  
- 每个 `SkillStatusData` 迁移为一个 `GameplayStatusData`。  
- 叠加：用 `StackingRefreshDuration`、`StackingIntensity` 等对应现有 `StackBehavior`。  
- **回合制持续时间**：插件文档中提到的 `DurationManualUpdate` **当前未实现**。可选做法：（1）继承 `StatusDurationPolicy` 自实现“按回合”策略，在每回合结束时由业务代码触发更新；（2）或继续在业务层每回合遍历状态、减少剩余回合数并移除到期状态，与 Status 组件配合。  
- 初始/持续/结束效果：映射到 `apply_effects`、`features`（如周期性）、`remove_effects`。  
- 事件驱动（如“受到伤害时反击”）：用 `FeatureEventListener` + 事件名（如 `on_damage_taken`），在插件事件总线上触发对应事件。  
- 行动限制（如沉默、眩晕）：可用插件的 **标签系统**（GameplayTag）：给单位/状态打 tag，技能或 Cost 检查 tag 决定是否可释放；或在业务层保留一层“可行动”检查，读取 Status 组件/标签。

### 2.5 回合制与“输入/冷却”的适配

- **当前**：回合制，玩家在己方回合选技能+目标，无实时输入绑定。  
- **插件**：快速开始里多用 `AbilityInputFeature` + `match_input`，偏即时制。

**建议**：  
- 不在技能上绑 `AbilityInputFeature`（或仅占位），改为 **业务层驱动**：玩家在 UI 选技能和目标后，调用 `ability_component.try_activate_ability(ability_id)`，并把目标、战斗上下文等通过 **context/黑板** 传入。  
- 冷却：若你使用“按回合冷却”，可用插件 Cooldown 按“秒”配置（例如 1 回合 = 1 秒），或在业务层用自定义 Feature 实现“每回合减 1”的冷却。  
- MP 消耗：用 `CostFeature`（cost_type = mana）或行为树里 `AbilityNodeApplyCost`，与 `GameplayVitalAttributeComponent` 的 mana 对接。

---

## 三、分阶段重构步骤

### 阶段 1：启用插件与兼容层（最小改动）

1. 在项目中启用 **godot_ability_system** 插件。  
2. **不删除** 现有 `CharacterSkillComponent`、`SkillData`、`SkillAttributeSet` 等，先增加“双写/适配”：  
   - 在角色场景中挂载：  
     - `GameplayAttributeComponent`  
     - `GameplayVitalAttributeComponent`（若采用 Vital 管理 HP/MP）  
     - `GameplayStatusComponent`  
     - `GameplayAbilityComponent`  
   - 实现一个 **适配器脚本**（如 `AbilitySystemAdapter`），实现当前项目用到的 `SkillComponentInterface` 子集（或你现有的 getter 集合），内部转发到上述四个组件。  
   - 角色和战斗逻辑仍通过“技能组件接口”访问，接口背后先走现有实现，确保战斗流程不变。  
3. 在 `Character` 的 `_initialize_from_data` 中，用 `CharacterData` 的数值**同步到插件组件**（例如初始化 AttributeSet 的 base_value、Vital 的 current/max），保证两边数据一致，便于后续对比和切换。

### 阶段 2：属性与 Vital 迁移

1. 用插件资源类型创建：  
   - `GameplayAttribute`（AttackPower、DefensePower、Speed 等）  
   - `GameplayAttributeSet`（如 `battle_attribute_set.tres`），并配置初始值或 ScalableValue。  
2. 若采用 Vital：创建 `GameplayVital`（health、mana），在角色初始化时 `vital_component.initialize_vital(&"health", ...)` 等。  
3. 将 `CharacterData` 中的 `attribute_set_resource` 从 `SkillAttributeSet` 改为引用 `GameplayAttributeSet`（或同时保留两个，用适配器从插件组件读值）。  
4. 适配器改为：`get_attribute_current_value` 等从 `GameplayAttributeComponent` / `GameplayVitalAttributeComponent` 读取；`consume_mp`/`restore_mp` 等调用 Vital 组件。  
5. UI（如血条、MP 条、属性面板）改为监听插件组件的信号（如 `attribute_changed`、`vital_changed`）。

### 阶段 3：状态系统迁移

1. 为每个现有 `SkillStatusData` 创建对应的 `GameplayStatusData`：  
   - 叠加策略 ↔ `stacking_policy`  
   - 持续策略：当前插件仅提供 `DurationNaturalTime`；回合制需自实现 `StatusDurationPolicy` 子类，或在业务层每回合遍历并移除到期状态。  
   - 初始/周期/结束效果 → `apply_effects`、`features`、`remove_effects`  
2. 在回合结束逻辑（原 `update_status_durations()` 处）：若使用自定义回合制策略则调用其更新接口；否则在业务层遍历状态、减少剩余回合数并移除到期状态。  
3. 事件类状态（如受击反击）：用 `FeatureEventListener`，事件名与当前 `TBCombatSystem` 的事件名对齐；在触发事件时同时调用插件的事件总线（若有）或由 Status 组件监听。  
4. 行动限制：用标签或自定义逻辑，在“能否释放技能/普攻”处查询 Status 或 Tag，保持与现有 `restricted_action_categories` 行为一致。  
5. 适配器：`apply_status`/`remove_status`/`has_status`/`get_active_statuses` 等转发到 `GameplayStatusComponent`，并做好事件与信号到现有 UI/战斗逻辑的桥接。

### 阶段 4：技能与效果迁移

1. **效果**：  
   - 为每个 `SkillEffect` 类型建对应 `GameplayEffect`（或使用插件内置的 GEApplyDamage、GEModifyVital、GEApplyStatus 等）。  
   - 伤害、治疗、挂状态、驱散等逻辑尽量用内置 GE，减少自定义脚本。  
2. **技能定义**：  
   - 每个 `SkillData` 对应一个 `GameplayAbilityDefinition`（ability_id 与 skill_id 一致或建映射表）。  
   - 用行为树组织：ApplyCost（或 CommitCost）→ PlayAnimation（可选）→ ApplyEffect（对黑板中的目标应用效果）→ CommitCooldown。  
3. **目标**：  
   - 在玩家选完目标后，调用 `try_activate_ability(ability_id, context)` 时，把 `target`/`targets` 放入 context；行为树根节点或第一个需要目标的节点从 context 读目标，写入黑板，后续 `AbilityNodeApplyEffect` 使用黑板中的目标。  
   - 或引入 `AbilityNodeTargetSearch` + 自定义目标策略（封装“敌方单体/友方单体/自身”等），与当前 `SkillData.target_type` 对应。  
4. **学习/列表**：  
   - 角色初始化时用 `ability_component.learn_ability(definition)` 学习当前 `CharacterData` 中的技能与普攻/防御技能。  
5. 适配器：`execute_skill(skill_id, targets, context)` 转为 `try_activate_ability(skill_id)` 并传入带目标的 context；`get_skills`/`has_skill`/`get_skill_mp_cost` 等从 `GameplayAbilityComponent` 和技能定义读取。

### 阶段 5：移除旧实现并收尾

1. 当所有战斗与 UI 都通过适配器或直接使用插件组件后，移除对 `CharacterSkillComponent`、`SkillAttributeSet`、`SkillAttribute`、`SkillData`、`SkillStatusData`、`SkillEffect` 等旧类型的依赖。  
2. 将 `SkillComponentInterface` 改为面向插件组件的薄接口（或删除接口，直接依赖四个组件）。  
3. `CharacterData` 改为只引用插件资源（`GameplayAttributeSet`、`GameplayVital`、`GameplayAbilityDefinition`、`GameplayStatusData` 等）。  
4. 事件与日志：统一走 `AbilityEventBus` 或组件信号，替换原 `TBCombatSystem.trigger_game_event` 的调用处（或保留 TBCombatSystem 但内部转发到插件事件总线）。

---

## 四、关键对接点清单

- **Character 初始化**：  
  - 用 `CharacterData` 初始化：AttributeSet、Vital、技能列表（learn_ability）、被动状态（若用被动技能或开局 apply_status）。  
- **回合结束**：  
  - 对状态做“一回合”更新：若使用自定义的回合制 `StatusDurationPolicy` 则调用其更新接口；否则在业务层遍历并减少剩余回合数、移除到期状态。  
- **技能释放**：  
  - UI/战斗流程选技能+目标 → `try_activate_ability(ability_id)`，context 带 target/targets 和 battle_manager 等。  
- **伤害/治疗**：  
  - 使用插件 `GEApplyDamage`/`GEModifyVital`，通过 `DamageCalculator` 或效果内逻辑与现有元素/防御公式对接（必要时写自定义 GE 或扩展现有 GE）。  
- **事件**：  
  - 受击、回合开始等用插件事件或信号，与 `FeatureEventListener`、状态触发逻辑对接。  
- **UI**：  
  - 技能列表、目标选择、状态图标、血条 MP 条，数据源改为四个插件组件的属性和信号。

---

## 五、注意事项

1. **插件版本**：文档要求 Godot 4.5+，请确认项目与插件版本兼容。  
2. **回合制**：插件当前未提供按回合的持续时间策略，需自实现 `StatusDurationPolicy` 或在业务层每回合驱散到期状态。  
3. **目标与上下文**：行为树需要从“外部已选目标”或“目标策略”拿到目标并写入黑板，与当前 BattleManager 的 `get_valid_enemy_targets` 等配合。  
4. **保留扩展性**：自定义 `GameplayEffect`、自定义行为树节点、自定义目标策略都可与现有设计（如元素克制、多段攻击）结合。  
5. **测试策略**：每阶段迁移后保留旧数据或双写一段时间，用少量角色/技能做完整回合战斗验证，再全面切换。

按以上步骤，可以渐进地用 **godot_ability_system** 替换当前技能/属性/状态实现，同时保持回合制流程和现有战斗体验一致，并便于后续扩展更多技能类型与状态逻辑。
