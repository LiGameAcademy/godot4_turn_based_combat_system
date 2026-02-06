extends EventContext
class_name EventStatusRemovedContext

var status_id: StringName
var status_instance_data_before_removal: SkillStatusData

func _init(p_source: Node, p_status_id: StringName, p_status_instance_data_before_removal: SkillStatusData) -> void:
	super(p_source)
	status_id = p_status_id
	status_instance_data_before_removal = p_status_instance_data_before_removal
