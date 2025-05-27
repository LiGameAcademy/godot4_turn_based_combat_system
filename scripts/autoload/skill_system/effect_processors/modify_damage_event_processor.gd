extends EffectProcessor
class_name ModifyDamageEventProcessor

## 获取处理器ID
func get_processor_id() -> StringName:
	return &"modify_damage_event"

## 判断是否可以处理该效果
func can_process_effect(effect_data: SkillEffectData) -> bool:
	return effect_data.effect_type == SkillEffectData.EffectType.MODIFY_DAMAGE_EVENT

## 处理伤害修改效果
## 此处理器专门用于修改伤害事件，必须在 execution_context 中包含 damage_info
func process_effect(effect_data: SkillEffectData, execution_context: Dictionary) -> Dictionary:
	var source_character: Character = execution_context.get("source_character")
	var target_character: Character = execution_context.get("primary_target")
	var damage_info = execution_context.get("damage_info")
	
	var results = {"success": false, "message": "未执行伤害修改"}
	
	# 检查必要参数
	if not source_character or not target_character:
		push_warning("ModifyDamageEventProcessor: 源角色或目标角色为空。")
		return {"success": false, "message": "缺失源或目标"}
		
	if not damage_info:
		push_warning("ModifyDamageEventProcessor: 执行上下文中缺失伤害信息。")
		return {"success": false, "message": "缺失伤害信息"}
	
	# 检查伤害是否可以被修改
	if not damage_info.get("can_be_modified", true):
		results["message"] = "伤害已被锁定，无法修改"
		return results
	
	# 根据效果类型应用不同的伤害修改
	match effect_data.mod_dmg_event_type:
		SkillEffectData.DamageModificationType.NONE:
			results["message"] = "无效果类型"
			return results
			
		SkillEffectData.DamageModificationType.MODIFICATION_FLAT:
			# 应用固定值修改 (正数为增伤，负数为减伤)
			var original_value = damage_info["modified_damage_amount"]
			var new_value = original_value + effect_data.mod_dmg_value
			
			# 记录修改
			if not damage_info.has("modification_log"):
				damage_info["modification_log"] = []
			
			damage_info["modification_log"].append({
				"modifier_name": StringName(source_character.character_name + ":FLAT_MOD"),
				"change_amount": effect_data.mod_dmg_value,
				"original_value": original_value,
				"new_value": new_value,
				"type": "flat_modification"
			})
			
			# 更新伤害值
			damage_info["modified_damage_amount"] = new_value
			
			results["success"] = true
			results["message"] = "应用了固定值%s: %s" % [
				"增伤" if effect_data.mod_dmg_value >= 0 else "减伤",
				str(abs(effect_data.mod_dmg_value))
			]
			
		SkillEffectData.DamageModificationType.MODIFICATION_PERCENT:
			# 应用百分比修改 (正数为增伤，负数为减伤)
			var original_value = damage_info["modified_damage_amount"]
			var percent_change = effect_data.mod_dmg_value / 100.0
			var change_amount = original_value * percent_change
			var new_value = original_value + change_amount
			
			# 记录修改
			if not damage_info.has("modification_log"):
				damage_info["modification_log"] = []
			
			damage_info["modification_log"].append({
				"modifier_name": StringName(source_character.character_name + ":PERCENT_MOD"),
				"change_amount": change_amount,
				"original_value": original_value,
				"new_value": new_value,
				"type": "percentage_modification",
				"percent": effect_data.mod_dmg_value
			})
			
			# 更新伤害值
			damage_info["modified_damage_amount"] = new_value
			
		SkillEffectData.DamageModificationType.SET_DAMAGE_FLAT:
			# 直接设置伤害值（在这里用于完全阻挡伤害）
			var original_value = damage_info["modified_damage_amount"]
			var new_value = 0 # 设置为零实现完全阻挡
			
			# 记录修改
			if not damage_info.has("modification_log"):
				damage_info["modification_log"] = []
			
			damage_info["modification_log"].append({
				"modifier_name": StringName(source_character.character_name + ":BLOCK"),
				"change_amount": -original_value,
				"original_value": original_value,
				"new_value": new_value,
				"type": "block"
			})
			
			# 将伤害设为零
			damage_info["modified_damage_amount"] = new_value
			
			results["success"] = true
			results["message"] = "伤害已完全阻挡"
			
		SkillEffectData.DamageModificationType.REFLECT_DAMAGE_PERCENT:
			# 反弹伤害逻辑
			# 这里只记录反弹效果，实际反弹伤害需要在外部处理
			if not damage_info.has("tags"):
				damage_info["tags"] = []
			
			damage_info["tags"].append(&"reflected")
			results["reflected"] = true
			results["reflect_percent"] = effect_data.mod_dmg_value
			
			results["success"] = true
			results["message"] = "应用了伤害反弹：%.1f%%" % effect_data.mod_dmg_value
			
		SkillEffectData.DamageModificationType.ABSORPTION_FLAT:
			# 应用固定值吸收
			var original_damage = damage_info["modified_damage_amount"]
			var absorption_amount = min(original_damage, effect_data.mod_dmg_value)
			
			# 减少伤害
			var new_value = original_damage - absorption_amount
			damage_info["modified_damage_amount"] = new_value
			
			# 记录修改
			if not damage_info.has("modification_log"):
				damage_info["modification_log"] = []
			
			damage_info["modification_log"].append({
				"modifier_name": StringName(source_character.character_name + ":ABSORB_FLAT"),
				"change_amount": -absorption_amount,
				"original_value": original_damage,
				"new_value": new_value,
				"type": "absorb"
			})
			
			# 治疗施法者
			if source_character.has_method("heal"):
				source_character.heal(absorption_amount)
				
			results["success"] = true
			results["message"] = "吸收了 %s 点伤害并转化为治疗" % str(absorption_amount)
			
		SkillEffectData.DamageModificationType.ABSORPTION_PERCENT:
			# 应用百分比吸收
			var original_damage = damage_info.get_final_damage()
			var absorption_amount = round(original_damage * effect_data.mod_dmg_value)
			
			# 减少伤害
			damage_info.apply_flat_modification(
				-absorption_amount,
				StringName(source_character.character_name + ":ABSORB_PERCENT")
			)
			
			# 治疗施法者
			if source_character.has_method("heal"):
				source_character.heal(absorption_amount)
				
			results["success"] = true
			results["message"] = "吸收了 %s%% 伤害 (%s点) 并转化为治疗" % [
				str(effect_data.mod_dmg_value * 100),
				str(absorption_amount)
			]
			
		SkillEffectData.DamageModificationType.CONVERT_DAMAGE_TYPE:
			# 转换伤害类型
			var original_type = damage_info.damage_element
			damage_info.damage_element = effect_data.mod_dmg_new_damage_type
			
			results["success"] = true
			results["message"] = "将伤害类型从 %s 转换为 %s" % [
				ElementTypes.get_element_name(original_type),
				ElementTypes.get_element_name(effect_data.mod_dmg_new_damage_type)
			]
			
		SkillEffectData.DamageModificationType.SET_DAMAGE_FLAT:
			# 直接设置伤害值
			var original_damage = damage_info.get_final_damage()
			damage_info.modified_damage_amount = effect_data.mod_dmg_value
			
			results["success"] = true
			results["message"] = "将伤害值从 %s 直接设置为 %s" % [
				str(original_damage),
				str(effect_data.mod_dmg_value)
			]
			
		SkillEffectData.DamageModificationType.REFLECT_DAMAGE_PERCENT:
			# 反弹伤害百分比
			var original_damage = damage_info.get_final_damage()
			var reflect_amount = round(original_damage * effect_data.mod_dmg_value)
			
			# 如果反弹目标是伤害来源
			if effect_data.mod_dmg_reflect_target_is_source and damage_info.source_character:
				var reflect_target = damage_info.source_character
				
				# 对反弹目标造成伤害
				if reflect_target.has_method("take_damage"):
					reflect_target.take_damage(reflect_amount)
					
					# 显示反弹效果
					_request_visual_effect(&"damage_reflect", reflect_target, {
						"amount": reflect_amount,
						"from": target_character.character_name
					})
					
					print_rich("[color=orange]%s 反弹了 %s 点伤害给 %s[/color]" % [
						target_character.character_name,
						str(reflect_amount),
						reflect_target.character_name
					])
			
			results["success"] = true
			results["message"] = "反弹了 %s%% 伤害 (%s点)" % [
				str(effect_data.mod_dmg_value * 100),
				str(reflect_amount)
			]
			
		_:
			push_warning("ModifyDamageEventProcessor: 未知的伤害修改类型: %s" % str(effect_data.mod_dmg_event_type))
			results["message"] = "未知的伤害修改类型"
	
	# 如果成功修改了伤害，播放视觉效果
	if results.success:
		_request_visual_effect(&"damage_modified", target_character, {
			"message": results.message,
			"effect_type": SkillEffectData.DamageModificationType.keys()[effect_data.mod_dmg_event_type]
		})
	
	return results
