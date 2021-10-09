extends Viewport
class_name Room

signal world_state_updated(world_state, id)
signal room_filled()

const PLAYER_NUMBER_PER_ROOM = 2

var room_name: String
var id: int
var player_count: int = 0

onready var _player_manager: PlayerManager = get_node("PlayerManager")
onready var _world_state_manager: WorldStateManager = get_node("WorldStateManager")
onready var _game_manager: GameManager = get_node("GameManager")
onready var _level = get_node("LevelH") # TODO: Should be configurable later

#id dictionary -> translates network id to game id (0 or 1)
var player_id_to_game_id = {}
var game_id_to_player_id = {}


func _ready():
	_world_state_manager.connect("world_state_updated", self, "_on_world_state_update")
	_game_manager.connect("prep_phase_ended",self, "_on_prep_phase_end")
	_game_manager.connect("round_ended",self, "_on_round_ended")
	
	_player_manager.level = _level
	_game_manager.level = _level


func reset():
	_player_manager.reset()
	_game_manager.reset()
	_level.reset()

func _on_prep_phase_end( _round_index: int) ->void:
	#TODO: change this when ghosts to replace are pickable after round 3
	#for now we always replace the last ghost after we hit max ghost count
	_player_manager.restart_ghosts()
	var ghost_index = min(_round_index-1,Constants.get_value("ghosts", "max_amount"))
	_player_manager.enable_ghosts()
	_player_manager.start_recording(ghost_index)
	_player_manager.set_players_can_move(true)

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
	_player_manager.update_player_state(player_id, player_state)


func update_dash_state(player_id, dash_state):
	_player_manager.update_dash_state(player_id, dash_state)


func get_players():
	return _player_manager.players

func get_game_manager() -> GameManager:
	return _game_manager


func _on_world_state_update(world_state):
	emit_signal("world_state_updated", world_state, id)
