extends EffectProcessor
class_name ControlEffectProcessor

## 获取处理器ID
func get_processor_id() -> String:
	return "control"

## 处理控制效果
func process_effect(effect: SkillEffectData, source: Character, target: Character) -> Dictionary:
	var results = {}
	
	# 播放施法动画
	_request_visual_effect("cast", source, {"element": effect.element})
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	# 计算控制效果是否命中
	var chance = effect.status_chance  # 复用status_chance作为控制效果命中率
	var roll = randf()
	var success = roll <= chance
	
	if success:
		# 应用控制效果
		var control_type = effect.control_type
		var duration = effect.control_duration
		
		# 使用Character类的apply_control_effect方法
		target.apply_control_effect(control_type, duration)
		
		# 播放控制效果动画
		_request_visual_effect("control_applied", target, {"control_type": control_type})
		
		# 角色状态变化信号
		var battle_mgr = _get_battle_manager()
		if battle_mgr and battle_mgr.has_signal("character_stats_changed"):
			battle_mgr.character_stats_changed.emit(target)
		
		# 记录结果
		results["control_applied"] = control_type
		results["duration"] = duration
		
		# 显示控制信息
		var control_name = get_control_name(control_type)
		var message = "[color=orange]%s 被%s，持续%d回合[/color]" % [target.character_name, control_name, duration]
		print_rich(message)
	else:
		# 控制效果未命中
		_request_visual_effect("control_resist", target, {})
		
		# 记录结果
		results["control_resisted"] = true
		
		# 显示抵抗信息
		var message = "[color=teal]%s 抵抗了控制效果[/color]" % target.character_name
		print_rich(message)
	
	return results

## 获取控制效果名称
func get_control_name(control_type: String) -> String:
	match control_type:
		"stun":
			return "眩晕"
		"silence":
			return "沉默"
		"root":
			return "定身"
		"sleep":
			return "睡眠"
		_:
			return control_type

## 获取效果描述
func get_effect_description(effect: SkillEffectData) -> String:
	var control_name = get_control_name(effect.control_type)
	var chance_text = ""
	if effect.status_chance < 1.0:
		var chance_percent = int(effect.status_chance * 100)
		chance_text = "(%d%%几率)" % chance_percent
		
	return "%s目标%s，持续%d回合" % [control_name, chance_text, effect.control_duration] 