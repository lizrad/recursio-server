extends Node
class_name RoomManager

var has_room : bool = false

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
	has_room = true


func delete_room(room_id : int) -> void:
	if _room_dic.has(room_id):
		_room_dic[room_id].queue_free()


func join_room(room_id : int, player_id : int) -> void:
	if _room_dic.has(room_id):
		_room_dic[room_id].player_manager.spawn_player(player_id)
		_room_dic[room_id].world_state_manager.set_physics_process(true)


func leave_room(room_id : int, player_id : int) -> void:
	if _room_dic.has(room_id):
		_room_dic[room_id].player_manager.despawn_player(player_id)
		if _room_dic[room_id].player_manager.players.size() == 0:
			delete_room(room_id)


func _on_world_state_update(world_state, room_id) -> void:
	_server.send_world_state(world_state)
