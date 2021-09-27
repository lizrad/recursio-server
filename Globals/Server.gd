extends Node


var network = NetworkedMultiplayerENet.new()
var port = 1909
var max_players = 100
#temporary very basic spawn point system
var _possible_spawn_points = [Vector3(0,0,5), Vector3(0,0,-5)]
var _current_spawn_point = 0

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
	_spawn_player(player_id)
	
	

func _peer_disconnected(player_id):
	print("Player with id: " + str(player_id)+ " disconnected.")

func _spawn_player(player_id):
	var spawn_point = _possible_spawn_points[_current_spawn_point]
	rpc_id(player_id,"spawn_player", spawn_point)
	PlayerManager.spawn_player(player_id, spawn_point)
	#spawnpoints currently just switch between two positions
	_current_spawn_point= 1- _current_spawn_point

func notify_player_of_enemy(player_id, enemy_id, enemy_position):
	rpc_id(player_id,"spawn_enemy",enemy_id, enemy_position)
