extends Node
class_name RoomManager

# Creates and removes rooms, and mediates between Server requests and specific rooms.

var room_count: int = 0

var _room_scene = preload("res://Room/Room.tscn")

var _room_id_counter: int = 1
var _room_dic: Dictionary = {}

onready var _server: Server = get_node("/root/Server")


func create_room(room_name: String) -> int:
	var room: Room = _room_scene.instance()
	room.set_name(str(_room_id_counter))
	room.room_name = room_name
	room.id = _room_id_counter
	$ViewportContainer.add_child(room)
	
	# Workaround for getting the viewport to update
	$ViewportContainer.rect_clip_content = true

	room.connect("world_state_updated", self, "_on_world_state_update")
	room.get_game_manager().connect("round_started", self, "_on_round_start", [room.id])
	room.get_game_manager().connect("round_ended", self, "_on_round_end", [room.id])
	room.get_game_manager().connect("capture_point_team_changed", self, "_on_capture_point_team_changed", [room.id])
	room.get_game_manager().connect("capture_point_captured", self, "_on_capture_point_captured", [room.id])
	room.get_game_manager().connect("capture_point_status_changed", self, "_on_capture_point_status_changed", [room.id])
	room.get_game_manager().connect("capture_point_capture_lost", self, "_on_capture_point_capture_lost", [room.id])
	room.get_game_manager().connect("game_result", self, "_on_game_result", [room.id])
	
	_room_dic[_room_id_counter] = room
	_room_id_counter += 1
	room_count += 1
	Logger.info("Room added (ID:%s)" % room.id, "rooms")
	return room.id


func delete_room(room_id: int) -> void:
	if _room_dic.has(room_id):
		_room_dic[room_id].free()
		_room_dic.erase(room_id)
		room_count -= 1
		Logger.info("Room removed (ID:%s)" % room_id, "rooms")
		
		# Same workaround as in create_room
		$ViewportContainer.rect_clip_content = true


func join_room(room_id: int, player_id: int) -> void:
	if _room_dic.has(room_id):
		var room: Room = _room_dic[room_id]
		room.add_player(player_id)


func leave_room(room_id: int, player_id: int) -> void:
	if _room_dic.has(room_id):
		var room: Room = _room_dic[room_id]
		room.remove_player(player_id)
		if room.player_count == 0:
			delete_room(room_id)


func get_room(room_id: int) -> Room:
	return _room_dic[room_id]


func get_current_room_id() -> int:
	return _room_dic[_room_id_counter - 1].id


func is_current_room_full() -> bool:
	if _room_dic.size() == 0:
		return true
	else:
		return _room_dic[_room_id_counter - 1].player_count >= 2


# Sends the world state of the room to all players in the room
func _on_world_state_update(world_state, room_id) -> void:
	var room: Room = _room_dic[room_id]
	for player_id in room.get_players().keys():
		_server.send_world_state(player_id, world_state)


# Sends the round start event to all players in the room
func _on_round_start(round_index, room_id):
	var room: Room = _room_dic[room_id]
	for player_id in room.get_players().keys():
		room.get_players()[player_id].round_index = round_index
		_server.send_round_start_to_client(player_id, round_index)


# Sends the round end event to all players in the room
func _on_round_end(round_index, room_id):
	var room: Room = _room_dic[room_id]
	room.get_node("ActionManager").clear_action_instances()
	
	for player_id in room.get_players().keys():
		_server.send_round_end_to_client(player_id, round_index)

func _on_capture_point_team_changed(team_id, capture_point, room_id):
	var room = _room_dic[room_id]
	var capturing_player_id = -1
	if team_id != -1:
		capturing_player_id = room.game_id_to_player_id[team_id]
	for player_id in room.get_players().keys():
		_server.send_capture_point_team_changed(player_id, capturing_player_id, capture_point)


func _on_capture_point_captured(team_id, capture_point, room_id):
	var room = _room_dic[room_id]
	var capturing_player_id = -1
	if team_id != -1:
		capturing_player_id = room.game_id_to_player_id[team_id]
	for player_id in room.get_players().keys():
		_server.send_capture_point_captured(player_id, capturing_player_id, capture_point)

func _on_capture_point_status_changed(capture_progress, team_id, capture_point, room_id):
	var room = _room_dic[room_id]
	var capturing_player_id = -1
	if team_id != -1:
		capturing_player_id = room.game_id_to_player_id[team_id]
	for player_id in room.get_players().keys():
		_server.send_capture_point_status_changed(player_id, capturing_player_id, capture_point, capture_progress)

func _on_capture_point_capture_lost(team_id, capture_point, room_id):
	var room = _room_dic[room_id]
	var capturing_player_id = -1
	if team_id != -1:
		capturing_player_id = room.game_id_to_player_id[team_id]
	for player_id in room.get_players().keys():
		_server.send_capture_point_capture_lost(player_id, capturing_player_id, capture_point)

func _on_game_result(team_id, room_id):
	var room = _room_dic[room_id]
	var winning_player_id = room.game_id_to_player_id[team_id]
	for player_id in room.get_players().keys():
		_server.send_game_result(player_id, winning_player_id)
	room.reset()
	room.start_game()
