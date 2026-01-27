extends SkillEffect
class_name MultiStrikeEffect

@export_group("多段攻击配置")
## 连击的总次数
@export var strike_count: int = 2
## 每一击的伤害倍率。数组的长度应与总次数匹配。
@export var strike_multipliers: Array[float] = [1.2, 1.0]
## 连击中每次攻击所使用的基础技能模板（通常是角色的普通攻击）
@export var base_attack_skill: SkillData
## 两次攻击之间的动画延迟
@export var delay_between_strikes: float = 0.2

func _init() -> void:
	description_format = "对【{count}】名随机敌人造成多段伤害，分别造成【{multipliers}】的伤害。"

func _get_base_description() -> String:
	# 1. 将伤害倍率的浮点数数组，转换成百分比字符串数组
	# [1.2, 1.0, 0.8] -> ["120%", "100%", "80%"]
	var multiplier_strings = strike_multipliers.map(
		func(multiplier): 
			return "%d%%" % (multiplier * 100)
	)

	# 2. 用“、”将百分比字符串连接起来
	# ["120%", "100%", "80%"] -> "120%、100%、80%"
	var damage_list_string = "、".join(multiplier_strings)

	# 3. 准备最终的格式化字符串模板
	var format_string = "对【%d】名随机敌人造成多段伤害，分别造成【%s】的伤害。"

	# 4. 将数据填入模板
	return format_string % [strike_count, damage_list_string]

func _process_effect(source: Node, _target: Node, context: SkillExecutionContext) -> Dictionary:
	var battle_manager: BattleManager = context.battle_manager

	# --- 1. 目标获取与筛选 ---
	# 从战场上获取所有存活的敌人
	var all_enemies = battle_manager.character_registry.get_all_alive_characters(false)
	all_enemies.shuffle() # 随机打乱
	
	# 选取不多于总数的敌人作为目标
	var targets_count = min(strike_count, all_enemies.size())
	var final_targets = all_enemies.slice(0, targets_count)

	if final_targets.is_empty():
		return {"success": false, "reason": "no_valid_targets"}

	# --- 2. 演出编排与执行 ---
	for i in range(final_targets.size()):
		var current_target = final_targets[i]
		
		# a. 准备“上下文覆写”，传递本段攻击的伤害倍率
		var override_context = {
			"damage_multiplier": strike_multipliers[i]
		}
		
		# b. 【核心】调用完整的、带演出的子行动
		#    我们复用之前为“连击”设计的子行动服务
		await battle_manager.execute_staged_sub_action(source, current_target, base_attack_skill, override_context)
		
		# c. 如果不是最后一次攻击，则等待一小段节奏延迟
		if i < final_targets.size() - 1:
			await source.get_tree().create_timer(delay_between_strikes).timeout

	return {"success": true}
