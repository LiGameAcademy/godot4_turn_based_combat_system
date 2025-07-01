extends SkillEffectData
class_name DispelEffectData

# 驱散效果参数
@export_group("驱散效果参数", "dispel_")
@export var dispel_types: Array[String] = []  	## 驱散的状态类型
@export var dispel_count: int = 1       		## 驱散数量
@export var dispel_is_positive: bool = false  	## 是否驱散正面效果
@export var dispel_is_all: bool = false        	## 是否全部驱散

## 获取驱散效果描述
func get_description() -> String:
	var count = dispel_count
	var is_positive = dispel_is_positive
	var type_name = "增益" if is_positive else "减益"
	return "驱散 %d 个%s效果" % [count, type_name]

func process_effect(source: Character, target: Character, _context : SkillExecutionContext) -> Dictionary:
	var results := { "success": false, "dispelled_count": 0, "dispelled_ids": [] }

	if not is_instance_valid(target):
		results["error"] = "Invalid target."
		push_error("DispelEffectProcessor: " + results.error)
		return results

	var dispel_target_type: SkillStatusData.StatusType = SkillStatusData.StatusType.BUFF if dispel_is_positive else SkillStatusData.StatusType.DEBUFF
	var count_to_dispel: int = dispel_count
	var dispel_all: bool = dispel_is_all
	
	# 播放施法/效果触发前视觉
	var cast_vfx_params = {"dispel_type": SkillStatusData.StatusType.keys()[dispel_target_type]}
	_request_visual_effect(&"dispel_cast", source, cast_vfx_params)

	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame

	var dispelled_this_action: Array[StringName] = []
	
	# 获取目标身上所有状态的运行时实例副本进行迭代，因为我们会在循环中移除
	var target_active_statuses_copy: Array = []
	if target.has_method("get_all_active_status_instances_for_check"): # Character 应有此方法
		target_active_statuses_copy = target.get_all_active_status_instances_for_check().duplicate()

	# 根据驱散类型筛选，并可能需要排序（例如，先驱散debuff中的控制类，或先驱散快结束的）
	var eligible_statuses_to_dispel: Array[SkillStatusData] = []
	for status_instance: SkillStatusData in target_active_statuses_copy: # 迭代的是运行时实例
		if is_instance_valid(status_instance) and status_instance.status_type == dispel_target_type:
			# TODO: 此处可以添加更复杂的筛选逻辑，例如是否可被驱散的标记
			eligible_statuses_to_dispel.append(status_instance)
	
	# TODO: 对 eligible_statuses_to_dispel 进行排序（如果需要特定驱散顺序）

	for status_to_dispel_instance: SkillStatusData in eligible_statuses_to_dispel:
		if dispel_all or results.dispelled_count < count_to_dispel:
			# remove_status_effect 需要 BattleManager 引用来触发结束效果
			var removed_successfully = await target.remove_skill_status(status_to_dispel_instance.status_id, true)
			if removed_successfully:
				results.dispelled_count += 1
				results.dispelled_ids.append(status_to_dispel_instance.status_id)
				dispelled_this_action.append(status_to_dispel_instance.status_name) # 用于消息
		else:
			break # 已达到驱散数量上限

	if results.dispelled_count > 0:
		results["success"] = true
		# 播放驱散成功视觉效果
		_request_visual_effect(&"dispel_success", target, {
			"count": results.dispelled_count, 
			"type_dispelled_key": SkillStatusData.StatusType.keys()[dispel_target_type]
			})
		if visual_effect != "": # 如果效果本身定义了特定视觉
			_request_visual_effect(visual_effect, target, results)

		var message = "[color=cyan]%s 从 %s 身上驱散了 %d 个%s效果: %s[/color]" % [
			source.character_name, 
			target.character_name, 
			results.dispelled_count, 
			SkillStatusData.StatusType.keys()[dispel_target_type],
			", ".join(dispelled_this_action)
		]
		print_rich(message)
	else:
		results["reason"] = "no_matching_statuses_to_dispel"
		var message = "[color=gray]%s 尝试驱散 %s 身上的%s效果，但未找到可驱散的目标。[/color]" % [
			source.character_name, 
			target.character_name, 
			SkillStatusData.StatusType.keys()[dispel_target_type]
		]
		print_rich(message)
		# 可以考虑为“无效果驱散”也播放一个视觉提示
		_request_visual_effect(&"dispel_nothing", target, {})


	return results
