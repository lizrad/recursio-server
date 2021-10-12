extends Node
class_name PlayerManager

onready var Server = get_node("/root/Server")
var _player_scene = preload("res://Players/Player.tscn")
var _ghost_scene = preload("res://Players/Ghost.tscn")
var players = {}
var ghosts = {}
var player_states = {}

var level

onready var _game_manager = get_node("../GameManager")
onready var _action_manager = get_node("../ActionManager")


func reset():
	stop_recording()
	for player_id in ghosts:
			for i in ghosts[player_id]:
				ghosts[player_id][i].queue_free()
			ghosts[player_id].clear()
	player_states.clear()
	for player_id in players:
		players[player_id].reset()
	reset_spawnpoints()

func despawn_player(player_id):
	player_states.erase(player_id)
	for i in ghosts[player_id]:
		ghosts[player_id][i].queue_free()
	ghosts.erase(player_id)
	players[player_id].queue_free()
	players.erase(player_id)
	for other_player_id in players:
		Server.despawn_enemy_on_client(other_player_id, player_id)

func reset_spawnpoints():
	for player_id in players:
		move_player_to_spawnpoint(player_id)
		
		
func move_player_to_spawnpoint(player_id)->void:
	Logger.info("Moving player "+str(player_id)+" to spawnpoint "+str(players[player_id].ghost_index), "spawnpoints")
	#Hotfix: otherwise it would overcorrect again
	players[player_id].wait_for_player_to_correct=120
	players[player_id].transform.origin = _get_spawn_point(players[player_id].game_id, players[player_id].ghost_index)


func spawn_player(player_id, game_id):
	var spawn_point = _get_spawn_point(game_id, 0)
	var player = _player_scene.instance()
	player.game_id = game_id
	player.player_id = player_id
	player.ghost_index = 0
	player.action_manager = _action_manager
	ghosts[player_id] = {}
	add_child(player)
	player.connect("hit", self, "_on_player_hit", [player_id])

	#triggering spawns of enemies on all clients
	for other_player_id in players:
		Server.spawn_enemy_on_client(
			player_id, other_player_id, players[other_player_id].transform.origin
		)
		Server.spawn_enemy_on_client(other_player_id, player_id, spawn_point)

	players[player_id] = player
	move_player_to_spawnpoint(player_id)
	Server.spawn_player_on_client(player_id, spawn_point, game_id)


func start_recording():
	for player_id in players:
		players[player_id].start_recording()


func stop_recording()->void:
	for player_id in players:
		players[player_id].stop_recording()


func create_ghosts()->void:
	for player_id in players:
		_create_ghost_from_player(players[player_id])


func restart_ghosts()->void:
	for player_id in ghosts:
			for i in ghosts[player_id]:
				if players[player_id].ghost_index!=i:
					ghosts[player_id][i].start_replay(Server.get_server_time())


func enable_ghosts() ->void:
	for player_id in ghosts:
			for i in ghosts[player_id]:
				if players[player_id].ghost_index != i and not ghosts[player_id][i].is_inside_tree():
					add_ghost(ghosts[player_id][i])


func add_ghost(ghost):
	add_child(ghost)
	ghost.action_manager = _action_manager
	ghost.connect("hit", self, "_on_ghost_hit", [ghost.ghost_index, ghost.player_id])
	ghost.connect("ghost_attack", self, "do_attack")


func remove_ghost(ghost):
	remove_child(ghost)
	ghost.disconnect("hit", self, "_on_ghost_hit")
	ghost.disconnect("ghost_attack", self, "do_attack")


func disable_ghosts()->void:
	for player_id in ghosts:
			for i in ghosts[player_id]:
				if i != players[player_id].ghost_index:
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
	ghost.round_index = _game_manager.round_index

	if  ghosts[player.player_id].has([player.gameplay_record["G"]]):
		ghosts[player.player_id][player.gameplay_record["G"]].queue_free()
	ghosts[player.player_id][player.gameplay_record["G"]] = ghost
	
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
	
	for any_player_id in players:
		if any_player_id != player_id:
			# Player is another player
			var action_type = _action_manager.get_action_type_for_trigger(action_state["A"], players[player_id].ghost_index)
			Server.send_player_action(any_player_id, player_id, action_type)


func do_attack(attacker, trigger):
	var action = _action_manager.get_action_for_trigger(trigger, attacker.ghost_index)
	_action_manager.set_active(action, true, attacker, get_parent())
	
	if "action_last_frame" in attacker:
		attacker.action_last_frame = trigger


func update_dash_state(player_id, dash_state):
	players[player_id].update_dash_state(dash_state)


func _physics_process(delta):
	for player_id in player_states:
		if players.has(player_id):
			players[player_id].apply_player_state(player_states[player_id], delta)


func _on_player_hit(hit_player_id):
	Logger.info("Player hit!", "attacking")
	move_player_to_spawnpoint(hit_player_id)
	
	for player_id in players:
		Server.send_player_hit(player_id, hit_player_id)


func _on_ghost_hit(ghost_id, owning_player_id):
	Logger.info("Ghost hit!", "attacking")
	for player_id in players:
		Server.send_ghost_hit(player_id, owning_player_id, ghost_id)

func set_ghost_index(player_id, ghost_index):
	Logger.info("Setting ghost index for player "+str(player_id)+" to "+str(ghost_index),"ghost_picking")
	players[player_id].ghost_index = ghost_index

func propagate_player_picks():
	Logger.info("Propagating ghost picks", "ghost_picking")
	for player_id in players:
		var player_pick = players[player_id].ghost_index
		var enemy_picks = {}
		for enemy_id in players:
			if enemy_id!=player_id:
				enemy_picks[enemy_id]=players[enemy_id].ghost_index
		Server.send_ghost_pick(player_id, player_pick, enemy_picks)
