extends EventContext
class_name EventHealCompletedContext

var amount: float
var healer: Node

func _init(p_source: Node, p_amount: float, p_healer: Node) -> void:
	super(p_source)
	amount = p_amount
	healer = p_healer
