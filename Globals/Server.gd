extends Node


var network = NetworkedMultiplayerENet.new()
var port = 1909
var max_players = 100
var player_amount = 0

func _ready():
	start_server()


func start_server():
	network.create_server(port, max_players)
	get_tree().set_network_peer(network)
	print("Server started")
	
	network.connect("peer_connected", self, "_peer_connected")
	network.connect("peer_disconnected", self, "_peer_disconnected")


func _peer_connected(player_id):
	print("Player with id: " + str(player_id)+ " connected.")
	#temporarily instantly spawning a player
	PlayerManager.spawn_player(player_id)
	player_amount+=1

func _peer_disconnected(player_id):
	print("Player with id: " + str(player_id)+ " disconnected.")
	PlayerManager.despawn_player(player_id)
	player_amount-=1

func spawn_player_on_client(player_id, spawn_point):
	rpc_id(player_id,"spawn_player", player_id, spawn_point)

func spawn_enemy_on_client(player_id, enemy_id, enemy_position):
	rpc_id(player_id,"spawn_enemy",enemy_id, enemy_position)

func despawn_enemy_on_client(player_id, enemy_id):
	rpc_id(player_id,"despawn_enemy",enemy_id)


remote func receive_player_state(player_state):
	var player_id = get_tree().get_rpc_sender_id()
	PlayerManager.update_player_state(player_id,player_state)

func send_world_state(world_state):
	rpc_unreliable_id(0,"receive_world_state",world_state)
	
func get_server_time():
	return OS.get_system_time_msecs()
