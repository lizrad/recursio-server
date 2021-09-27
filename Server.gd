extends Node


var network = NetworkedMultiplayerENet.new()
var port = 1909
var max_players = 100
#temporary very basic spawn point system
var _spawn_points = [Vector3(0,0,5), Vector3(0,0,-5)]
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
	rpc_id(player_id,"spawn_player", _spawn_points[_current_spawn_point])
	#spawnpoints currently just switch between two positions
	_current_spawn_point= 1- _current_spawn_point


func _peer_disconnected(player_id):
	print("Player with id: " + str(player_id)+ " disconnected.")


