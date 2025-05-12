extends Resource
class_name SkillStatusData

# 状态效果类型枚举
enum EffectType {
	BUFF,       # 增益效果 (增强属性)
	DEBUFF,     # 减益效果 (削弱属性)
	DOT,        # 持续伤害 (Damage Over Time)
	HOT,        # 持续治疗 (Healing Over Time)
	CONTROL     # 控制效果 (限制行动)
}

# 作用的属性枚举
enum TargetStat {
	NONE,       				# 无特定属性 (用于DOT/HOT/CONTROL)
	ATTACK,     				# 攻击力
	DEFENSE,    				# 防御力
	MAGIC_ATTACK, 				# 魔法攻击力
	MAGIC_DEFENSE, 				# 魔法防御力
	SPEED,      				# 速度
	ALL_STATS   				# 所有属性
}

# 基本属性
@export var effect_id: String = "effect_id"           # 效果唯一标识符
@export var effect_name: String = "状态效果"            # 效果名称
@export var description: String = "一个状态效果"        # 效果描述
@export var effect_type: EffectType = EffectType.BUFF  # 效果类型
@export var icon_path: String = "res://assets/icons/status/default.png"  # 图标路径

# 效果设置
@export var initial_effects: Array[SkillEffectData] = [] # 初次应用时触发的效果
@export var ongoing_effects: Array[SkillEffectData] = [] # 每回合触发的效果
@export var end_effects: Array[SkillEffectData] = []     # 结束时触发的效果

# 目标属性和强度
@export var target_stat: TargetStat = TargetStat.ATTACK  # 影响的属性
@export var value_flat: int = 0         # 固定值修改 (如 +5 攻击力)
@export var value_percent: float = 0.0  # 百分比修改 (如 +20% 防御力)

# 持续伤害/治疗相关
@export var dot_hot_value: int = 0      # 每回合伤害/治疗量

# 控制效果相关
@export var can_act: bool = true        # 是否可以行动 (用于眩晕等效果)

# 持续时间和叠加规则
@export var duration: int = 3           # 持续回合数
@export var can_stack: bool = false     # 是否可叠加
@export var max_stacks: int = 1         # 最大叠加层数
@export_enum("replace", "extend_duration", "increase_intensity") var stack_behavior: String = "replace"  # 叠加行为

# 状态间关系
@export var overrides_states: Array[String] = []  # 此状态可以覆盖的其他状态
@export var resisted_by_states: Array[String] = []  # 会抵抗此状态的其他状态

# 获取效果类型的字符串表示
func get_effect_type_name() -> String:
	match effect_type:
		EffectType.BUFF: return "增益"
		EffectType.DEBUFF: return "减益"
		EffectType.DOT: return "持续伤害"
		EffectType.HOT: return "持续治疗"
		EffectType.CONTROL: return "控制"
		_: return "未知"

# 获取作用属性的字符串表示
func get_target_stat_name() -> String:
	match target_stat:
		TargetStat.NONE: return "无"
		TargetStat.ATTACK: return "攻击力"
		TargetStat.DEFENSE: return "防御力"
		TargetStat.MAGIC_ATTACK: return "魔法攻击"
		TargetStat.MAGIC_DEFENSE: return "魔法防御"
		TargetStat.SPEED: return "速度"
		TargetStat.ALL_STATS: return "所有属性"
		_: return "未知"

# 获取效果的完整描述
func get_full_description() -> String:
	var desc = description + "\n"
	
	# 添加初始效果描述
	if !initial_effects.is_empty():
		desc += "\n应用时:\n"
		for effect in initial_effects:
			desc += "- " + effect.get_description() + "\n"
	
	# 添加持续效果描述
	if !ongoing_effects.is_empty():
		desc += "\n每回合:\n"
		for effect in ongoing_effects:
			desc += "- " + effect.get_description() + "\n"
	
	# 添加结束效果描述
	if !end_effects.is_empty():
		desc += "\n结束时:\n"
		for effect in end_effects:
			desc += "- " + effect.get_description() + "\n"
	
	# 添加持续时间信息
	desc += "\n持续 " + str(duration) + " 回合"
	
	# 添加堆叠信息
	if can_stack:
		desc += " (可叠加，最多" + str(max_stacks) + "层)"
	
	return desc

# 检查是否允许角色行动
func allows_action() -> bool:
	if effect_type == EffectType.CONTROL:
		return can_act
	return true  # 非控制效果不影响行动

# 检查是否反制指定状态
func counters_status(status_id: String) -> bool:
	return overrides_states.has(status_id)

# 检查是否被指定状态反制
func is_countered_by(status_id: String) -> bool:
	return resisted_by_states.has(status_id) 
