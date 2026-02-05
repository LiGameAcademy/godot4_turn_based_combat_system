extends Node
class_name BattleCharacterRegistryManager

## 参与战斗的角色注册管理器
## 负责管理战斗中的角色注册和反注册
## 包括队伍管理和角色状态跟踪

enum TeamType {
	PLAYER,
	ENEMY
}

var _player_team: Array[Node] = []				## 玩家队伍
var _enemy_team: Array[Node] = []				## 敌人队伍

signal character_registered(character: Node)							## 角色注册信号
signal character_unregistered(character: Node)							## 角色反注册信号
signal team_changed(team_characters: Array[Node], team_id: TeamType)	## 队伍变化信号

## 初始化
func initialize() -> void:
	_player_team.clear()
	_enemy_team.clear()
	print_rich("[color=purple][角色注册管理器][/color] 已初始化")

## 注册一个角色到战斗中
## [param character] 要注册的角色
## [param is_player_team] 是否是玩家队伍
## [return] 是否注册成功
func register_character(character: Node, is_player_team: bool) -> bool:
	if not is_instance_valid(character):
		push_error("Attempted to register an invalid character instance.")
		return false

	var combat_component : CharacterCombatComponent = character.get_combat_component() if character.has_method("get_combat_component") else null
	if not is_instance_valid(combat_component):
		push_error("Character %s has no combat component." % character.character_name)
		return false

	if is_player_team and not _player_team.has(character):
		_player_team.append(character)
		team_changed.emit(_player_team, TeamType.PLAYER)
	else:
		_enemy_team.append(character)
		team_changed.emit(_enemy_team, TeamType.ENEMY)

	character_registered.emit(character)
	print_rich("[color=purple][角色注册管理器][/color] 角色 %s 已注册 (玩家队伍: %s)" % [character.get_character_name(), "是" if is_player_team else "否"])
	return true

## 从战斗中反注册一个角色
## [param character] 要反注册的角色
## [return] 是否反注册成功
func unregister_character(character: Node) -> bool:
	if not is_instance_valid(character):
		push_warning("无法反注册一个无效的角色: %s" % character)
		return false

	var combat_component : CharacterCombatComponent = character.get_combat_component() if character.has_method("get_combat_component") else null
	if not is_instance_valid(combat_component):
		push_error("Character %s has no combat component." % character.character_name)
		return false

	var team_id_changed : TeamType
	if character in _player_team:
		_player_team.erase(character)
		team_id_changed = TeamType.PLAYER
	elif character in _enemy_team:
		_enemy_team.erase(character)
		team_id_changed = TeamType.ENEMY
	
	character_unregistered.emit(character)
	team_changed.emit(_player_team, team_id_changed)
	var team_name : String = "玩家" if team_id_changed == TeamType.PLAYER else "敌人"
	print_rich("[color=purple][角色注册管理器][/color] 角色 %s 已反注册 (玩家队伍: %s)" % [character.get_character_name(), team_name])
	return true

## 获取所有已注册的角色
## [return] 所有已注册的角色
func get_all_characters() -> Array[Node]:
	return _player_team.duplicate() + _enemy_team.duplicate()

## 获取所有存活的角色
## [return] 所有存活的角色
func get_all_living_characters() -> Array[Node]:
	return get_player_team(true).duplicate() + get_enemy_team(true).duplicate()

## 获取玩家队伍的角色
## [param is_only_alive] 是否只返回存活的角色
## [return] 玩家队伍的角色
func get_player_team(is_only_alive: bool = false) -> Array[Node]:
	return _player_team.filter(func(character: Node) -> bool:
			if not is_instance_valid(character):
				return false

			var combat_component : CharacterCombatComponent = character.get_combat_component() if character.has_method("get_combat_component") else null
			if not is_instance_valid(combat_component):
				return false

			if is_only_alive and not combat_component.is_alive:
				return false

			return true
			)

## 获取敌人队伍的角色
## [param is_only_alive] 是否只返回存活的角色
## [return] 敌人队伍的角色
func get_enemy_team(is_only_alive: bool = false) -> Array[Node]:
	return _enemy_team.filter(func(character: Node) -> bool:
			if not is_instance_valid(character):
				return false

			var combat_component : CharacterCombatComponent = character.get_combat_component() if character.has_method("get_combat_component") else null
			if not is_instance_valid(combat_component):
				return false

			if is_only_alive and not combat_component.is_alive:
				return false

			return true
			)

## 清空所有注册信息 (例如战斗结束时)
func clear_registry() -> void:
	var all_characters: Array[Node] = get_all_characters()
	_player_team.clear()
	_enemy_team.clear()
	team_changed.emit(_player_team, TeamType.PLAYER)
	team_changed.emit(_enemy_team, TeamType.ENEMY)
	print_rich("[color=purple][角色注册管理器][/color] 所有角色已反注册")

## 检查特定队伍是否全部被击败
## [param is_player_team_check] 是否检查玩家队伍
## [return] 是否全部被击败
func is_team_defeated(is_player_team_check: bool) -> bool:
	var team_to_check = get_player_team(true) if is_player_team_check else get_enemy_team(true)
	if team_to_check.is_empty():
		return true
	return false

## 检查角色是否在玩家队伍
## [param character] 要检查的角色
## [return] 是否在玩家队伍
func is_player_character(character: Node) -> bool:
	if not is_instance_valid(character):
		push_error("角色不存在！")
		return false
	return _player_team.has(character)

## 获取角色的友方队伍
## [param character] 目标角色
## [param include_self] 是否包含自己
## [return] 友方队伍角色列表
func get_allied_team_for_character(character: Node, include_self: bool = true, is_alive: bool = true) -> Array[Node]:
	var team:Array[Node] = get_player_team(is_alive) if is_player_character(character) else get_enemy_team(is_alive)
	if not include_self:
		team.erase(character)
	return team

## 获取角色的敌对队伍
## [param character] 目标角色
## [param is_alive] 是否只返回存活的角色
## [return] 敌对队伍角色列表
func get_opposing_team_for_character(character: Node, is_alive: bool = true) -> Array[Node]:
	return get_enemy_team(is_alive) if is_player_character(character) else get_player_team(is_alive)

## 判断是否为敌人
func is_enemy_of(character: Node, target: Node, is_alive: bool = true) -> bool:
	return target in get_opposing_team_for_character(character, is_alive)

## 判断是否为友方
func is_allied_of(character: Node, target: Node, is_alive: bool = true) -> bool:
	return target in get_allied_team_for_character(character, true, is_alive)
