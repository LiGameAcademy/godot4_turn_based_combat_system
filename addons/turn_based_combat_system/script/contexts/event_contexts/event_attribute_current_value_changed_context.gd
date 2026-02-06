extends EventContext
class_name EventAttributeCurrentValueChangedContext

var attribute_id: StringName
var old_value: float
var new_value: float

func _init(p_source: Node, p_attribute_id: StringName, p_old_value: float, p_new_value: float) -> void:
	super(p_source)
	attribute_id = p_attribute_id
	old_value = p_old_value
	new_value = p_new_value
