extends Node


var network = NetworkedMultiplayerENet.new()
var port = 1909
var max_players = 100


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
	rpc_id(player_id,"spawn_player")


func _peer_disconnected(player_id):
	print("Player with id: " + str(player_id)+ " disconnected.")


