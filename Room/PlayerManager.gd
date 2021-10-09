extends Node
class_name PlayerManager

onready var Server = get_node("/root/Server")
var _player_scene = preload("res://Players/Player.tscn")
var _ghost_scene = preload("res://Players/Ghost.tscn")
var players = {}
var ghosts = {}
var player_states = {}


var level
func reset():
	stop_recording()
	for player_id in ghosts:
			for i in range(ghosts[player_id].size()):
				ghosts[player_id][i].queue_free()
			ghosts[player_id].clear()
	player_states.clear()
	for player_id in players:
		players[player_id].reset()
	reset_spawnpoints()

func despawn_player(player_id):
	player_states.erase(player_id)
	for i in range(ghosts[player_id].size()):
		ghosts[player_id][i].queue_free()
	ghosts.erase(player_id)
	players[player_id].queue_free()
	players.erase(player_id)
	for other_player_id in players:
		Server.despawn_enemy_on_client(other_player_id, player_id)

func reset_spawnpoints():
	for player_id in players:
		move_player_to_spawnpoint(player_id, 0)
		
		
func move_player_to_spawnpoint(player_id, ghost_index:int)->void:
	Logger.info("Moving player "+str(player_id)+" to spawnpoint "+str(ghost_index), "spawnpoints")
	#Hotfix: otherwise it would overcorrect again
	players[player_id].wait_for_player_to_correct=120
	players[player_id].transform.origin = _get_spawn_point(players[player_id].game_id, ghost_index)


func spawn_player(player_id, game_id):
	var spawn_point = _get_spawn_point(game_id, 0)
	var player = _player_scene.instance()
	player.game_id = game_id
	player.player_id = player_id
	ghosts[player_id] = []
	add_child(player)
	player.connect("hit", self, "_on_player_hit", [player_id])

	#triggering spawns of enemies on all clients
	for other_player_id in players:
		Server.spawn_enemy_on_client(
			player_id, other_player_id, players[other_player_id].transform.origin
		)
		Server.spawn_enemy_on_client(other_player_id, player_id, spawn_point)

	players[player_id] = player
	move_player_to_spawnpoint(player_id, 0)
	Server.spawn_player_on_client(player_id, spawn_point, game_id)


func start_recording(ghost_indices:Dictionary):
	for player_id in players:
		players[player_id].start_recording(ghost_indices[player_id])


func stop_recording()->void:
	for player_id in players:
		players[player_id].stop_recording()


func create_ghosts()->void:
	for player_id in players:
		_create_ghost_from_player(players[player_id])


func restart_ghosts(replaced_ghost_indices:Dictionary)->void:
	for player_id in ghosts:
			for i in range(ghosts[player_id].size()):
				if replaced_ghost_indices[player_id]!=i:
					ghosts[player_id][i].start_replay(Server.get_server_time())


func enable_ghosts(replaced_ghost_indices:Dictionary) ->void:
	for player_id in ghosts:
			for i in range(ghosts[player_id].size()):
				if replaced_ghost_indices[player_id]!=i:
					add_ghost(ghosts[player_id][i])


func add_ghost(ghost):
	add_child(ghost)
	ghost.connect("hit", self, "_on_ghost_hit", [ghost.ghost_id])
	ghost.connect("ghost_attack", self, "do_attack")


func remove_ghost(ghost):
	remove_child(ghost)
	ghost.disconnect("hit", self, "_on_ghost_hit")
	ghost.disconnect("ghost_attack", self, "do_attack")


func disable_ghosts()->void:
	for player_id in ghosts:
			for i in range(ghosts[player_id].size()):
				remove_ghost(ghosts[player_id][i])


func set_players_can_move(can_move : bool) -> void:
	for player_id in players:
		players[player_id].can_move = can_move


func _create_ghost_from_player(player)->void:
	var ghost = _ghost_scene.instance()
	ghost.init(player.gameplay_record)
	ghost.spawn_point = player.spawn_point
	ghost.game_id = player.game_id
	ghost.player_id = player.player_id
	if ghosts[player.player_id].size()<=Constants.get_value("ghosts", "max_amount"):
		ghosts[player.player_id].append(ghost)
	else:
		var old_ghost = ghosts[player.player_id][player.gameplay_record["G"]]
		ghosts[player.player_id][player.gameplay_record["G"]] = ghost
		old_ghost.queue_free()
	
	add_ghost(ghost)
	
	Server.send_own_ghost_record_to_client(player.player_id, player.gameplay_record)
	for client_id in players:
		if client_id != player.player_id:
			Server.send_enemy_ghost_record_to_client(client_id, player.player_id, player.gameplay_record)


func _get_spawn_point(game_id, ghost_index):
	var player_number = game_id + 1
	var spawn_point = level.get_spawn_points(player_number)[ghost_index]
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


func handle_player_action(player_id, action_state):
	# {"A": Constants.ActionType, "T": Server.get_server_time()}
	Logger.info("Handling action of type " + str(action_state["A"]))
	do_attack(players[player_id], action_state["A"])


func do_attack(attacker, action_type):
	if action_type == Enums.ActionType.SHOOT:
		var spawn = preload("res://Shared/Attacks/Shots/HitscanShot.tscn").instance()
		spawn.initialize(attacker)
		spawn.global_transform = attacker.global_transform
		add_child(spawn)
	
		if "action_last_frame" in attacker:
			attacker.action_last_frame = Enums.AttackFrame.SHOOT_START
	


func update_dash_state(player_id, dash_state):
	players[player_id].update_dash_state(dash_state)


func _physics_process(delta):
	for player_id in player_states:
		if players.has(player_id):
			players[player_id].apply_player_state(player_states[player_id], delta)


func _on_player_hit(hit_player_id):
	Logger.info("Player hit!", "attacking")
	for player_id in players:
		Server.send_player_hit(player_id, hit_player_id)


func _on_ghost_hit(ghost_id):
	Logger.info("Ghost hit!", "attacking")
	for player_id in players:
		Server.send_ghost_hit(player_id, ghost_id)
