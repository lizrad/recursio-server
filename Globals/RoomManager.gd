extends Node
class_name RoomManager

var room_count : int = 0

var _room_scene = preload("res://Room.tscn")

var _room_id_counter : int = 1
var _room_dic : Dictionary = {}

onready var _server = get_node("/root/Server")


func create_room(room_name : String) -> void :
	var room : Room = _room_scene.instance()
	room.set_name(str(_room_id_counter))
	room.room_name = room_name
	room.room_id = _room_id_counter
	add_child(room)
	
	room.world_state_manager.set_physics_process(false)
	room.world_state_manager.connect("on_world_state_update", self, "_on_world_state_update", [_room_id_counter])

	_room_dic[_room_id_counter] = room
	_room_id_counter += 1
	room_count += 1

func delete_room(room_id : int) -> void:
	if _room_dic.has(room_id):
		_room_dic[room_id].queue_free()
		_room_dic.erase(room_id)
		room_count -= 1


func join_room(room_id : int, player_id : int) -> void:
	if _room_dic.has(room_id):
		var room : Room = _room_dic[room_id]
		room.player_manager.spawn_player(player_id)
		room.world_state_manager.set_physics_process(true)
		room.room_player_count += 1


func leave_room(room_id : int, player_id : int) -> void:
	if _room_dic.has(room_id):
		var room : Room = _room_dic[room_id]
		room.player_manager.despawn_player(player_id)
		room.room_player_count -= 1
		if room.room_player_count == 0:
			delete_room(room_id)


func get_room(room_id : int) -> Room:
	return _room_dic[room_id]


func is_current_room_full() -> bool:
	if _room_dic.size() == 0:
		return true
	else:
		return _room_dic[_room_id_counter - 1].room_player_count >= 2


func _on_world_state_update(world_state, room_id) -> void:
	_server.send_world_state(world_state)
