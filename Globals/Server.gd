extends Node
class_name Server

var network = NetworkedMultiplayerENet.new()
var port = 1909
var max_players = 100
var player_amount = 0

onready var _room_manager = get_node("RoomManager")

var _player_room_dic: Dictionary = {}


func _ready():
	#TODO: put this where it makes more sense
	Logger.load_config()
	start_server()


func start_server():
	network.create_server(port, max_players)
	get_tree().set_network_peer(network)

	Logger.info("Server started", "connection")

	network.connect("peer_connected", self, "_peer_connected")
	network.connect("peer_disconnected", self, "_peer_disconnected")


func _peer_connected(player_id):
	Logger.info("Player with id: " + str(player_id) + " connected.", "connection")

	player_amount += 1

	if _room_manager.is_current_room_full():
		var room_id = _room_manager.create_room("Room 1")
		_room_manager.join_room(room_id, player_id)
		_player_room_dic[player_id] = room_id
	else:
		var room_id = _room_manager.get_current_room_id()
		_room_manager.join_room(room_id, player_id)
		_player_room_dic[player_id] = room_id


func _peer_disconnected(player_id):
	Logger.info("Player with id: " + str(player_id) + " disconnected.", "connection")

	_room_manager.leave_room(_player_room_dic[player_id], player_id)
	_player_room_dic.erase(player_id)
	player_amount -= 1


func spawn_player_on_client(player_id, spawn_point):
	rpc_id(player_id, "spawn_player", player_id, spawn_point)


func spawn_enemy_on_client(player_id, enemy_id, enemy_position):
	rpc_id(player_id, "spawn_enemy", enemy_id, enemy_position)


func despawn_enemy_on_client(player_id, enemy_id):
	rpc_id(player_id, "despawn_enemy", enemy_id)


func send_own_ghost_record_to_client( player_id, gameplay_record):
	rpc_id(player_id, "receive_own_ghost_record", gameplay_record)
	
func send_enemy_ghost_record_to_client(player_id, enemy_id, gameplay_record):
	rpc_id(player_id, "receive_enemy_ghost_record", enemy_id, gameplay_record)

func get_server_time():
	return OS.get_system_time_msecs()


remote func determine_latency(player_time):
	var player_id = get_tree().get_rpc_sender_id()
	rpc_id(player_id, "receive_latency", player_time)


remote func fetch_server_time(player_time):
	var player_id = get_tree().get_rpc_sender_id()
	rpc_id(player_id, "receive_server_time", OS.get_system_time_msecs(), player_time)


remote func receive_player_state(player_state):
	var player_id = get_tree().get_rpc_sender_id()
	var room_id = _player_room_dic[player_id]
	_room_manager.get_room(room_id).update_player_state(player_id, player_state)


remote func receive_dash_state(dash_state):
	var player_id = get_tree().get_rpc_sender_id()
	var room_id = _player_room_dic[player_id]
	_room_manager.get_room(room_id).update_dash_state(player_id, dash_state)


# Sends the current world state (of the players room) to the player
func send_world_state(player_id, world_state):
	rpc_unreliable_id(player_id, "receive_world_state", world_state)


# Notifies a player that a specific round will start
# Provides the server time to counteract latency
func send_round_start_to_client(player_id, round_index, warm_up):
	rpc_id(player_id, "receive_round_start", round_index, warm_up, get_server_time())

# Notifies a player that a specific round has ended
func send_round_end_to_client(player_id, round_index):
	rpc_id(player_id, "receive_round_end", round_index)
