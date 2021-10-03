extends Viewport
class_name Room

var room_name: String
var id: int
var player_count: int = 0

signal world_state_updated(world_state, id)
signal room_filled

onready var _player_manager: PlayerManager = get_node("PlayerManager")
onready var _world_state_manager: WorldStateManager = get_node("WorldStateManager")
#id dictionary -> translates network id to game id (0 or 1)
var player_id_to_game_id = {}
var game_id_to_player_id = {}


func _ready():
	_world_state_manager.connect("world_state_updated", self, "_on_world_state_update")


func add_player(player_id: int) -> void:
	_player_manager.spawn_player(player_id, player_count)
	#update id dictionary
	player_id_to_game_id[player_id] = player_count
	game_id_to_player_id[player_count] = player_id
	player_count += 1


func remove_player(player_id: int) -> void:
	_player_manager.despawn_player(player_id)
	#update id dictionary
	player_id_to_game_id.erase(player_id)
	game_id_to_player_id.clear()
	var game_id = 0
	for player_id in player_id_to_game_id:
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


func _on_world_state_update(world_state):
	emit_signal("world_state_updated", world_state, id)
