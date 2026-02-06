extends EventContext
class_name EventStatusUpdatedContext

var status_id: StringName
var status_instance: SkillStatusData
var old_stacks: int
var old_duration: int

func _init(p_source: Node, p_status_id: StringName, p_status_instance: SkillStatusData, p_old_stacks: int, p_old_duration: int) -> void:
	super(p_source)
	status_id = p_status_id
	status_instance = p_status_instance
	old_stacks = p_old_stacks
	old_duration = p_old_duration