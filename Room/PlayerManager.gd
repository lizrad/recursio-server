extends Node
class_name PlayerManager

onready var Server = get_node("/root/Server")
var _player_scene = preload("res://Players/Player.tscn")
var _ghost_scene = preload("res://Players/Ghost.tscn")
var players = {}
var ghosts = {}
var player_states = {}

#temporary very basic spawn point system
var _possible_spawn_points = [Vector3(0, 0, 5), Vector3(0, 0, -5)]
var _current_spawn_point = 0


func despawn_player(player_id):
	player_states.erase(player_id)
	for i in range(ghosts[player_id].size()):
		ghosts[player_id][i].queue_free()
	ghosts.erase(player_id)
	players[player_id].queue_free()
	players.erase(player_id)
	for other_player_id in players:
		Server.despawn_enemy_on_client(other_player_id, player_id)

func reset_spawnpoints()->void:
	for player_id in players:
		players[player_id].transform.origin = players[player_id].spawn_point

func spawn_player(player_id, game_id):
	var spawn_point = _find_next_spawn_point()
	var player = _player_scene.instance()
	player.game_id = game_id
	player.player_id = player_id
	player.transform.origin = spawn_point
	player.spawn_point = spawn_point
	ghosts[player_id] = []
	add_child(player)

	#triggering spawns of enemies on all clients
	for other_player_id in players:
		Server.spawn_enemy_on_client(
			player_id, other_player_id, players[other_player_id].transform.origin
		)
		Server.spawn_enemy_on_client(other_player_id, player_id, spawn_point)

	players[player_id] = player
	Server.spawn_player_on_client(player_id, spawn_point)


func start_recording(ghost_index:int):
	for player_id in players:
		players[player_id].start_recording(ghost_index)


func stop_recording()->void:
	for player_id in players:
		players[player_id].stop_recording()


func create_ghosts()->void:
	for player_id in players:
		_create_ghost_from_player(players[player_id])


func restart_ghosts()->void:
	for player_id in ghosts:
			for i in range(ghosts[player_id].size()):
				ghosts[player_id][i].start_replay(Server.get_server_time())


func enable_ghosts() ->void:
	for player_id in ghosts:
			for i in range(ghosts[player_id].size()):
				add_child(ghosts[player_id][i])

func disable_ghosts()->void:
	for player_id in ghosts:
			for i in range(ghosts[player_id].size()):
				remove_child(ghosts[player_id][i])

func _create_ghost_from_player(player)->void:
	var ghost = _ghost_scene.instance()
	ghost.init(player.gameplay_record)
	ghost.game_id = player.game_id
	ghost.player_id = player.player_id
	if ghosts[player.player_id].size()<=Constants.get_value("ghosts", "max_amount"):
		ghosts[player.player_id].append(ghost)
	else:
		var old_ghost = ghosts[player.player_id][player.gameplay_record["G"]]
		ghosts[player.player_id][player.gameplay_record["G"]] = ghost
		old_ghost.queue_free()
	
	add_child(ghost)
	Server.send_own_ghost_record_to_client(player.player_id,player.gameplay_record)
	for client_id in players:
		if client_id != player.player_id:
			Server.send_enemy_ghost_record_to_client(client_id, player.player_id, player.gameplay_record)


func _find_next_spawn_point():
	var spawn_point = _possible_spawn_points[_current_spawn_point]
	#spawnpoints currently just switch between two positions
	_current_spawn_point = 1 - _current_spawn_point
	return spawn_point


func update_player_state(player_id, player_state):
	if player_states.has(player_id):
		if (
			player_states[player_id]["T"] < player_state["T"]  # playerstates have to come in the correct order
			&& player_state["T"] - Server.get_server_time() < 25
		):  # clock on client can't run more than 25ms fast
			player_states[player_id] = player_state
	else:
		player_states[player_id] = player_state


func update_dash_state(player_id, dash_state):
	players[player_id].update_dash_state(dash_state)


func _physics_process(delta):
	for player_id in player_states:
		if players.has(player_id):
			players[player_id].apply_player_state(player_states[player_id], delta)
