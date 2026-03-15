extends EventContext
class_name DamageEventContext

## 伤害事件

var target: Node
var damage_info: DamageInfo # 使用我们之前定义的DamageInfo类

func _init(p_source: Node, p_target: Node, p_damage_info: DamageInfo) -> void:
    super(p_source)
    target = p_target
    damage_info = p_damage_info