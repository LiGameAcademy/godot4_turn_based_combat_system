@abstract
extends Resource
class_name SkillEffect

# 基本属性
@export var disable : bool = false													## 是否禁用
@export var visual_effect: String = ""  											## 视觉效果标识符
@export var sound_effect: String = ""   											## 音效标识符
@export_multiline var description_format: String = ""								## 效果描述格式
## 目标覆盖类型
@export_enum("none", "self_only", "all_allies", "all_enemies", "all_allies_and_self") 
var target_override: String = "none"
## 元素属性
@export_enum("none", "fire", "water", "earth", "light") var element: int = 0 # ElementTypes.Element.NONE 

@export var pre_process_delay: float = 0.2											## 处理前延迟
@export var post_process_delay: float = 0.0											## 处理后延迟

## 子效果
@export var sub_effects: Array[SkillEffect] = []

@export_group("执行条件")
@export var conditions: Array[SkillCondition] = []

## 信号：效果处理完成
signal effect_processed(source: Node, target: Node, result: Dictionary)

## 供外部调用的、完整的描述方法
func get_description() -> String:
	var base_desc = _get_base_description() # 获取效果自身的基础描述
	if conditions.is_empty():
		return base_desc

	var condition_descs: Array[String] = []
	for condition in conditions:
		if is_instance_valid(condition):
			condition_descs.append(condition.get_description())
			
	# 将效果描述和条件描述组合起来
	return "%s [%s]" % [base_desc, ", ".join(condition_descs)]

## 处理效果 - 主要接口方法
## [return] 处理结果的字典
func process_effect(source: Node, target: Node, context : SkillExecutionContext) -> Dictionary:
	if disable : return {"success": false,"reason": "Effect is disabled"}

	# 检查参数有效性
	if not is_instance_valid(source):
		push_error("SkillEffect: 无效的角色引用")
		return {
			"success": false,
			"reason": "Invalid source node reference!"
		}

	elif not is_instance_valid(self):
		push_error("SkillEffect: 无效的效果引用")
		return {
			"success": false,
			"reason": "Invalid effect reference!"
		}

	var effect_targets = _get_determine_targets(source, [target], context)
	if effect_targets.is_empty():
		push_warning("SkillEffect: No valid targets for effect '%s'" % resource_name)
		return {
			"success": false,
			"reason": "No valid targets"
		}

	var results: Dictionary = {"success": true, "reason": ""}
	for effect_target in effect_targets:
		# 1. 准备用于条件检查的上下文
		var condition_context = {"source": source, "targets": target}

		# 2. 检查所有条件是否满足
		for condition : SkillCondition in conditions:
			if not condition.is_met(condition_context):
				print_rich("[color=gray]效果 %s 因条件 %s 未满足而被跳过。[/color]" % [resource_name, condition.resource_name])
				return {
					"success": false,
					"reason": "Condition not met: %s" % condition.get_description()
				}# 任何一个条件不满足，则直接跳过此效果	

		# 3. 执行效果
		await source.get_tree().create_timer(pre_process_delay).timeout
		var result = await _process_effect(source, target, context)
		await source.get_tree().create_timer(post_process_delay).timeout
		results[effect_target] = result

	for sub_effect in sub_effects:
		if not is_instance_valid(sub_effect):
			push_warning("SkillEffect: 无效的子效果引用")
			continue
		results[sub_effect] =  await sub_effect.process_effect(source, target, context)

	effect_processed.emit(source, target, results)
	return results

## 确定效果的实际目标
## [param context] 技能执行上下文
## [param caster] 施法者
## [param effect] 效果数据
## [param initial_targets] 初始目标
## [return] 效果的实际目标
func _get_determine_targets(caster: Node, targets: Array[Node], context : SkillExecutionContext) -> Array[Node]:
	# 默认使用技能的目标
	var effect_targets: Array[Node] = targets.duplicate()
	
	# TODO 如果效果有特殊的目标覆盖规则，可以在这里处理
	# 例如，某些效果可能会影响主目标周围的敌人，或者只影响施法者自己
	
	# 示例：如果效果有target_override属性，可以根据它来确定目标
	if target_override != "none":
		match target_override:
			"self_only":
				effect_targets = [caster] if is_instance_valid(caster) else []
			"all_allies":
				effect_targets = context.battle_manager.get_valid_ally_targets(caster, false)
			"all_enemies":
				effect_targets = context.battle_manager.get_valid_enemy_targets(caster)
			"all_allies_and_self":
				effect_targets = context.battle_manager.get_valid_ally_targets(caster, true)
	return effect_targets

## 通用辅助方法
## [param effect_type] 视觉效果类型
## [param target] 目标角色
## [param params] 视觉效果参数
## 发送视觉效果请求
func _request_visual_effect(effect_type: StringName, target: Character, battle_manager: BattleManager, params: Dictionary = {}) -> void:
	if not is_instance_valid(battle_manager):
		push_error("SkillEffect: 无效的战斗管理器引用")
		return
	
	# 分发到适当的视觉效果方法
	var method_name : String = "_play_" + effect_type + "_effect"
	if battle_manager.has_method(method_name):
		battle_manager.call(method_name, target, params)
	else:
		push_warning("SkillEffect: 未找到视觉效果方法 " + method_name)

@abstract func _process_effect(source: Node, target: Node, context: SkillExecutionContext) -> Dictionary

## 内部方法，供子类重写，只负责描述效果本身
@abstract func _get_base_description() -> String
