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
	var damage_info: DamageInfo = execution_context.get("damage_info")
	
	var results = {"success": false, "message": "未执行伤害修改"}
	
	# 检查必要参数
	if not source_character or not target_character:
		push_warning("ModifyDamageEventProcessor: Source or target character is null.")
		return {"success": false, "message": "Source or target missing."}
		
	if not damage_info:
		push_warning("ModifyDamageEventProcessor: DamageInfo missing in execution_context.")
		return {"success": false, "message": "DamageInfo missing."}
	
	# 检查伤害是否可以被修改
	if not damage_info.can_be_modified:
		results["message"] = "伤害已被锁定，无法修改"
		return results
	
	# 根据效果类型应用不同的伤害修改
	match effect_data.mod_dmg_event_type:
		SkillEffectData.DamageModificationType.NONE:
			results["message"] = "无效果类型"
			return results
			
		SkillEffectData.DamageModificationType.MODIFICATION_FLAT:
			# 应用固定值修改 (正数为增伤，负数为减伤)
			damage_info.apply_flat_modification(
				effect_data.mod_dmg_value, 
				StringName(source_character.character_name + ":FLAT_MOD")
			)
			results["success"] = true
			results["message"] = "应用了固定值%s: %s" % [
				"增伤" if effect_data.mod_dmg_value >= 0 else "减伤",
				str(abs(effect_data.mod_dmg_value))
			]
			
		SkillEffectData.DamageModificationType.MODIFICATION_PERCENT:
			# 应用百分比修改 (正数为增伤，负数为减伤)
			damage_info.apply_percentage_modification(
				effect_data.mod_dmg_value,
				StringName(source_character.character_name + ":PERCENT_MOD")
			)
			results["success"] = true
			results["message"] = "应用了百分比%s: %s%%" % [
				"增伤" if effect_data.mod_dmg_value >= 0 else "减伤",
				str(abs(effect_data.mod_dmg_value) * 100)
			]
			
		SkillEffectData.DamageModificationType.ABSORPTION_FLAT:
			# 应用固定值吸收
			var original_damage = damage_info.get_final_damage()
			var absorption_amount = min(original_damage, effect_data.mod_dmg_value)
			
			# 减少伤害
			damage_info.apply_flat_modification(
				-absorption_amount,
				StringName(source_character.character_name + ":ABSORB_FLAT")
			)
			
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
