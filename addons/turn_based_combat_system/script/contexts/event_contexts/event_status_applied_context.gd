extends EventContext
class_name EventStatusAppliedContext

var status_instance: SkillStatusData

func _init(p_source: Node, p_status_instance: SkillStatusData) -> void:
	super(p_source)
	status_instance = p_status_instance
