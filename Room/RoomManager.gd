extends Node
class_name RoomManager

var room_count : int = 0

var _room_scene = preload("res://Room/Room.tscn")

var _room_id_counter : int = 1
var _room_dic : Dictionary = {}

onready var _server = get_node("/root/Server")


func create_room(room_name : String) -> int :
	var room : Room = _room_scene.instance()
	room.set_name(str(_room_id_counter))
	room.room_name = room_name
	room.id = _room_id_counter
	add_child(room)
	
	room.connect("world_state_updated", self, "_on_world_state_update")

	_room_dic[_room_id_counter] = room
	_room_id_counter += 1
	room_count += 1
	
	return room.id

func delete_room(room_id : int) -> void:
	if _room_dic.has(room_id):
		_room_dic[room_id].queue_free()
		_room_dic.erase(room_id)
		room_count -= 1


func join_room(room_id : int, player_id : int) -> void:
	if _room_dic.has(room_id):
		var room : Room = _room_dic[room_id]
		room.add_player(player_id)
		


func leave_room(room_id : int, player_id : int) -> void:
	if _room_dic.has(room_id):
		var room : Room = _room_dic[room_id]
		room.remove_player(player_id)
		if room.player_count == 0:
			delete_room(room_id)


func get_room(room_id : int) -> Room:
	return _room_dic[room_id]

func get_current_room_id() -> int:
	return _room_dic[_room_id_counter - 1].id


func is_current_room_full() -> bool:
	if _room_dic.size() == 0:
		return true
	else:
		return _room_dic[_room_id_counter - 1].player_count >= 2


func _on_world_state_update(world_state, room_id) -> void:
	var room : Room = _room_dic[room_id]
	for player_id in room.get_players().keys():
		_server.send_world_state(world_state, player_id)