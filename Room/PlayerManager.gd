extends Node
class_name PlayerManager

onready var Server = get_node("/root/Server")
var _player_scene = preload("res://Players/Player.tscn")
var _ghost_scene = preload("res://Players/Ghost.tscn")
var players = {}
var ghosts = []
var player_states = {}

#temporary very basic spawn point system
var _possible_spawn_points = [Vector3(0, 0, 5), Vector3(0, 0, -5)]
var _current_spawn_point = 0


func despawn_player(player_id):
	player_states.erase(player_id)
	#TODO: does this actually work correctly
	ghosts.erase(ghosts[players[player_id].game_id])
	players[player_id].queue_free()
	players.erase(player_id)
	for other_player_id in players:
		Server.despawn_enemy_on_client(other_player_id, player_id)

func spawn_player(player_id, game_id):
	var spawn_point = _find_next_spawn_point()
	var player = _player_scene.instance()
	player.game_id = game_id
	player.player_id = player_id
	player.transform.origin = spawn_point
	add_child(player)
	ghosts.append([])

	#triggering spawns of enemies on all clients
	for other_player_id in players:
		Server.spawn_enemy_on_client(
			player_id, other_player_id, players[other_player_id].transform.origin
		)
		Server.spawn_enemy_on_client(other_player_id, player_id, spawn_point)

	players[player_id] = player
	Server.spawn_player_on_client(player_id, spawn_point)

	#TODO: move this to where it makes sense
	start_recording()

func start_recording():
	for player_id in players:
		players[player_id].start_recording()

func stop_recording():
	for player_id in players:
		players[player_id].stop_recording()

func create_ghosts():
	for player_id in players:
		create_ghost_from_player(players[player_id])

func create_ghost_from_player(player):
	var ghost = _ghost_scene.instance()
	ghost.init(player.gameplay_record, player.game_id, player.player_id)
	ghosts[player.game_id].append(ghost)
	add_child(ghost)
	Server.send_ghost_record(player.gameplay_record, player.player_id)

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


var timer = 10
var do_once = false
func _physics_process(delta):
	timer-=delta
	for player_id in player_states:
		if players.has(player_id):
			players[player_id].apply_player_state(player_states[player_id], delta)
	if timer<=0 and not do_once:
		do_once = true
		stop_recording()
		create_ghosts()
		for i in range(ghosts.size()):
			for j in range(ghosts[i].size()):
				ghosts[i][j].start_replay()
