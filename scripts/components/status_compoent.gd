extends Node

#region Signals
## 当角色的生命值发生变化时发出
## 参数: character_node (Character), actual_hp_change (int), source (Object - SkillEffectData, SkillStatusData, etc.)
signal health_changed(character_node, actual_hp_change, source)
## 当角色的法力值发生变化时发出
## 参数: character_node (Character), actual_mp_change (int), source (Object)
signal mp_changed(character_node, actual_mp_change, source)

## 当一个状态被成功应用到角色身上时发出 (新状态或叠加层数/持续时间更新)
## 参数: character_node (Character), status_id (StringName), status_runtime_info (Dictionary)
signal status_applied(character_node, status_id, status_runtime_info)
## 当一个状态从角色身上移除时发出
## 参数: character_node (Character), removed_status_data_res (SkillStatusData)
signal status_removed(character_node, removed_status_data_res)
## 当一个已存在状态的层数或持续时间被刷新/更新时发出
## 参数: character_node (Character), status_id (StringName), status_runtime_info (Dictionary), old_stacks (int), old_duration (int)
signal status_updated(character_node, status_id, status_runtime_info, old_stacks, old_duration)

## 当角色因状态效果而无法执行某些行动时发出
## 参数: character_node (Character), blocking_status_data_res (SkillStatusData)
signal action_blocked(character_node, blocking_status_data_res)

## 当属性修改器被添加时发出
## 参数: character_node (Character), modifier_resource (SkillAttributeModifier), source_status_id (StringName, optional)
signal attribute_modifier_applied(character_node, modifier_resource, source_status_id)
## 当属性修改器被移除时发出
## 参数: character_node (Character), modifier_resource (SkillAttributeModifier), source_status_id (StringName, optional)
signal attribute_modifier_removed(character_node, modifier_resource, source_status_id)
#endregion

#region Variables
var skill_system_ref: SkillSystem
var character_owner: Character:
    get:
        return owner if owner is Character else null

# 存储激活状态的运行时数据
# 结构: { status_id_stringname: { "status_res": SkillStatusData, "duration": int, "stacks": int, "source_char": Character } }
var active_statuses: Dictionary = {}

# 追踪由状态应用的属性修改器，方便移除
# 结构: { status_id_stringname: Array[SkillAttributeModifier] }
var _status_applied_modifiers: Dictionary = {}

var _last_action_block_reason: String = ""
var _is_defending: bool = false # 防御状态标记

# 假设在 Character.gd 或全局脚本中定义了行动标志位常量
# const ACTION_FLAG_MOVE = 1
# const ACTION_FLAG_ATTACK = 2
# const ACTION_FLAG_SKILL = 4
# const ACTION_FLAG_ITEM = 8
# const ACTION_FLAG_ANY = ACTION_FLAG_MOVE | ACTION_FLAG_ATTACK | ACTION_FLAG_SKILL | ACTION_FLAG_ITEM
#endregion

#region Initialization
func _ready():
    if not character_owner:
        push_error("CombatComponent '%s' must be a child of a Character node." % name)
        queue_free() # Or handle error appropriately

func set_skill_system_reference(p_skill_system: SkillSystem):
    skill_system_ref = p_skill_system
    
#endregion

#region Action & Resource Management
## 检查角色是否能执行特定行动或任何行动
func can_perform_action(skill_to_cast: SkillData = null, action_type_flag: int = 0) -> bool: # action_type_flag 使用预定义的行动标志位
    if not character_owner or not character_owner.is_alive: # 假设 Character 有 is_alive()
        _last_action_block_reason = "Character is not valid or not alive."
        return false

    if skill_to_cast and character_owner.current_mp < skill_to_cast.mp_cost:
        _last_action_block_reason = "Not enough MP."
        return false
    
    # TODO: SkillStatusData.gd 中缺少类似 'prevents_action_flags' 的属性。
    # 你需要在 SkillStatusData 中添加一个方式来定义状态如何限制行动 (例如，一个整型标志位或布尔属性)。
    # 以下为假设 SkillStatusData 有 'prevents_action_flags' 属性的示例逻辑：
    for status_id in active_statuses:
        var status_runtime = active_statuses[status_id]
        var status_res: SkillStatusData = status_runtime.status_res
        # 假设 SkillStatusData 有一个 'action_restrictions' 标志位属性
        if status_res.has_meta("action_restrictions"): # 检查元数据或直接属性
            var restrictions = status_res.get_meta("action_restrictions", 0) # 或者 status_res.action_restrictions
            
            # 如果要执行特定类型的行动，并且状态限制了该类型
            if action_type_flag > 0 and (restrictions & action_type_flag):
                 _last_action_block_reason = "Action type blocked by status: %s" % status_res.status_name
                 action_blocked.emit(character_owner, status_res)
                 return false
            # 如果状态限制所有行动 (假设 Character.ACTION_FLAG_ANY 是所有行动的组合)
            # elif restrictions & Character.ACTION_FLAG_ANY and action_type_flag == 0: # 检查是否能执行任何行动
            # _last_action_block_reason = "All actions blocked by status: %s" % status_res.status_name
            # action_blocked.emit(character_owner, status_res)
            # return false

    _last_action_block_reason = ""
    return true

func get_last_action_block_reason() -> String:
    return _last_action_block_reason

func consume_skill_resources(skill_data: SkillData):
    if character_owner and skill_data:
        var mp_cost = skill_data.mp_cost
        if mp_cost > 0:
            var actual_mp_change = character_owner.modify_mp(-mp_cost) # Character.modify_mp返回实际变化
            mp_changed.emit(character_owner, actual_mp_change, skill_data)

func set_defending(is_defending: bool):
    _is_defending = is_defending
    if _is_defending:
        print("%s is now defending." % character_owner.character_name)
        # 你也可以在这里应用一个“防御中”的 SkillStatusData
    else:
        print("%s is no longer defending." % character_owner.character_name)
        # 移除“防御中”状态

func is_defending() -> bool:
    return _is_defending
#endregion

#region Health & Mana Modification
func take_damage(base_amount: int, damage_type_element: int = 0, source_char: Character = null, source_object = null) -> int:
    if not character_owner or not character_owner.is_alive(): return 0

    var final_damage = float(base_amount) # 开始时为浮点数以便计算百分比减伤

    # TODO: 集成更复杂的伤害计算，考虑属性、抗性等
    # final_damage = DamageCalculator.calculate(base_amount, damage_type_element, source_char, character_owner)
    if _is_defending:
        final_damage *= 0.5 # 简单防御减伤50%
    
    final_damage = int(round(max(0.0, final_damage))) # 四舍五入并确保非负

    var actual_hp_change = character_owner.modify_hp(-final_damage) # Character.modify_hp返回实际变化
    health_changed.emit(character_owner, actual_hp_change, source_object)
        
    return -actual_hp_change # 返回正值代表造成的伤害

func restore_health(amount: int, source_char: Character = null, source_object = null) -> int:
    if not character_owner: return 0 # 允许给死亡单位回血（复活逻辑由特定技能效果处理）
    
    var actual_healed = character_owner.modify_hp(amount)
    health_changed.emit(character_owner, actual_healed, source_object)
    return actual_healed
#endregion

#region Status Management
func add_status(new_status_data_res: SkillStatusData, p_source_char: Character) -> Dictionary:
    if not character_owner or not new_status_data_res:
        return {"applied_successfully": false, "reason": "invalid_character_or_status_data"}

    var new_status_id: StringName = new_status_data_res.status_id

    # 1. 检查是否被现有状态抵抗
    for active_status_id in active_statuses:
        var active_status_runtime = active_statuses[active_status_id]
        var active_status_res: SkillStatusData = active_status_runtime.status_res
        if new_status_data_res.is_countered_by(active_status_res.status_id):
            # print("%s resisted by active status %s" % [new_status_id, active_status_res.status_id])
            return {"applied_successfully": false, "reason": "resisted_by_existing_status", "resisting_status_id": active_status_res.status_id}

    # 2. 如果此新状态会覆盖某些现有状态，则先移除它们
    if not new_status_data_res.overrides_states.is_empty():
        var ids_to_remove: Array[StringName] = []
        for id_to_override in new_status_data_res.overrides_states:
            if active_statuses.has(id_to_override):
                ids_to_remove.append(id_to_override)
        for id_rem in ids_to_remove:
            # print("Status %s overrides status %s. Removing %s." % [new_status_id, id_rem, id_rem])
            await remove_status(id_rem, true) # 触发被覆盖状态的结束效果

    # 3. 处理状态应用/叠加逻辑
    var applied_successfully = false
    var reason = "unknown"
    var current_stacks = 0
    var current_duration = 0
    var old_stacks = 0
    var old_duration = 0

    if active_statuses.has(new_status_id): # 状态已存在
        var existing_runtime = active_statuses[new_status_id]
        var existing_status_res: SkillStatusData = existing_runtime.status_res
        old_stacks = existing_runtime.stacks
        old_duration = existing_runtime.duration
        
        current_stacks = old_stacks # 默认层数不变

        match new_status_data_res.stack_behavior: # 使用新状态的叠加行为定义，因为是新实例应用
            SkillStatusData.StackBehavior.NO_STACK:
                # 通常意味着如果已存在，则什么都不做或仅刷新来源。这里我们刷新来源和持续时间。
                existing_runtime.source_char = p_source_char
                existing_runtime.duration = new_status_data_res.duration # 刷新为新状态定义的持续时间
                current_duration = existing_runtime.duration
                reason = "no_stack_refreshed"
            SkillStatusData.StackBehavior.REFRESH_DURATION:
                existing_runtime.duration = new_status_data_res.duration
                existing_runtime.source_char = p_source_char
                current_duration = existing_runtime.duration
                reason = "duration_refreshed"
            SkillStatusData.StackBehavior.ADD_DURATION:
                existing_runtime.duration += new_status_data_res.duration
                existing_runtime.source_char = p_source_char
                current_duration = existing_runtime.duration
                reason = "duration_added"
            SkillStatusData.StackBehavior.ADD_STACKS_REFRESH_DURATION:
                current_stacks = min(old_stacks + 1, new_status_data_res.max_stacks) # 使用新状态的max_stacks
                existing_runtime.stacks = current_stacks
                existing_runtime.duration = new_status_data_res.duration
                existing_runtime.source_char = p_source_char
                current_duration = existing_runtime.duration
                reason = "stacked_duration_refreshed"
            SkillStatusData.StackBehavior.ADD_STACKS_INDEPENDENT_DURATION:
                # 简化：此模式下，我们增加层数，并取新旧持续时间中较长的一个，或刷新为新的。
                # 真正独立持续时间需要更复杂的数据结构来追踪每个stack的duration。
                current_stacks = min(old_stacks + 1, new_status_data_res.max_stacks)
                existing_runtime.stacks = current_stacks
                existing_runtime.duration = max(existing_runtime.duration, new_status_data_res.duration) # 或者始终刷新
                existing_runtime.source_char = p_source_char
                current_duration = existing_runtime.duration
                reason = "stacked_independent_duration_simplified"
        
        if old_stacks != current_stacks or old_duration != current_duration:
            status_updated.emit(character_owner, new_status_id, existing_runtime, old_stacks, old_duration)
        applied_successfully = true

    else: # 新状态添加
        var runtime_info = {
            "status_res": new_status_data_res,
            "duration": new_status_data_res.duration,
            "stacks": 1,
            "source_char": p_source_char
        }
        active_statuses[new_status_id] = runtime_info
        current_stacks = 1
        current_duration = new_status_data_res.duration
        _apply_status_attribute_modifiers(new_status_data_res, true, new_status_id)
        reason = "newly_applied"
        applied_successfully = true
        status_applied.emit(character_owner, new_status_id, runtime_info)

    # 注意：初始效果由 SkillSystem 在调用此方法 *之后*，且成功应用后，再通过 SkillSystem 的效果处理流程来执行
    return {
        "applied_successfully": applied_successfully, 
        "reason": reason, 
        "status_id": new_status_id, 
        "current_stacks": current_stacks,
        "current_duration": current_duration
    }

func remove_status(status_id: StringName, trigger_end_effects: bool = true) -> bool:
    if active_statuses.has(status_id):
        var status_runtime_info = active_statuses.erase(status_id) # erase returns the value
        var status_data_res: SkillStatusData = status_runtime_info.status_res
        var source_char: Character = status_runtime_info.source_char

        _remove_status_attribute_modifiers(status_id) # 使用 status_id
        status_removed.emit(character_owner, status_data_res)

        if trigger_end_effects and skill_system_ref and not status_data_res.end_effects.is_empty():
            for effect_data in status_data_res.get_end_effects(): # 使用getter
                var effect_source = source_char if is_instance_valid(source_char) else character_owner
                await skill_system_ref.apply_effect_to_target(effect_data, effect_source, character_owner)
        return true
    return false

func _apply_status_attribute_modifiers(status_data_res: SkillStatusData, add: bool, p_status_id: StringName):
    if not character_owner or status_data_res.attribute_modifiers.is_empty():
        return

    # 假设Character上有AttributeSet组件或方法
    var attr_set = character_owner.get_node_or_null("AttributeSet") # 或者 character_owner.attribute_set
    if not attr_set or not attr_set.has_method("add_modifier_from_source") or not attr_set.has_method("remove_modifiers_by_source_id"):
        push_warning("Character %s is missing AttributeSet or required methods for status modifiers." % character_owner.name)
        return

    if add:
        # _status_applied_modifiers 不需要了，如果 AttributeSet 可以按 source_id 移除
        for mod_res in status_data_res.get_attribute_modifiers(): # 使用getter
            attr_set.add_modifier_from_source(mod_res, p_status_id) # AttributeSet需要记录来源ID
            attribute_modifier_applied.emit(character_owner, mod_res, p_status_id)
    else: # remove
        attr_set.remove_modifiers_by_source_id(p_status_id) # AttributeSet需要能按来源ID移除所有关联的modifier
        # 发出移除信号可能需要知道具体移除了哪些modifier，如果AttributeSet不返回它们，这里会比较麻烦
        # 简化：我们假设AttributeSet处理好移除，CombatComponent不追踪单个modifier实例
        # 如果需要精确追踪，_status_applied_modifiers 字典仍然有用

func _remove_status_attribute_modifiers(status_id: StringName):
    if not character_owner or not character_owner.is_alive: # 假设 Character 有 is_alive()
        return

    var attr_set = character_owner.get_node_or_null("AttributeSet") # 或者 character_owner.attribute_set
    if not attr_set or not attr_set.has_method("remove_modifiers_by_source_id"):
        push_warning("Character %s is missing AttributeSet or required method for removing modifiers." % character_owner.name)
        return

    attr_set.remove_modifiers_by_source_id(status_id) # AttributeSet需要能按来源ID移除所有关联的modifier
    attribute_modifier_removed.emit(character_owner, null, status_id)

func has_status(status_id: StringName) -> bool:
    return active_statuses.has(status_id)

func get_status_runtime_info(status_id: StringName) -> Dictionary:
    return active_statuses.get(status_id, null)

func get_status_stacks(status_id: StringName) -> int:
    var info = get_status_runtime_info(status_id)
    return info.stacks if info else 0

func get_status_remaining_duration(status_id: StringName) -> int:
    var info = get_status_runtime_info(status_id)
    return info.duration if info else 0

func get_all_active_statuses_info() -> Array[Dictionary]:
    var infos = []
    for id in active_statuses:
        infos.append(active_statuses[id])
    return infos
#endregion

#region Turn Processing
func on_end_of_turn():
    if not character_owner or not character_owner.is_alive: return
    if not skill_system_ref:
        push_warning("SkillSystem reference not set in CombatComponent for %s" % character_owner.name)
        # 考虑是否在此处终止，或允许无 SkillSystem 的情况下仅处理持续时间
        # return 

    var status_ids_to_process = active_statuses.keys()
    var expired_status_ids_this_turn : Array[StringName] = []

    for status_id in status_ids_to_process:
        if not active_statuses.has(status_id): continue

        var status_runtime = active_statuses[status_id]
        var status_res: SkillStatusData = status_runtime.status_res
        var status_source: Character = status_runtime.source_char

        if skill_system_ref and not status_res.ongoing_effects.is_empty():
            for effect_data in status_res.get_ongoing_effects(): # 使用getter
                var effect_source = status_source if is_instance_valid(status_source) else character_owner
                if character_owner.is_alive and active_statuses.has(status_id):
                    await skill_system_ref.apply_effect_to_target(effect_data, effect_source, character_owner)
                else: break 
        
        if not character_owner.is_alive or not active_statuses.has(status_id): continue

        if status_res.duration_type == SkillStatusData.DurationType.TURNS:
            status_runtime.duration -= 1
            if status_runtime.duration <= 0:
                expired_status_ids_this_turn.append(status_id)
    
    for expired_id in expired_status_ids_this_turn:
        if active_statuses.has(expired_id): # 再次检查，因为一个状态的结束效果可能移除了另一个即将到期的状态
            await remove_status(expired_id, true)
    
    if _is_defending:
        set_defending(false)
#endregion

#region Attribute Access
func get_calculated_attribute(attribute_key: StringName) -> float:
    if character_owner and character_owner.has_method("get_final_attribute_value"):
        return character_owner.get_final_attribute_value(attribute_key)
    push_warning("Character '%s' or get_final_attribute_value method not found for attribute '%s'" % [character_owner.name if character_owner else "Unknown", attribute_key])
    return 0.0
#endregion