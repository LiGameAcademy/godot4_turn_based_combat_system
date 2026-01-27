extends BaseCombatCharacter
class_name CharacterInheritanceExample

## 继承 BaseCombatCharacter 的示例
## 展示如何在业务层继承基础角色类并自定义行为

func _ready() -> void:
	super()
	# 添加自定义初始化逻辑
	print("自定义角色初始化")

## 重写执行行动方法，添加自定义逻辑
func execute_action(action_type: CharacterCombatComponent.ActionType, target: Node = null, params: Dictionary = {}) -> void:
	# 添加自定义逻辑（例如：记录行动日志）
	print("角色 %s 执行行动: %s" % [character_name, action_type])
	
	# 调用父类方法
	await super(action_type, target, params)
	
	# 行动后的自定义逻辑
	print("行动执行完成")

## 重写伤害处理方法，添加自定义效果
func take_damage(base_damage: float, source: Node, p_element: int, is_melee: bool) -> float:
	# 添加自定义逻辑（例如：伤害减免）
	var final_damage = base_damage * 0.9  # 10% 伤害减免
	
	# 调用父类方法
	var result = await super(final_damage, source, p_element, is_melee)
	
	# 伤害后的自定义逻辑
	if result > 0:
		print("受到 %f 点伤害" % result)
	
	return result

## 重写回合开始方法
func on_turn_start(battle_manager: Node) -> void:
	super(battle_manager)
	# 添加自定义回合开始逻辑
	print("回合开始：%s" % character_name)

## 重写回合结束方法
func on_turn_end(battle_manager: Node) -> void:
	super(battle_manager)
	# 添加自定义回合结束逻辑
	print("回合结束：%s" % character_name)
