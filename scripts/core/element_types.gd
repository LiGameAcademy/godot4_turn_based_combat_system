extends RefCounted
class_name ElementTypes

enum Element {
    NONE,     # 无属性
    FIRE,     # 火
    WATER,    # 水
    EARTH,    # 土
    LIGHT,    # 光
}

# 获取元素的名称（用于显示）
static func get_element_name(element: Element) -> String:
    match element:
        Element.NONE: return "无"
        Element.FIRE: return "火"
        Element.WATER: return "水"
        Element.EARTH: return "土"
        Element.LIGHT: return "光"
        _: return "未知"

# 获取元素的颜色（用于UI显示）
static func get_element_color(element: Element) -> Color:
    match element:
        Element.NONE: return Color.DARK_GRAY
        Element.FIRE: return Color(1.0, 0.3, 0.1) # 橙红色
        Element.WATER: return Color(0.2, 0.4, 1.0) # 蓝色
        Element.EARTH: return Color(0.6, 0.4, 0.2) # 棕色
        Element.LIGHT: return Color(1.0, 1.0, 0.8) # 淡黄白色
        _: return Color.WHITE

# 攻击系数常量
const EFFECTIVE_MULTIPLIER = 1.5      # 克制效果（伤害提高50%）
const INEFFECTIVE_MULTIPLIER = 0.5    # 被克制效果（伤害降低50%）
const NEUTRAL_MULTIPLIER = 1.0        # 普通效果

# 属性克制关系表 [攻击属性][防御属性]
static func get_effectiveness(attack_element: Element, defense_element: Element) -> float:
    # 如果任一方是无属性，则无克制关系
    if attack_element == Element.NONE or defense_element == Element.NONE:
        return NEUTRAL_MULTIPLIER
    
    # 创建克制关系表
    # 表示 "X攻击Y的效果系数"
    var effectiveness_table = {
        Element.FIRE: {
            Element.FIRE: NEUTRAL_MULTIPLIER,
            Element.WATER: INEFFECTIVE_MULTIPLIER,
            Element.EARTH: EFFECTIVE_MULTIPLIER,
            Element.LIGHT: NEUTRAL_MULTIPLIER
        },
        Element.WATER: {
            Element.FIRE: EFFECTIVE_MULTIPLIER,
            Element.WATER: NEUTRAL_MULTIPLIER,
            Element.EARTH: INEFFECTIVE_MULTIPLIER,
            Element.LIGHT: NEUTRAL_MULTIPLIER
        },
        Element.EARTH: {
            Element.FIRE: INEFFECTIVE_MULTIPLIER,
            Element.WATER: EFFECTIVE_MULTIPLIER,
            Element.EARTH: NEUTRAL_MULTIPLIER,
            Element.LIGHT: NEUTRAL_MULTIPLIER
        },
        Element.LIGHT: {
            Element.FIRE: NEUTRAL_MULTIPLIER,
            Element.WATER: NEUTRAL_MULTIPLIER,
            Element.EARTH: NEUTRAL_MULTIPLIER,
            Element.LIGHT: NEUTRAL_MULTIPLIER
        }
    }
    
    # 如果关系表中定义了这对元素的关系，返回对应系数
    if effectiveness_table.has(attack_element) and effectiveness_table[attack_element].has(defense_element):
        return effectiveness_table[attack_element][defense_element]
    
    # 默认为普通效果
    return NEUTRAL_MULTIPLIER 