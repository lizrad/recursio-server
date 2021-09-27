extends Node

onready var Server = get_node("/root/Server")
var _character_base_scene = preload("res://Players/CharacterBase.tscn")
var players = {}

func spawn_player(player_id, spawn_point):
	var player = _character_base_scene.instance()
	player.set_name(str(player_id))
	player.transform.origin = spawn_point
	add_child(player)
	
	#triggering spawns of enemies on all clients
	for other_player_id in players:
		Server.notify_player_of_enemy(player_id, other_player_id,players[other_player_id].transform.origin)
		Server.notify_player_of_enemy(other_player_id,player_id, spawn_point)
	
	players[player_id]=player

