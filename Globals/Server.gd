extends Node
class_name Server

var network = NetworkedMultiplayerENet.new()
var port = 1909
var max_players = 100
var player_amount = 0

onready var _room_manager = get_node("RoomManager")

var _player_room_dic: Dictionary = {}


func _ready():
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


func spawn_player_on_client(player_id, spawn_point, game_id):
	rpc_id(player_id, "spawn_player", player_id, spawn_point, game_id)


func spawn_enemy_on_client(player_id, enemy_id, enemy_position):
	rpc_id(player_id, "spawn_enemy", enemy_id, enemy_position)


func despawn_enemy_on_client(player_id, enemy_id):
	rpc_id(player_id, "despawn_enemy", enemy_id)


func send_own_ghost_record_to_client(player_id, gameplay_record):
	rpc_id(player_id, "receive_own_ghost_record", gameplay_record)
	
func send_enemy_ghost_record_to_client(player_id, enemy_id, gameplay_record):
	rpc_id(player_id, "receive_enemy_ghost_record", enemy_id, gameplay_record)

func get_server_time():
	return OS.get_system_time_msecs()

func send_capture_point_captured(player_id, capturing_player_id, capture_point):
	Logger.info("Sending capture point captured to client", "connection")
	rpc_id(player_id, "receive_capture_point_captured", capturing_player_id, capture_point )

func send_capture_point_team_changed(player_id, capturing_player_id, capture_point):
	Logger.info("Sending capture point team changed to client", "connection")
	rpc_id(player_id, "receive_capture_point_team_changed", capturing_player_id, capture_point )

func send_capture_point_status_changed(player_id, capturing_player_id, capture_point, capture_progress):
	Logger.info("Sending capture point status changed to client", "connection")
	rpc_unreliable_id(player_id, "receive_capture_point_status_changed", capturing_player_id, capture_point, capture_progress )

func send_capture_point_capture_lost(player_id, capturing_player_id, capture_point):
	Logger.info("Sending capture point capture lost to client", "connection")
	rpc_id(player_id, "receive_capture_point_capture_lost", capturing_player_id, capture_point )


func send_player_action(player_id, action_player_id, action_type):
	Logger.info("Sending capture point capture lost to client", "connection")
	rpc_id(player_id, "receive_player_action", action_player_id, action_type)


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


remote func receive_action_trigger(action):
	Logger.info("received action trigger %s" %[action], "connection")
	var player_id = get_tree().get_rpc_sender_id()
	var room_id = _player_room_dic[player_id]
	_room_manager.get_room(room_id).handle_player_action(player_id, action)


remote func receive_ghost_pick(ghost_index):
	var player_id = get_tree().get_rpc_sender_id()
	var room_id = _player_room_dic[player_id]
	Logger.info("received ghost index of "+str(ghost_index)+" from player "+str(player_id)+".", "connection")
	_room_manager.get_room(room_id).handle_ghost_pick(player_id, ghost_index)
	

# Sends the current world state (of the players room) to the player
func send_world_state(player_id, world_state):
	rpc_unreliable_id(player_id, "receive_world_state", world_state)


# Notifies a player that a specific round will start
# Provides the server time to counteract latency
func send_round_start_to_client(player_id, round_index):
	Logger.info("Sending round start to client", "connection")
	rpc_id(player_id, "receive_round_start", round_index, get_server_time())


# Notifies a player that a specific round has ended
func send_round_end_to_client(player_id, round_index):
	Logger.info("Sending round end to client", "connection")
	rpc_id(player_id, "receive_round_end", round_index)


func send_game_result(player_id, winning_player_id):
	Logger.info("Sending game result to client", "connection")
	rpc_id(player_id, "receive_game_result", winning_player_id)


func send_player_hit(player_id, hit_player_id):
	Logger.info("Sending player hit to client", "connection")
	rpc_id(player_id, "receive_player_hit", hit_player_id)


func send_ghost_hit(player_id, hit_ghost_player_owner, hit_ghost_id):
	Logger.info("Sending ghost hit to client", "connection")
	rpc_id(player_id, "receive_ghost_hit", hit_ghost_player_owner, hit_ghost_id)


func send_ghost_pick(player_id, player_pick, enemy_picks):
	Logger.info("Sending ghost picks", "connection")
	rpc_id(player_id, "receive_ghost_picks", player_pick, enemy_picks)
