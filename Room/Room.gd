extends Viewport
class_name Room

# Connects all the specific managers together

signal world_state_updated(world_state, id)
signal room_filled()

const PLAYER_NUMBER_PER_ROOM = 2

var room_name: String
var id: int
var player_count: int = 0

onready var _player_manager: PlayerManager = get_node("PlayerManager")
onready var _world_state_manager: WorldStateManager = get_node("WorldStateManager")
onready var _game_manager: GameManager = get_node("GameManager")
onready var _action_manager: ActionManager = get_node("ActionManager")
onready var _level = get_node("LevelH") # TODO: Should be configurable later

#id dictionary -> translates network id to game id (0 or 1)
var player_id_to_game_id = {}
var game_id_to_player_id = {}


func _ready():
	_world_state_manager.connect("world_state_updated", self, "_on_world_state_update")
	_game_manager.connect("round_started",self, "_on_round_started")
	_game_manager.connect("game_phase_started",self, "_on_game_phase_start")
	_game_manager.connect("round_ended",self, "_on_round_ended")
	_game_manager.connect("countdown_halfway_point", self,"_on_countdown_halfway_point")
	_player_manager.level = _level
	_game_manager.level = _level


func reset():
	Logger.info("Full reset triggered.","gameplay")
	_action_manager.clear_action_instances()
	_player_manager.reset()
	_game_manager.reset()
	_level.reset()

func _on_round_started(round_index):
	var default_ghost_index = min(round_index-1,Constants.get_value("ghosts", "max_amount"))
	for player_id in _player_manager.players:
		_player_manager.set_ghost_index(player_id, default_ghost_index)

func _on_game_phase_start(round_index: int) ->void:
	_player_manager.restart_ghosts()
	_player_manager.enable_ghosts()
	_player_manager.start_recording()
	for player_id in _player_manager.players:
		_player_manager.move_player_to_spawnpoint(player_id)
	_player_manager.set_players_can_move(true)

func _on_countdown_halfway_point():
	_player_manager.propagate_player_picks()

func _on_round_ended(_round_index: int) -> void:
	_player_manager.stop_recording()
	_player_manager.create_ghosts()
	_player_manager.disable_ghosts()
	_player_manager.reset_spawnpoints()
	_player_manager.set_players_can_move(false)

func add_player(player_id: int) -> void:
	_player_manager.spawn_player(player_id, player_count)
	#update id dictionary
	player_id_to_game_id[player_id] = player_count
	game_id_to_player_id[player_count] = player_id
	player_count += 1
	
	# If the room is filled, start the game
	if player_count >= PLAYER_NUMBER_PER_ROOM:
		start_game()

func start_game():
	
	_game_manager.start_game()
	
func remove_player(player_id: int) -> void:
	_player_manager.despawn_player(player_id)
	#update id dictionary
	player_id_to_game_id.erase(player_id)
	game_id_to_player_id.clear()
	var game_id = 0
	for player_id in player_id_to_game_id:
		_player_manager.players[player_id].game_id = game_id
		player_id_to_game_id[player_id] = game_id
		game_id_to_player_id[game_id] = player_id
		game_id += 1

	player_count -= 1


func update_player_state(player_id, player_state):
	if _game_manager.game_phase_in_progress:
		_player_manager.update_player_state(player_id, player_state)
		pass


func update_dash_state(player_id, dash_state):
	_player_manager.update_dash_state(player_id, dash_state)


func handle_player_action(player_id, action_state):
	_player_manager.handle_player_action(player_id, action_state)

func handle_ghost_pick(player_id, ghost_index):
	if not _game_manager._before_second_half_of_countdown:
		Logger.error("Received ghost picks outside proper phase", "ghost_picking")
		return
	_player_manager.set_ghost_index(player_id, ghost_index)
	

func get_players():
	return _player_manager.players

func get_game_manager() -> GameManager:
	return _game_manager


func _on_world_state_update(world_state):
	emit_signal("world_state_updated", world_state, id)
