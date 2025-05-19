extends EffectProcessor
class_name StatusEffectProcessor

## 获取处理器ID
func get_processor_id() -> StringName:
	return "apply_status"

## 判断是否可以处理该效果
func can_process(effect: SkillEffectData) -> bool:
	return effect.effect_type == effect.SkillEffectType.STATUS

## 处理状态效果
func process_effect(effect: SkillEffectData, source: Character, target: Character) -> Dictionary:
	var results = {}
	
	# 播放施法动画
	request_visual_effect("cast", source, {"element": effect.element})
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	# 计算状态效果是否命中
	var chance = effect.status_chance
	var roll = randf()
	var success = roll <= chance
	
	if success:
		var status_effect = effect.status
		if status_effect:
			# 应用状态效果
			target.add_status(status_effect, source)
			
			# 播放状态效果动画
			request_visual_effect("status_applied", target, {"status_id": effect.status_id})
			
			# 角色状态变化信号
			var battle_mgr = _get_battle_manager()
			if battle_mgr and battle_mgr.has_signal("character_stats_changed"):
				battle_mgr.character_stats_changed.emit(target)
			
			# 记录结果
			results["status_applied"] = effect.status_id
			
			# 显示状态信息
			var message = "[color=purple]%s 被施加了 %s 状态[/color]" % [target.character_name, status_effect.effect_name]
			print_rich(message)
		else:
			push_error("无法加载状态效果: %s" % effect.status_id)
	else:
		# 状态效果未命中
		request_visual_effect("status_resist", target, {})
		
		# 记录结果
		results["status_resisted"] = true
		
		# 显示抵抗信息
		var message = "[color=teal]%s 抵抗了状态效果[/color]" % target.character_name
		print_rich(message)
	
	return results