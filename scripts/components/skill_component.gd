# res://scripts/components/skill_component.gd
extends Node
class_name SkillComponent

#region Signals
signal status_applied(character_node: Character, status_id: StringName, status_runtime_info: Dictionary)
signal status_removed(character_node: Character, removed_status_data_res: SkillStatusData)
signal status_updated(character_node: Character, status_id: StringName, status_runtime_info: Dictionary, old_stacks: int, old_duration: int)
# AttributeSet的信号可以被Character或其他系统直接连接，或者SkillComponent可以中继它们
# signal attribute_current_value_changed(attribute_instance: SkillAttribute, old_current_value: float, new_current_value: float, source: Variant)
#endregion

#region Variables
var character_owner: Character :
    get:
        return get_parent()
## 由 BattleManager -> Character -> CombatComponent -> SkillComponent 注入，或直接由 Character 注入
var skill_system_ref: SkillSystem 
## 在编辑器中分配属性集模板资源
@export var attribute_set_resource_template: SkillAttributeSet 
## 运行时唯一的属性集实例
var attribute_set_instance: SkillAttributeSet 
## 角色已学习的技能
var learned_skills: Array[SkillData] = [] 
## 激活的状态列表
var active_statuses: Dictionary[StringName, SkillStatusData] = {}
#endregion

## 初始化技能组件
func initialize(p_character_data: CharacterData):
    if p_character_data:
        if p_character_data.attribute_set_resource:
            self.attribute_set_resource_template = p_character_data.attribute_set_resource
        self.learned_skills = p_character_data.skills.duplicate(true) # 复制技能列表

    if not attribute_set_resource_template:
        push_error("SkillComponent for '%s' requires an AttributeSet resource template." % character_owner.name)
        return

    attribute_set_instance = attribute_set_resource_template.duplicate(true) # 深拷贝
    attribute_set_instance.initialize_set() # 初始化属性实例
    
    # (可选) 连接 AttributeSet 的信号，如果 SkillComponent 需要直接响应或中继它们
    # attribute_set_instance.current_value_changed.connect(_on_attribute_set_current_value_changed)

    print("SkillComponent for '%s' initialized." % character_owner.name)

func set_skill_system_reference(p_skill_system: SkillSystem):
    skill_system_ref = p_skill_system

#region Attribute Management
func get_calculated_attribute(attribute_name: StringName) -> float:
    if attribute_set_instance:
        return attribute_set_instance.get_current_value(attribute_name)
    return 0.0

#endregion

#region Status Management
func add_status(new_status_data_res: SkillStatusData, p_source_char: Character) -> Dictionary:
    if not character_owner or not new_status_data_res:
        return {"applied_successfully": false, "reason": "invalid_character_or_status_data"}

    var new_status_id: StringName = new_status_data_res.status_id
    var result_info = {"applied_successfully": false, "reason": "unknown", "status_id": new_status_id, "current_stacks": 0, "current_duration": 0}

    # 1. 检查是否被现有状态抵抗
    for active_status_id : StringName in active_statuses:
        if new_status_data_res.is_countered_by(active_status_id):
            # 状态抵抗
            result_info.reason = "resisted_by_existing_status: %s" % active_status_id
            return result_info

    # 2. 如果此新状态会覆盖某些现有状态，则先移除它们
    if not new_status_data_res.overrides_states.is_empty():
        for id_to_override : StringName in new_status_data_res.overrides_states:
            if active_statuses.has(id_to_override):
                await remove_status(id_to_override, true) # 触发被覆盖状态的结束效果
    var old_stacks = 0
    var old_duration = 0

    # 3. 检查状态是否已存在
    if active_statuses.has(new_status_id): # 状态已存在，处理叠加
        var existing_status_res: SkillStatusData = active_statuses[new_status_id]
        old_stacks = existing_status_res.stacks
        old_duration = existing_status_res.left_duration

        match new_status_data_res.stack_behavior:
            SkillStatusData.StackBehavior.NO_STACK:
                existing_status_res.source_char = p_source_char
                existing_status_res.left_duration = new_status_data_res.duration
                result_info.reason = "no_stack_refreshed"
            SkillStatusData.StackBehavior.REFRESH_DURATION:
                existing_status_res.left_duration = new_status_data_res.duration
                existing_status_res.source_char = p_source_char
                result_info.reason = "duration_refreshed"
            SkillStatusData.StackBehavior.ADD_DURATION:
                existing_status_res.left_duration += new_status_data_res.duration
                existing_status_res.source_char = p_source_char
                result_info.reason = "duration_added"
            SkillStatusData.StackBehavior.ADD_STACKS_REFRESH_DURATION:
                # 增加层数并刷新持续时间
                var new_s = min(old_stacks + 1, new_status_data_res.max_stacks)
                if new_s > old_stacks: # 层数实际增加才应用新的修改器
                     _apply_modifiers_from_status(new_status_data_res, new_status_id, true) #  每个stack可能都应用一次modifier
                existing_status_res.stacks = new_s
                existing_status_res.left_duration = new_status_data_res.duration
                existing_status_res.source_char = p_source_char
                result_info.reason = "stacked_duration_refreshed"
            SkillStatusData.StackBehavior.ADD_STACKS_INDEPENDENT_DURATION:
                # 增加层数并独立持续时间
                var new_s_ind = min(old_stacks + 1, new_status_data_res.max_stacks)
                if new_s_ind > old_stacks:
                    _apply_modifiers_from_status(new_status_data_res, new_status_id, true)
                existing_status_res.stacks = new_s_ind
                existing_status_res.left_duration = new_status_data_res.duration 
                existing_status_res.source_char = p_source_char
                result_info.reason = "stacked_independent_simplified"
        
        result_info.current_stacks = existing_status_res.stacks
        result_info.current_duration = existing_status_res.left_duration
        if old_stacks != result_info.current_stacks or old_duration != result_info.current_duration:
            status_updated.emit(character_owner, new_status_id, existing_status_res, old_stacks, old_duration)
        result_info.applied_successfully = true
    else: # 新状态添加
        var runtime_info = {
            "status_res": new_status_data_res,
            "duration": new_status_data_res.duration,
            "stacks": 1,
            "source_char": p_source_char
        }
        active_statuses[new_status_id] = new_status_data_res
        _apply_modifiers_from_status(new_status_data_res, new_status_id, true)
        result_info.reason = "newly_applied"
        result_info.applied_successfully = true
        status_applied.emit(character_owner, new_status_id, runtime_info)

    return result_info

## 移除状态，并可选地触发其结束效果 (通过SkillSystem)
func remove_status(status_id: StringName, trigger_end_effects: bool = true) -> bool:
    if active_statuses.has(status_id):
        active_statuses.erase(status_id)
        var status_data_res: SkillStatusData = active_statuses[status_id]
        var source_char: Character = status_data_res.source_char

        _apply_modifiers_from_status(status_data_res, status_id, false) # 移除修改器
        status_removed.emit(character_owner, status_data_res)

        # 触发结束效果
        if trigger_end_effects and skill_system_ref and not status_data_res.end_effects.is_empty():
            for effect_data in status_data_res.end_effects:
                var effect_source = source_char if is_instance_valid(source_char) else character_owner
                if character_owner.is_alive: 
                    # 仅当角色存活时才尝试应用结束效果（除非效果本身是复活等）
                    await skill_system_ref.apply_effect(effect_data, effect_source, character_owner)
        return true
    return false

## 检查是否拥有某个状态
## [param status_id]: 要检查的状态ID
## [return]: 是否拥有该状态
func has_status(status_id: StringName) -> bool:
    return active_statuses.has(status_id)

## 获取状态的运行时信息
## [param status_id]: 要获取的状态ID
## [return]: 状态的运行时信息，或null
func get_status_runtime_info(status_id: StringName) -> Dictionary:
    return active_statuses.get(status_id, null)

## 获取状态的当前层数
## [param status_id]: 要获取的状态ID
## [return]: 状态的当前层数
func get_status_stacks(status_id: StringName) -> int:
    var info = get_status_runtime_info(status_id)
    return info.stacks if info else 0

## 由 CombatComponent 在回合结束时调用
func process_statuses_end_of_turn() -> void:
    if not character_owner or not character_owner.is_alive: return
    if not skill_system_ref:
        push_warning("SkillSystem reference not set in SkillComponent for '%s'" % character_owner.name)
        return # 如果没有SkillSystem，则无法处理效果

    var status_ids_to_process = active_statuses.keys()
    var expired_status_ids_this_turn : Array[StringName] = []   # 这回合过期的状态ID

    for status_id in status_ids_to_process:
        if not active_statuses.has(status_id): continue # 可能已被其他效果移除

        var status_res: SkillStatusData = active_statuses[status_id]
        var status_source: Character = status_res.source_char

        # 1. 执行持续效果 (通过SkillSystem)
        if skill_system_ref and not status_res.ongoing_effects.is_empty():
            for effect_data in status_res.get_ongoing_effects():
                var effect_source = status_source if is_instance_valid(status_source) else character_owner
                if character_owner.is_alive and active_statuses.has(status_id): # 再次检查
                    await skill_system_ref.apply_effect_to_target(effect_data, effect_source, character_owner)
                else: break
        
        if not character_owner.is_alive or not active_statuses.has(status_id): continue

        # 2. 更新持续时间
        if status_res.duration_type == status_res.DurationType.TURNS:
            status_res.duration -= 1
            # print("%s's status %s duration now %d" % [character_owner.name, status_id, status_res.duration])
            if status_res.duration <= 0:
                expired_status_ids_this_turn.append(status_id)
    
    # 3. 移除到期的状态 (并触发结束效果)
    for expired_id in expired_status_ids_this_turn:
        if active_statuses.has(expired_id):
            await remove_status(expired_id, true)
#endregion

#region Skill Knowledge
## 获取已学习的技能
func get_learned_skills() -> Array[SkillData]:
    return learned_skills

## 检查是否可以使用某个技能
func can_use_skill(skill_data: SkillData) -> bool:
    if not learned_skills.has(skill_data):
        return false # 未学习此技能
    if attribute_set_instance.get_current_value(&"CurrentMana") < skill_data.mp_cost:
        return false # MP不足
    # TODO: 检查技能冷却等其他条件
    return true

## 添加已学习的技能
func add_skill(skill_data: SkillData):
    learned_skills.append(skill_data)

## 移除已学习的技能
func remove_skill(skill_data: SkillData):
    learned_skills.erase(skill_data)

## 判断是否已学习某个技能
func has_skill(skill_data: SkillData) -> bool:
    return learned_skills.has(skill_data)

#endregion


# 应用/移除由状态提供的属性修改器
func _apply_modifiers_from_status(status_data_res: SkillStatusData, status_id_source: StringName, add: bool):
    if not attribute_set_instance or not status_data_res or status_data_res.attribute_modifiers.is_empty():
        return

    for mod_res in status_data_res.get_attribute_modifiers():
        if add:
            attribute_set_instance.apply_modifier(mod_res.attribute_to_modify, mod_res, status_id_source) # 假设AttributeSet有此方法
        else:
            attribute_set_instance.remove_modifier(mod_res.attribute_to_modify, mod_res, status_id_source) # 假设AttributeSet有此方法
