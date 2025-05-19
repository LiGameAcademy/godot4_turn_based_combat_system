extends EffectProcessor
class_name DispelEffectProcessor

func get_processor_id() -> StringName:
    return &"dispel"

func can_process_effect(effect: SkillEffectData) -> bool:
    return effect.effect_type == SkillEffectData.EffectType.DISPEL

func process_effect(effect_data: SkillEffectData, _source: Character, target: Character) -> Dictionary:
    if effect_data.effect_type != SkillEffectData.EffectType.DISPEL:
        return {"error": "wrong_effect_type"}

    var target_combat_comp = _get_target_combat_component(target)
    if not target_combat_comp:
        return {"error": "invalid_target", "statuses_dispelled_count": 0}

    var dispel_types: Array[String] = effect_data.dispel_types # 状态类型字符串，或SkillStatusData.StatusType枚举值
    var dispel_count: int = effect_data.dispel_count
    var dispel_is_positive: bool = effect_data.dispel_is_positive # true驱散BUFF, false驱散DEBUFF
    var is_dispel_all: bool = effect_data.is_dispel_all

    var dispelled_statuses_info: Array[Dictionary] = []
    var active_statuses_copy = target_combat_comp.get_all_active_statuses_info() # 获取所有状态信息的副本

    var statuses_to_check = []
    for status_info in active_statuses_copy:
        var status_res: SkillStatusData = status_info.status_res
        # 根据 dispel_is_positive 筛选 BUFF 或 DEBUFF
        var type_matches = (dispel_is_positive and status_res.status_type == SkillStatusData.StatusType.BUFF) or \
                           (not dispel_is_positive and status_res.status_type == SkillStatusData.StatusType.DEBUFF)
        
        # 如果 dispel_types 非空，则还需检查类型是否匹配 (假设status_res.status_tags: Array[String] 或类似)
        var category_matches = true
        if not dispel_types.is_empty():
            category_matches = false
            for dt in dispel_types:
                # 假设 SkillStatusData 有一个 'tags' 数组或 'category' 字符串用于匹配 dispel_types
                if status_res.has_method("has_tag") and status_res.has_tag(dt): # 示例
                    category_matches = true
                    break
        
        if type_matches and category_matches:
            statuses_to_check.append(status_info)
            
    # TODO: 可能需要排序（例如，先驱散快过期的，或随机）
    
    var count_removed = 0
    for status_info_to_dispel in statuses_to_check:
        if is_dispel_all or count_removed < dispel_count:
            var status_id_to_remove = status_info_to_dispel.status_res.status_id
            var removed_success = target_combat_comp.remove_status(status_id_to_remove, true) # 触发结束效果
            if removed_success:
                count_removed += 1
                dispelled_statuses_info.append({"id": status_id_to_remove, "name": status_info_to_dispel.status_res.status_name})
        else:
            break # 已达到驱散数量上限

    if count_removed > 0:
        if effect_data.visual_effect != "":
            request_visual_effect(effect_data.visual_effect, target, {"count": count_removed, "is_positive": dispel_is_positive})
        # print("%s dispelled %d %s effects from %s" % [source.name, count_removed, "positive" if dispel_is_positive else "negative", target.name])

    return {
        "statuses_dispelled_count": count_removed,
        "dispelled_list": dispelled_statuses_info
    }