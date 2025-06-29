extends RefCounted
class_name ElementTypes

## 元素克制系统

enum {
	NONE,     # 无属性
	FIRE,     # 火
	WATER,    # 水
	EARTH,    # 土
	LIGHT,    # 光
}

# 攻击系数常量
const EFFECTIVE_MULTIPLIER = 1.5      # 克制效果（伤害提高50%）
const INEFFECTIVE_MULTIPLIER = 0.5    # 被克制效果（伤害降低50%）
const NEUTRAL_MULTIPLIER = 1.0        # 普通效果

# 属性克制关系表 [攻击属性][防御属性]
static func get_effectiveness(attack_element: int, defense_element: int) -> float:
	# 如果任一方是无属性，则无克制关系
	if attack_element == ElementTypes.NONE or defense_element == ElementTypes.NONE:
		return NEUTRAL_MULTIPLIER
	
	# 创建克制关系表
	# 表示 "X攻击Y的效果系数"
	var effectiveness_table = {
		ElementTypes.FIRE: {
			# 火被水克制，能够克制土
			ElementTypes.FIRE: NEUTRAL_MULTIPLIER,
			ElementTypes.WATER: INEFFECTIVE_MULTIPLIER,
			ElementTypes.EARTH: EFFECTIVE_MULTIPLIER,
			ElementTypes.LIGHT: NEUTRAL_MULTIPLIER
		},
		ElementTypes.WATER: {
			# 水被土克制，能够克制火
			ElementTypes.FIRE: EFFECTIVE_MULTIPLIER,
			ElementTypes.WATER: NEUTRAL_MULTIPLIER,
			ElementTypes.EARTH: INEFFECTIVE_MULTIPLIER,
			ElementTypes.LIGHT: NEUTRAL_MULTIPLIER
		},
		ElementTypes.EARTH: {
			ElementTypes.FIRE: INEFFECTIVE_MULTIPLIER,
			ElementTypes.WATER: EFFECTIVE_MULTIPLIER,
			ElementTypes.EARTH: NEUTRAL_MULTIPLIER,
			ElementTypes.LIGHT: NEUTRAL_MULTIPLIER
		},
		ElementTypes.LIGHT: {
			ElementTypes.FIRE: NEUTRAL_MULTIPLIER,
			ElementTypes.WATER: NEUTRAL_MULTIPLIER,
			ElementTypes.EARTH: NEUTRAL_MULTIPLIER,
			ElementTypes.LIGHT: NEUTRAL_MULTIPLIER
		}
	}
	
	# 如果关系表中定义了这对元素的关系，返回对应系数
	if effectiveness_table.has(attack_element) and effectiveness_table[attack_element].has(defense_element):
		return effectiveness_table[attack_element][defense_element]
	
	# 默认为普通效果
	return NEUTRAL_MULTIPLIER

# 获取元素的名称（用于显示）
static func get_element_name(element: int) -> String:
	match element:
		ElementTypes.NONE: return "无"
		ElementTypes.FIRE: return "火"
		ElementTypes.WATER: return "水"
		ElementTypes.EARTH: return "土"
		ElementTypes.LIGHT: return "光"
		_: return "未知"

# 获取元素的颜色（用于UI显示）
static func get_element_color(element: int) -> Color:
	match element:
		ElementTypes.NONE: return Color.DARK_GRAY
		ElementTypes.FIRE: return Color(1.0, 0.3, 0.1) # 橙红色
		ElementTypes.WATER: return Color(0.2, 0.4, 1.0) # 蓝色
		ElementTypes.EARTH: return Color(0.6, 0.4, 0.2) # 棕色
		ElementTypes.LIGHT: return Color(1.0, 1.0, 0.8) # 淡黄白色
		_: return Color.WHITE
